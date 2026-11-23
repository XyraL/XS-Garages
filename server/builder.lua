Builder = {}

local function running(name)
    local state = GetResourceState(name)
    return state == 'started' or state == 'starting'
end

function Builder.Allowed(src)
    return Framework.IsAdmin(src) == true
end

local function right(name)
    local r = (Config.Admin or {}).rights or {}
    return r[name] ~= false
end

local function rights()
    local r = (Config.Admin or {}).rights or {}
    return { delete = r.delete ~= false, vehicles = r.vehicles ~= false, removeCars = r.removeCars == true, owners = r.owners ~= false }
end

local function counts()
    local parked = {}
    for _, row in ipairs(MySQL.query.await('SELECT garage, COUNT(*) AS n FROM player_vehicles WHERE state = 1 GROUP BY garage') or {}) do
        parked[row.garage or ''] = tonumber(row.n) or 0
    end
    return parked
end

local function record(g, parked)
    local o = g.id and Private.owners[g.id]
    return {
        id = g.id, data = g.data, parked = parked[g.data.key] or 0,
        owner = o and { name = o.name, cid = o.citizenid, kind = o.kind, paidUntil = o.paid_until, access = o.access } or nil,
    }
end

function Builder.Stats()
    local s = { garages = 0, byType = {}, parked = 0, out = 0, impound = 0, held = 0, lost = 0, privateOwned = 0, fleetOut = 0, cars = 0 }
    for _, g in pairs(Garages.list) do
        s.garages = s.garages + 1
        s.byType[g.data.type] = (s.byType[g.data.type] or 0) + 1
    end
    for _ in pairs(Private.owners) do s.privateOwned = s.privateOwned + 1 end
    for _ in pairs(Fleet.out) do s.fleetOut = s.fleetOut + 1 end
    local rows = MySQL.query.await('SELECT plate, state, depotprice FROM player_vehicles') or {}
    for _, r in ipairs(rows) do
        s.cars = s.cars + 1
        local st = Vehicles.Status(r)
        s[st == 'parked' and 'parked' or st] = (s[st == 'parked' and 'parked' or st] or 0) + 1
    end
    local week = MySQL.single.await('SELECT COUNT(*) AS n, COALESCE(SUM(amount), 0) AS total FROM xs_garages_logs WHERE at > ? AND kind IN (?, ?, ?)', { os.time() - 7 * 86400, 'release', 'takeout', 'park' })
    s.weekFees = tonumber(week and week.total) or 0
    return s
end

function Builder.System()
    local phone
    for _, name in ipairs({ 'XS-Phone', 'lb-phone', 'qs-smartphone-pro', 'qs-smartphone', 'yseries', 'gksphone', 'okokPhone', 'npwd' }) do
        if running(name) then phone = name break end
    end
    return {
        framework = Framework.name, target = Config.Bridges.target, keys = Keys.name, banking = Banking.Ready() and Banking.name or nil,
        housing = running('XS-Housing') and 'XS-Housing' or nil, police = running('XS-PoliceSystem') and 'XS-PoliceSystem' or nil, phone = phone,
        oldGarage = (running('qb-garages') and 'qb-garages') or (running('qbx_garages') and 'qbx_garages') or (running('jg-advancedgarages') and 'jg-advancedgarages') or nil,
    }
end

function Builder.Data(src)
    local parked = counts()
    local list = {}
    for _, g in pairs(Garages.list) do list[#list + 1] = record(g, parked) end
    table.sort(list, function(a, b) return a.id < b.id end)
    local external = {}
    for key, g in pairs(Garages.external) do
        external[#external + 1] = { key = key, label = g.data.label, resource = g.resource, category = g.data.category, spots = #g.data.spawns, parked = parked[key] or 0, shared = g.data.shared }
    end
    table.sort(external, function(a, b) return a.label < b.label end)
    local standard = {}
    for _, e in ipairs(Standard or {}) do
        standard[#standard + 1] = { id = e.id, label = e.label, type = e.type, category = e.category, added = Garages.byKey[e.id] ~= nil, desk = e.desk }
    end
    local vehicles = {}
    for _, v in ipairs(Framework.Vehicles() or {}) do vehicles[#vehicles + 1] = { model = v.model, label = v.label } end
    return {
        garages = list, external = external, standard = standard, stats = Builder.Stats(), system = Builder.System(), rights = rights(),
        jobs = Framework.Jobs(), gangs = Framework.Gangs(), vehicles = vehicles, settings = Settings.Builder(),
        me = { name = Framework.GetName(src) or GetPlayerName(src) or '' }, ace = (Config.Admin or {}).acePermission or 'xs.garages.admin',
        command = Config.Commands.builder,
    }
end

local function guard(src)
    if not Builder.Allowed(src) then return false, Text('err_not_admin') end
    return true
end

lib.callback.register('XS-Garages:server:builderData', function(src)
    local ok, why = guard(src)
    if not ok then return false, why end
    return true, Builder.Data(src)
end)

lib.callback.register('XS-Garages:server:builderSave', function(src, id, data)
    local ok, why = guard(src)
    if not ok then return false, why end
    id = tonumber(id)
    local before = id and Garages.list[id] and Util.Copy(Garages.list[id].data) or nil
    local g, e = Garages.Save(id, data)
    if not g then return false, e end
    if before and before.key ~= g.data.key then
        MySQL.update.await('UPDATE player_vehicles SET garage = ? WHERE garage = ?', { g.data.key, before.key })
        Display.bays[before.key] = nil
    end
    Display.Rebuild(g.data.key)
    TriggerClientEvent('XS-Garages:client:display', -1, g.data.key)
    Logs.Add(id and 'admin' or 'create', g.data.key, '', Logs.Who(src), id and Text('log_saved') or Text('log_created'))
    Garages.Changed()
    return true, record(g, counts())
end)

lib.callback.register('XS-Garages:server:builderDelete', function(src, id)
    local ok, why = guard(src)
    if not ok then return false, why end
    if not right('delete') then return false, Text('err_no_right') end
    local g = Garages.list[tonumber(id) or 0]
    if not g then return false, Text('err_no_garage') end
    local key = g.data.key
    local target = Garages.Nearest(g.data.desks[1] or g.data.spawns[1] or { x = 0, y = 0, z = 0 }, g.data.category, 'public', key)
    Garages.Delete(g.id)
    if target and target.data.key ~= key then
        for _, r in ipairs(Vehicles.ParkedAt(key)) do Vehicles.SetMeta(r.plate, { bay = 0 }) end
        MySQL.update.await('UPDATE player_vehicles SET garage = ? WHERE garage = ? AND state = 1', { target.data.key, key })
    end
    Display.bays[key] = nil
    TriggerClientEvent('XS-Garages:client:display', -1, key)
    Logs.Add('delete', key, '', Logs.Who(src), g.data.label)
    Garages.Changed()
    return true, { movedTo = target and target.data.label or '' }
end)

lib.callback.register('XS-Garages:server:builderStandard', function(src, ids)
    local ok, why = guard(src)
    if not ok then return false, why end
    local made = Garages.SeedStandard(ids == 'all' and 'all' or (type(ids) == 'table' and ids or {}))
    if made > 0 then
        Logs.Add('create', '', '', Logs.Who(src), Text('log_standard', { n = made }))
        Garages.Changed()
    end
    return true, Builder.Data(src)
end)

lib.callback.register('XS-Garages:server:builderCars', function(src, filter)
    local ok, why = guard(src)
    if not ok then return false, why end
    filter = type(filter) == 'table' and filter or {}
    local where, args = {}, {}
    local q = Util.Text(filter.q, 48)
    if q ~= '' then
        local like = '%' .. q:gsub('[%%_]', '') .. '%'
        where[#where + 1] = '(plate LIKE ? OR citizenid = ? OR vehicle LIKE ?)'
        args[#args + 1], args[#args + 2], args[#args + 3] = like, q, like
        local cids = MySQL.query.await("SELECT citizenid FROM players WHERE charinfo LIKE ? LIMIT 25", { like }) or {}
        if #cids > 0 then
            local list = {}
            for _, c in ipairs(cids) do list[#list + 1] = c.citizenid end
            where[#where] = ('(plate LIKE ? OR citizenid = ? OR vehicle LIKE ? OR citizenid IN (%s))'):format(('?,'):rep(#list):sub(1, -2))
            for _, c in ipairs(list) do args[#args + 1] = c end
        end
    end
    if type(filter.garage) == 'string' and filter.garage ~= '' then
        where[#where + 1] = 'garage = ?'
        args[#args + 1] = filter.garage
    end
    local sql = 'SELECT * FROM player_vehicles'
    if #where > 0 then sql = sql .. ' WHERE ' .. table.concat(where, ' AND ') end
    sql = sql .. ' LIMIT 200'
    local rows = MySQL.query.await(sql, args) or {}
    local metas = Vehicles.Metas(rows)
    local out = {}
    for _, r in ipairs(rows) do
        local card = Vehicles.Card(r, metas[Util.Plate(r.plate)], nil, nil)
        card.owner = Vehicles.OwnerName(r.citizenid)
        card.cid = r.citizenid
        if not filter.status or filter.status == 'all' or filter.status == card.status then out[#out + 1] = card end
    end
    table.sort(out, function(a, b) return a.plate < b.plate end)
    return true, out
end)

lib.callback.register('XS-Garages:server:builderCar', function(src, plate, action, payload)
    local ok, why = guard(src)
    if not ok then return false, why end
    if not right('vehicles') then return false, Text('err_no_right') end
    local row = Vehicles.Row(plate)
    if not row then return false, Text('err_no_car') end
    plate = Util.Plate(row.plate)
    payload = type(payload) == 'table' and payload or {}
    local who = Logs.Who(src)
    if action == 'garage' then
        local g = Garages.Get(payload.garage)
        if not g then return false, Text('err_no_garage') end
        local veh = Spawn.Find(plate)
        if veh then Spawn.Remove(veh) end
        if row.garage then Display.Clear(row.garage, plate) end
        Vehicles.Update(plate, { state = 1, garage = g.data.key, depotprice = 0 })
        Vehicles.SetMeta(plate, { bay = 0, parked_at = os.time() })
        MySQL.update.await('UPDATE xs_garages_impound SET done = 1 WHERE plate = ? AND done = 0', { plate })
        Logs.Add('admin', g.data.key, plate, who, Text('log_admin_garage', { garage = g.data.label }))
    elseif action == 'impound' then
        local fee = math.max(0, math.floor(tonumber(payload.fee) or 0))
        local veh = Spawn.Find(plate)
        Impound.Do(plate, { fee = fee, hours = tonumber(payload.hours) or 0, reason = payload.reason or Text('log_admin_impound_reason'), officer = who.name, officerCid = who.citizenid })
        if veh then Spawn.Remove(veh) end
        Logs.Add('admin', '', plate, who, Text('log_admin_impound'), fee)
    elseif action == 'release' then
        Vehicles.Update(plate, { depotprice = 0, state = 1 })
        MySQL.update.await('UPDATE xs_garages_impound SET done = 1 WHERE plate = ? AND done = 0', { plate })
        Logs.Add('admin', row.garage or '', plate, who, Text('log_admin_release'))
    elseif action == 'fee' then
        local fee = math.max(0, math.floor(tonumber(payload.fee) or 0))
        Vehicles.Update(plate, { depotprice = fee })
        Logs.Add('admin', '', plate, who, Text('log_admin_fee'), fee)
    elseif action == 'remove' then
        if not right('removeCars') then return false, Text('err_no_right') end
        local veh = Spawn.Find(plate)
        if veh then Spawn.Remove(veh) end
        if row.garage then Display.Clear(row.garage, plate) end
        MySQL.query.await('DELETE FROM player_vehicles WHERE plate = ?', { row.plate })
        MySQL.query.await('DELETE FROM xs_garages_vehicles WHERE plate = ?', { plate })
        Logs.Add('admin', row.garage or '', plate, who, Text('log_admin_removed', { owner = Vehicles.OwnerName(row.citizenid) }))
    elseif action == 'where' then
        local veh = Spawn.Find(plate)
        if not veh then return false, Text('why_lost') end
        local c = GetEntityCoords(veh)
        return true, { x = c.x, y = c.y, z = c.z }
    else
        return false, Text('err_failed')
    end
    return true
end)

lib.callback.register('XS-Garages:server:builderOwner', function(src, id, action, payload)
    local ok, why = guard(src)
    if not ok then return false, why end
    if not right('owners') then return false, Text('err_no_right') end
    id = tonumber(id)
    local g = id and Garages.list[id]
    if not g or g.data.type ~= 'private' then return false, Text('err_no_garage') end
    payload = type(payload) == 'table' and payload or {}
    if action == 'clear' then
        Private.AdminSet(id, nil)
    elseif action == 'set' then
        local target = tonumber(payload.id)
        local cid = target and Framework.GetCitizenId(target)
        if not cid then return false, Text('err_no_player') end
        Private.AdminSet(id, cid, Framework.GetName(target), payload.kind)
    else
        return false, Text('err_failed')
    end
    Logs.Add('admin', g.data.key, '', Logs.Who(src), action == 'clear' and Text('log_owner_cleared') or Text('log_owner_set'))
    return true, record(g, counts())
end)

lib.callback.register('XS-Garages:server:builderPlayers', function(src, q)
    local ok, why = guard(src)
    if not ok then return false, why end
    q = Util.Text(q, 40):lower()
    local out = {}
    for _, id in ipairs(Framework.Players()) do
        local name = Framework.GetName(id) or GetPlayerName(id) or ''
        local cid = Framework.GetCitizenId(id) or ''
        if q == '' or name:lower():find(q, 1, true) or cid:lower() == q or tostring(id) == q then
            out[#out + 1] = { id = id, name = name, cid = cid }
        end
        if #out >= 20 then break end
    end
    return true, out
end)

lib.callback.register('XS-Garages:server:builderLogs', function(src, filter)
    local ok, why = guard(src)
    if not ok then return false, why end
    return true, Logs.Fetch(filter)
end)

lib.callback.register('XS-Garages:server:builderImpounds', function(src)
    local ok, why = guard(src)
    if not ok then return false, why end
    local rows = MySQL.query.await('SELECT * FROM player_vehicles WHERE depotprice > 0 OR state = 2 OR state = 3 LIMIT 300') or {}
    local metas = Vehicles.Metas(rows)
    local out = {}
    for _, r in ipairs(rows) do
        local card = Vehicles.Card(r, metas[Util.Plate(r.plate)], nil, nil)
        card.owner = Vehicles.OwnerName(r.citizenid)
        out[#out + 1] = card
    end
    table.sort(out, function(a, b) return a.plate < b.plate end)
    return true, out
end)

lib.callback.register('XS-Garages:server:builderTeleport', function(src)
    return Builder.Allowed(src)
end)
