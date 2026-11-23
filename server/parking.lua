Cabinet = { busy = {} }
Display = { bays = {} }

local function key(plate)
    return Util.Plate(plate):upper()
end

function Garages.GroupKey(g)
    local d = g and g.data
    if not d then return nil end
    if d.type == 'job' and d.job.name ~= '' then return 'job:' .. d.job.name end
    if d.type == 'gang' and d.gang.name ~= '' then return 'gang:' .. d.gang.name end
    return nil
end

local function err(name, vars)
    return false, Text(name, vars)
end

local function ownerStillIn(g, cid)
    if type(g.canAccess) ~= 'function' and type(g.canAccess) ~= 'table' then return true end
    local ok, yes = pcall(g.canAccess, cid)
    return ok and yes == true
end

local function drove(src, ped, veh, plate)
    if GetPedInVehicleSeat(veh, -1) == ped then return true end
    local okLast, last = pcall(GetLastPedInVehicleSeat, veh, -1)
    if okLast and last == ped then return true end
    return (Config.Parking or {}).keysParkers ~= false and Keys.Has(src, veh, plate) == true
end

local function categoryOf(veh, class)
    local ok, kind = pcall(GetVehicleType, veh)
    if ok and type(kind) == 'string' and kind ~= '' then
        if kind == 'boat' or kind == 'submarine' then return 'boat' end
        if kind == 'heli' or kind == 'plane' then return 'air' end
        return 'car'
    end
    return Util.CategoryOfClass(class)
end

local function noPersonal(g, card, group)
    local d = g.data
    if d.type ~= 'job' and d.type ~= 'gang' then return false end
    if d.personal then return false end
    return not (d.shared and card.shared == group)
end

local function prepare(src, garageKey, opts)
    opts = opts or {}
    local g = Garages.Get(garageKey)
    if not g then return nil, Text('err_no_garage') end
    local ok, why = Garages.Access(src, g)
    if not ok then return nil, why end
    if not opts.anywhere and not Garages.Near(src, g, opts.kinds or { 'desks', 'spawns', 'drops' }) then return nil, Text('err_too_far') end
    return g
end

function Display.Rebuild(garageKey)
    local g = Garages.Get(garageKey)
    Display.bays[garageKey] = {}
    if not g or not g.data.display then return end
    local rows = Vehicles.ParkedAt(garageKey)
    local metas = Vehicles.Metas(rows)
    for _, r in ipairs(rows) do
        local m = metas[Util.Plate(r.plate)] or {}
        r.shared = m.shared
        local bay = tonumber(m.bay)
        if bay and g.data.spawns[bay] and not Display.bays[garageKey][bay] then
            local model, hash = Vehicles.ModelOf(r)
            Display.bays[garageKey][bay] = { plate = Util.Plate(r.plate), model = model, hash = hash, props = Db.Decode(r.mods, {}), cid = r.citizenid, shared = r.shared or '' }
        end
    end
end

function Display.Load()
    Display.bays = {}
    for _, g in pairs(Garages.list) do
        if g.data.display then Display.Rebuild(g.data.key) end
    end
end

local function displayChanged(garageKey)
    TriggerClientEvent('XS-Garages:client:display', -1, garageKey)
end

function Display.FreeBay(g, near)
    local taken = Display.bays[g.data.key] or {}
    local best, bestDist = nil, math.huge
    for i, p in ipairs(g.data.spawns) do
        if not taken[i] then
            local dist = near and Util.Distance(near, p) or i
            if dist < bestDist then best, bestDist = i, dist end
        end
    end
    if best and near and bestDist > 12.0 then
        for i in ipairs(g.data.spawns) do
            if not taken[i] then return i end
        end
    end
    return best
end

function Display.Set(garageKey, bay, entry)
    Display.bays[garageKey] = Display.bays[garageKey] or {}
    Display.bays[garageKey][bay] = entry
    displayChanged(garageKey)
end

function Display.Clear(garageKey, plate)
    local list = Display.bays[garageKey]
    if not list then return end
    for bay, e in pairs(list) do
        if key(e.plate) == key(plate) then
            list[bay] = nil
            displayChanged(garageKey)
            return bay
        end
    end
end

lib.callback.register('XS-Garages:server:display', function(src, garageKey)
    local g = Garages.Get(garageKey)
    if not g or not g.data.display or (Config.Display or {}).enabled == false then return {} end
    local cid = Framework.GetCitizenId(src)
    local job, gang = Framework.GetJob(src), Framework.GetGang(src)
    local out = {}
    for bay, e in pairs(Display.bays[garageKey] or {}) do
        local mine = e.cid == cid
        if not mine and e.shared ~= '' then
            mine = (job and e.shared == 'job:' .. job.name) or (gang and e.shared == 'gang:' .. gang.name) or false
        end
        out[#out + 1] = { bay = bay, plate = e.plate, hash = e.hash, props = e.props, mine = mine == true }
    end
    return out
end)

local function sortCards(cards)
    local order = { parked = 0, out = 1, impound = 2, held = 3, lost = 4 }
    table.sort(cards, function(a, b)
        if a.here ~= b.here then return a.here end
        if a.favourite ~= b.favourite then return a.favourite end
        if (order[a.status] or 9) ~= (order[b.status] or 9) then return (order[a.status] or 9) < (order[b.status] or 9) end
        return (a.nickname ~= '' and a.nickname or a.label) < (b.nickname ~= '' and b.nickname or b.label)
    end)
end

function Cabinet.Cards(src, g)
    local cid = Framework.GetCitizenId(src)
    local d = g.data
    local rows, seen = {}, {}
    local function add(list)
        for _, r in ipairs(list or {}) do
            local k = key(r.plate)
            if not seen[k] then
                seen[k] = true
                rows[#rows + 1] = r
            end
        end
    end
    local group = Garages.GroupKey(g)
    if d.type == 'job' or d.type == 'gang' then
        if d.personal then add(Vehicles.OfOwner(cid)) end
        if d.shared and group then add(Vehicles.SharedWith(group)) end
    elseif d.type == 'house' then
        add(Vehicles.OfOwner(cid))
        if d.shared then add(Vehicles.ParkedAt(d.key)) end
    elseif d.type == 'private' then
        add(Vehicles.OfOwner(cid))
        add(Vehicles.ParkedAt(d.key))
    else
        add(Vehicles.OfOwner(cid))
    end
    local metas = Vehicles.Metas(rows)
    local cards = {}
    for _, r in ipairs(rows) do
        local card = Vehicles.Card(r, metas[Util.Plate(r.plate)], g, cid)
        local keep = true
        if d.type == 'impound' then
            keep = card.mine and (card.status == 'impound' or card.status == 'held' or card.status == 'lost')
        elseif not card.mine then
            keep = card.here or (card.status == 'out' and card.shared ~= '' and card.shared == group)
            if d.type == 'private' then card.action = 'none' card.why = 'not_yours' end
        end
        if keep then cards[#cards + 1] = card end
    end
    sortCards(cards)
    return cards
end

function Cabinet.Data(src, g)
    local cid = Framework.GetCitizenId(src)
    local d = g.data
    local money = Framework.GetMoney(src)
    local job, gang = Framework.GetJob(src), Framework.GetGang(src)
    local out = {
        garage = {
            key = d.key, label = d.label, type = d.type, category = d.category, display = d.display, personal = d.personal, shared = d.shared,
            fees = { takeOut = Garages.Fee(g, 'takeOut'), park = Garages.Fee(g, 'park'), move = Garages.Fee(g, 'move') },
            spawns = #d.spawns, external = g.external == true,
        },
        me = { cid = cid, name = Framework.GetName(src) or '', cash = money.cash, bank = money.bank, job = job and job.label or nil, gang = gang and gang.label or nil },
        rules = {
            unit = (Config.Mileage or {}).unit or 'mi', mileage = (Config.Mileage or {}).enabled ~= false,
            transfer = (Config.Transfer or {}).toPlayer == true, transferFee = (Config.Transfer or {}).fee or 0, nearby = (Config.Transfer or {}).nearby ~= false,
            shareJob = (Config.Share or {}).job == true and job ~= nil and job.name ~= 'unemployed', shareGang = (Config.Share or {}).gang == true and gang ~= nil,
            jobLabel = job and job.label or nil, gangLabel = gang and gang.label or nil, anywhere = (Config.Parking or {}).anywhere == true,
        },
        cars = {}, fleet = {},
    }
    if d.type == 'private' then
        out.private = Private.Info(src, g)
        if not out.private.access then return out end
    end
    out.cars = Cabinet.Cards(src, g)
    if (d.type == 'job' or d.type == 'gang') and #d.fleet > 0 then out.fleet = Fleet.List(src, g) end
    return out
end

lib.callback.register('XS-Garages:server:open', function(src, garageKey)
    local g = Garages.Get(garageKey)
    if not g then return err('err_no_garage') end
    if g.data.type == 'private' and (Config.Private or {}).enabled then
        if not g.data.enabled then return err('err_closed') end
        if not Garages.Near(src, g, { 'desks', 'spawns', 'drops' }) then return err('err_too_far') end
        return true, Cabinet.Data(src, g)
    end
    local ok, why = Garages.Access(src, g)
    if not ok then return false, why end
    if not Garages.Near(src, g, { 'desks', 'spawns', 'drops' }) then return err('err_too_far') end
    return true, Cabinet.Data(src, g)
end)

local function reasonOf(card)
    local why = card.why or 'cannot'
    if why == 'held' and card.hold and card.hold.untilAt > 0 then
        return Text('why_held_until', { time = Util.Span(card.hold.untilAt - os.time()) })
    end
    if why == 'impound' and card.depot then return Text('why_impound', { fee = Util.Money(card.depot) }) end
    return Text('why_' .. why)
end

function Cabinet.TakeOut(src, g, plate, opts)
    opts = opts or {}
    local cid = Framework.GetCitizenId(src)
    local row = Vehicles.Row(plate)
    if not row then return err('err_no_car') end
    plate = Util.Plate(row.plate)
    local meta = Vehicles.Meta(plate)
    local card = Vehicles.Card(row, meta, g, cid)
    local group = Garages.GroupKey(g)
    local allowed = card.mine
    if not allowed and group and g.data.shared and card.shared == group and card.here then allowed = true end
    if not allowed and g.data.type == 'house' and g.data.shared and card.here and ownerStillIn(g, row.citizenid) then allowed = true end
    if not allowed then return err('err_not_yours') end
    if card.mine and noPersonal(g, card, group) then return err('err_no_personal') end
    if card.action ~= 'take' and card.action ~= 'release' and card.action ~= 'recover' then return false, reasonOf(card) end
    if card.category ~= '' and not Util.Fits(g.data.category, card.category) then return err('err_wrong_type') end
    if Spawn.Find(plate) then return err('why_out') end
    if Cabinet.busy[key(plate)] then return err('err_busy') end
    Cabinet.busy[key(plate)] = true
    local result = { pcall(function()
        local prefer = (g.data.display and (tonumber(meta.bay) or 0) > 0 and card.here) and tonumber(meta.bay) or nil
        if prefer then Display.Clear(g.data.key, plate) Wait(350) end
        local idx = Spawn.FreePoint(g.data.spawns, prefer, g.data.display and Display.bays[g.data.key] or nil)
        if not idx then return false, Text('err_blocked') end
        local fee = math.max(0, card.fee or 0)
        local account
        if fee > 0 then
            local paid, acct = Framework.Charge(src, fee, 'bank', 'xs-garages')
            if not paid then return false, Text('err_money', { fee = Util.Money(fee) }) end
            account = acct
        end
        local model, hash = Vehicles.ModelOf(row)
        local props = Db.Decode(row.mods, {})
        if type(props) ~= 'table' then props = {} end
        props.plate = plate
        props.model = tonumber(props.model) or hash
        if (Config.Parking or {}).keepDamage == false or card.action == 'recover' then
            props.engineHealth, props.bodyHealth, props.tankHealth = 1000.0, 1000.0, 1000.0
            props.windows, props.doors, props.tyres = nil, nil, nil
        end
        local fuel = (Config.Parking or {}).keepFuel == false and 100 or (tonumber(row.fuel) or tonumber(props.fuelLevel) or 100)
        props.fuelLevel = fuel
        local at = g.data.spawns[idx]
        local veh, netId = Spawn.Create(src, props.model or model, at, props, { fuel = fuel, lock = (Config.General or {}).lockOnSpawn })
        if not veh then
            if account then Framework.AddMoney(src, account, fee, 'xs-garages-refund') end
            return false, Text('err_spawn')
        end
        Spawn.Track(plate, veh, { cid = row.citizenid, src = src, garage = g.data.key })
        if not prefer and row.garage and (tonumber(meta.bay) or 0) > 0 then Display.Clear(row.garage, plate) end
        Vehicles.Update(plate, { state = 0, depotprice = 0 })
        Vehicles.SetMeta(plate, { bay = 0 })
        if card.action == 'release' or card.action == 'recover' then
            local society = (Config.Impound or {}).society
            if fee > 0 and society and society ~= '' and card.action == 'release' then Banking.Deposit(society, fee, 'Impound release ' .. plate) end
            MySQL.update.await('UPDATE xs_garages_impound SET done = 1 WHERE plate = ? AND done = 0', { plate })
            Logs.Add('release', g.data.key, plate, Logs.Who(src), card.action == 'recover' and Text('log_recovered') or Text('log_released'), fee)
        else
            Logs.Add('takeout', g.data.key, plate, Logs.Who(src), card.moving and Text('log_moved_out', { from = card.garageLabel }) or '', fee)
        end
        Keys.Give(src, veh, plate)
        return true, { netId = netId, plate = plate, fuel = fuel, props = props, warp = (Config.General or {}).warpIn ~= false, fade = (Config.General or {}).fade ~= false, fee = fee }
    end) }
    Cabinet.busy[key(plate)] = nil
    if not result[1] then
        print(('^1[XS-Garages]^0 taking out %s failed: %s'):format(plate, tostring(result[2])))
        return err('err_failed')
    end
    return result[2], result[3]
end

lib.callback.register('XS-Garages:server:takeOut', function(src, garageKey, plate)
    local g, why = prepare(src, garageKey)
    if not g then return false, why end
    return Cabinet.TakeOut(src, g, plate)
end)

lib.callback.register('XS-Garages:server:move', function(src, garageKey, plate)
    local g, why = prepare(src, garageKey)
    if not g then return false, why end
    local cid = Framework.GetCitizenId(src)
    local row = Vehicles.Row(plate)
    if not row or row.citizenid ~= cid then return err('err_not_yours') end
    local card = Vehicles.Card(row, Vehicles.Meta(row.plate), g, cid)
    if noPersonal(g, card, Garages.GroupKey(g)) then return err('err_no_personal') end
    if not card.canMove then return err('err_cannot_move') end
    if card.category ~= '' and not Util.Fits(g.data.category, card.category) then return err('err_wrong_type') end
    if g.data.type == 'private' and Vehicles.CountAt(g.data.key) >= (g.data.private.slots or 1) then return err('err_full') end
    local fee = card.moveFee or 0
    if fee > 0 and not Framework.Charge(src, fee, 'bank', 'xs-garages-move') then return err('err_money', { fee = Util.Money(fee) }) end
    local from = row.garage
    Vehicles.Update(row.plate, { garage = g.data.key })
    Vehicles.SetMeta(row.plate, { bay = 0, parked_at = os.time() })
    if from then Display.Clear(from, row.plate) end
    Logs.Add('move', g.data.key, Util.Plate(row.plate), Logs.Who(src), Text('log_moved', { from = card.garageLabel }), fee)
    return true, Cabinet.Data(src, g)
end)

lib.callback.register('XS-Garages:server:rename', function(src, plate, name)
    local row = Vehicles.Row(plate)
    if not row or row.citizenid ~= Framework.GetCitizenId(src) then return err('err_not_yours') end
    Vehicles.SetMeta(row.plate, { nickname = Util.Text(name, 24) })
    return true
end)

lib.callback.register('XS-Garages:server:favourite', function(src, plate, on)
    local row = Vehicles.Row(plate)
    if not row or row.citizenid ~= Framework.GetCitizenId(src) then return err('err_not_yours') end
    Vehicles.SetMeta(row.plate, { favourite = on and 1 or 0 })
    return true
end)

lib.callback.register('XS-Garages:server:share', function(src, plate, kind)
    local row = Vehicles.Row(plate)
    if not row or row.citizenid ~= Framework.GetCitizenId(src) then return err('err_not_yours') end
    local value = ''
    if kind == 'job' and (Config.Share or {}).job then
        local job = Framework.GetJob(src)
        if not job or job.name == 'unemployed' then return err('err_no_job') end
        value = 'job:' .. job.name
    elseif kind == 'gang' and (Config.Share or {}).gang then
        local gang = Framework.GetGang(src)
        if not gang then return err('err_no_gang') end
        value = 'gang:' .. gang.name
    elseif kind ~= '' and kind ~= nil then
        return err('err_failed')
    end
    Vehicles.SetMeta(row.plate, { shared = value })
    Logs.Add('share', row.garage or '', Util.Plate(row.plate), Logs.Who(src), value ~= '' and value or Text('log_unshared'))
    return true
end)

lib.callback.register('XS-Garages:server:nearby', function(src)
    local me = GetPlayerPed(src)
    if not me or me == 0 then return {} end
    local pos = GetEntityCoords(me)
    local range = (Config.Transfer or {}).range or 6.0
    local out = {}
    for _, other in ipairs(Framework.Players()) do
        if other ~= src then
            local ped = GetPlayerPed(other)
            if ped and ped ~= 0 and #(GetEntityCoords(ped) - pos) <= range then
                out[#out + 1] = { id = other, name = Framework.GetName(other) or GetPlayerName(other) or ('#' .. other) }
            end
        end
    end
    return out
end)

lib.callback.register('XS-Garages:server:give', function(src, plate, target)
    local T = Config.Transfer or {}
    if not T.toPlayer then return err('err_off') end
    target = tonumber(target)
    if not target or target == src or not Framework.GetPlayer(target) then return err('err_no_player') end
    local cid = Framework.GetCitizenId(src)
    local row = Vehicles.Row(plate)
    if not row or row.citizenid ~= cid then return err('err_not_yours') end
    if tonumber(row.state) ~= 1 or (tonumber(row.depotprice) or 0) > 0 then return err('err_park_first') end
    if T.nearby ~= false then
        local a, b = GetPlayerPed(src), GetPlayerPed(target)
        if #(GetEntityCoords(a) - GetEntityCoords(b)) > (T.range or 6.0) + 1.0 then return err('err_too_far_player') end
    end
    local fee = T.fee or 0
    if fee > 0 and not Framework.Charge(src, fee, 'bank', 'xs-garages-transfer') then return err('err_money', { fee = Util.Money(fee) }) end
    local newCid = Framework.GetCitizenId(target)
    local fields = { citizenid = newCid }
    if Db.columns.license then fields.license = Framework.License(target) end
    Vehicles.Update(row.plate, fields)
    Vehicles.SetMeta(row.plate, { nickname = '', favourite = 0, shared = '' })
    local p = Util.Plate(row.plate)
    Logs.Add('transfer', row.garage or '', p, Logs.Who(src), Text('log_gave_to', { name = Framework.GetName(target) or '' }), fee)
    Framework.Notify(target, Text('got_car', { name = Framework.GetName(src) or '', plate = p }), 'success')
    return true
end)

lib.callback.register('XS-Garages:server:track', function(src, plate)
    local row = Vehicles.Row(plate)
    if not row then return err('err_no_car') end
    local cid = Framework.GetCitizenId(src)
    local meta = Vehicles.Meta(row.plate)
    local job, gang = Framework.GetJob(src), Framework.GetGang(src)
    local allowed = row.citizenid == cid or (meta.shared ~= '' and ((job and meta.shared == 'job:' .. job.name) or (gang and meta.shared == 'gang:' .. gang.name)))
    if not allowed then return err('err_not_yours') end
    local veh = Spawn.Find(row.plate)
    if not veh then return err('why_lost') end
    local c = GetEntityCoords(veh)
    return true, { x = c.x, y = c.y, z = c.z }
end)

lib.callback.register('XS-Garages:server:findCars', function(src)
    if (Config.Lost or {}).findCommand == false then return err('err_off') end
    local out = {}
    for _, row in ipairs(Vehicles.OfOwner(Framework.GetCitizenId(src))) do
        if tonumber(row.state) == 0 and (tonumber(row.depotprice) or 0) == 0 then
            local veh = Spawn.Find(row.plate)
            if veh then
                local c = GetEntityCoords(veh)
                local model, hash = Vehicles.ModelOf(row)
                out[#out + 1] = { plate = Util.Plate(row.plate), label = Vehicles.Label(model, hash), x = c.x, y = c.y, z = c.z }
            end
        end
    end
    return true, out
end)

function Cabinet.Park(src, g, veh, data)
    local d = g.data
    local cid = Framework.GetCitizenId(src)
    local ped = GetPlayerPed(src)
    local pos = GetEntityCoords(veh)
    local here = { x = pos.x, y = pos.y, z = pos.z }
    local radius = (d.dropRadius or 0) > 0 and d.dropRadius or ((Config.Parking or {}).parkRadius or 6.0)
    if d.category ~= 'car' then radius = radius + 20.0 end
    local close = false
    for _, p in ipairs(d.drops) do if Util.Distance(here, p) <= radius + 2.5 then close = true break end end
    if not close and d.display then
        for _, p in ipairs(d.spawns) do if Util.Distance(here, p) <= 4.5 then close = true break end end
    end
    if not close then return err('err_not_on_spot') end
    if #(GetEntityCoords(ped) - pos) > 12.0 then return err('err_too_far') end
    if d.type == 'impound' then return err('err_impound_park') end
    local plate = Util.Plate(GetVehicleNumberPlateText(veh))
    local fleet = Fleet.Of(plate)
    if fleet then return Fleet.Return(src, g, veh, fleet) end
    local row = Vehicles.Row(plate)
    if not row then return err('err_not_owned') end
    local meta = Vehicles.Meta(plate)
    local category = categoryOf(veh, data.class)
    if not Util.Fits(d.category, category) then return err('err_wrong_type') end
    local mine = row.citizenid == cid
    local group = Garages.GroupKey(g)
    local P = Config.Parking or {}
    if d.type == 'job' or d.type == 'gang' then
        if mine and not d.personal and not (d.shared and meta.shared == group) then return err('err_no_personal') end
        if not mine and not (d.shared and meta.shared == group) then return err('err_not_yours') end
    elseif d.type == 'house' then
        if not mine and not d.shared then return err('err_not_yours') end
        if not mine and not drove(src, ped, veh, plate) then return err('err_not_yours') end
    elseif not mine then
        if P.ownerOnly then return err('err_not_yours') end
        if not drove(src, ped, veh, plate) then return err('err_not_yours') end
    end
    if d.type == 'private' then
        local used = Vehicles.CountAt(d.key)
        if used >= (d.private.slots or 1) then return err('err_full') end
    end
    if P.passengersOut ~= false then
        for seat = -1, 8 do
            local other = GetPedInVehicleSeat(veh, seat)
            if other and other ~= 0 and IsPedAPlayer(other) then return err('err_passengers') end
        end
    end
    local engine = Util.Clamp(tonumber(data.engine) or 1000, -4000, 1000)
    local body = Util.Clamp(tonumber(data.body) or 1000, 0, 1000)
    if (P.minEngine or 0) > 0 and engine < P.minEngine then return err('err_wrecked') end
    local fee = Garages.Fee(g, 'park')
    if fee > 0 and not Framework.Charge(src, fee, 'bank', 'xs-garages-park') then return err('err_money', { fee = Util.Money(fee) }) end
    local props = type(data.props) == 'table' and data.props or Db.Decode(row.mods, {})
    if type(props) ~= 'table' then props = {} end
    props.plate = plate
    props.model = GetEntityModel(veh)
    local encoded = Db.Json(props)
    if #encoded > 60000 then encoded = row.mods or '{}' end
    local fuel = Util.Clamp(tonumber(data.fuel) or 100, 0, 100)
    local bay = 0
    if d.display and (Config.Display or {}).enabled ~= false then bay = Display.FreeBay(g, here) or 0 end
    local add = Util.Clamp(tonumber(data.mileage) or 0, 0, 500000)
    Vehicles.Update(plate, { state = 1, garage = d.key, mods = encoded, fuel = math.floor(fuel), engine = Util.Round(engine, 1), body = Util.Round(body, 1), depotprice = 0 })
    Vehicles.SetMeta(plate, { category = category, parked_at = os.time(), bay = bay, mileage = (tonumber(meta.mileage) or 0) + add })
    if row.garage and row.garage ~= d.key then Display.Clear(row.garage, plate) end
    Spawn.Remove(veh)
    if bay > 0 then
        local model, hash = Vehicles.ModelOf({ vehicle = row.vehicle, hash = props.model, mods = props })
        Display.Set(d.key, bay, { plate = plate, model = model, hash = props.model or hash, props = props, cid = row.citizenid, shared = meta.shared or '' })
    end
    Logs.Add('park', d.key, plate, Logs.Who(src), mine and '' or Text('log_parked_for', { name = Vehicles.OwnerName(row.citizenid) }), fee)
    return true, { fee = fee, bay = bay }
end

lib.callback.register('XS-Garages:server:park', function(src, garageKey, netId, data)
    local g = Garages.Get(garageKey)
    if not g then return err('err_no_garage') end
    local ok, why = Garages.Access(src, g)
    if not ok then return false, why end
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return err('err_no_vehicle') end
    if GetEntityType(veh) ~= 2 then return err('err_no_vehicle') end
    local res = { pcall(Cabinet.Park, src, g, veh, type(data) == 'table' and data or {}) }
    if not res[1] then
        print(('^1[XS-Garages]^0 parking failed: %s'):format(tostring(res[2])))
        return err('err_failed')
    end
    return res[2], res[3]
end)
