Garages = { list = {}, byKey = {}, external = {}, ready = false }

local LOOKS = { ped = true, prop = true, marker = true, none = true }
local OPENS = { key = true, target = true }
local MODES = { borrow = true, buy = true }

local function points(list, max)
    local out = {}
    for _, p in ipairs(type(list) == 'table' and list or {}) do
        local clean = Util.Point(p)
        if clean and #out < (max or 40) then out[#out + 1] = clean end
    end
    return out
end

local function int(v, d, lo, hi)
    local n = math.floor((tonumber(v) or d) + 0.5)
    if lo and n < lo then n = lo end
    if hi and n > hi then n = hi end
    return n
end

local function fleetEntry(e)
    if type(e) ~= 'table' then return nil end
    local model = Util.Slug(e.model, 32)
    if model == '' then return nil end
    local extras = {}
    for _, x in ipairs(type(e.extras) == 'table' and e.extras or {}) do
        local n = tonumber(x)
        if n and n >= 0 and n <= 20 and #extras < 20 then extras[#extras + 1] = math.floor(n) end
    end
    return {
        model = model, label = Util.Text(e.label, 40), grade = int(e.grade, 0, 0, 50), livery = int(e.livery, -1, -1, 80),
        extras = extras, color1 = int(e.color1, -1, -1, 160), color2 = int(e.color2, -1, -1, 160), tuned = e.tuned == true,
        plate = Util.Text(e.plate, 4):upper():gsub('[^%w]', ''), mode = MODES[e.mode] and e.mode or 'borrow',
        price = int(e.price, 0, 0, 100000000), limit = int(e.limit, 0, 0, 100),
    }
end

function Garages.Clean(d, id)
    d = type(d) == 'table' and d or {}
    local out = {}
    out.label = Util.Text(d.label, 48)
    if out.label == '' then out.label = Text('garage_unnamed') end
    out.key = Util.Slug(d.key, 50)
    out.type = Util.Has(Util.TYPES, d.type) and d.type or 'public'
    out.category = Util.Has(Util.CATEGORIES, d.category) and d.category or 'car'
    out.enabled = d.enabled ~= false
    out.desks = points(d.desks, 12)
    out.drops = points(d.drops, 20)
    out.spawns = points(d.spawns, 60)
    out.dropRadius = Util.Round(Util.Clamp(tonumber(d.dropRadius) or 0, 0, 40), 1)
    out.display = d.display == true
    local look = type(d.look) == 'table' and d.look or {}
    out.look = {
        desk = LOOKS[look.desk] and look.desk or 'ped',
        ped = Util.Slug(look.ped, 48), scenario = Util.Text(look.scenario, 64):upper():gsub('[^%w_]', ''), prop = Util.Slug(look.prop, 48),
        open = OPENS[look.open] and look.open or '',
    }
    local blip = type(d.blip) == 'table' and d.blip or {}
    out.blip = { show = blip.show ~= false, sprite = int(blip.sprite, 0, 0, 900), colour = int(blip.colour, -1, -1, 85), label = Util.Text(blip.label, 40) }
    local job = type(d.job) == 'table' and d.job or {}
    out.job = { name = Util.Slug(job.name, 48), grade = int(job.grade, 0, 0, 50), duty = job.duty == true }
    local gang = type(d.gang) == 'table' and d.gang or {}
    out.gang = { name = Util.Slug(gang.name, 48), grade = int(gang.grade, 0, 0, 50) }
    out.personal = d.personal ~= false
    out.shared = d.shared ~= false
    out.fleet = {}
    for _, e in ipairs(type(d.fleet) == 'table' and d.fleet or {}) do
        local clean = fleetEntry(e)
        if clean and #out.fleet < 40 then out.fleet[#out.fleet + 1] = clean end
    end
    local fees = type(d.fees) == 'table' and d.fees or {}
    out.fees = { takeOut = int(fees.takeOut, -1, -1, 1000000), park = int(fees.park, -1, -1, 1000000), move = int(fees.move, -1, -1, 1000000) }
    local p = type(d.private) == 'table' and d.private or {}
    out.private = {
        price = int(p.price, 50000, 0, 100000000), rent = int(p.rent, 1500, 0, 10000000), slots = int(p.slots, 4, 1, 100),
        buy = p.buy ~= false, rentable = p.rentable ~= false,
    }
    local imp = type(d.impound) == 'table' and d.impound or {}
    out.impound = { lost = imp.lost ~= false }
    out.standard = Util.Slug(d.standard, 48)
    out.notes = Util.Text(d.notes, 400)
    if out.key == '' and id then out.key = ('g%d'):format(id) end
    return out
end

local function index()
    Garages.byKey = {}
    for id, g in pairs(Garages.list) do Garages.byKey[g.data.key] = g end
    for key, g in pairs(Garages.external) do Garages.byKey[key] = g end
end

function Garages.Load()
    local rows = MySQL.query.await('SELECT id, data FROM xs_garages') or {}
    Garages.list = {}
    for _, row in ipairs(rows) do
        local id = tonumber(row.id)
        Garages.list[id] = { id = id, data = Garages.Clean(Db.Decode(row.data, {}), id) }
    end
    index()
    Garages.ready = true
end

function Garages.Get(key)
    if key == nil then return nil end
    if type(key) == 'number' then return Garages.list[key] end
    local n = tonumber(key)
    if n and Garages.list[n] and not Garages.byKey[key] then return Garages.list[n] end
    return Garages.byKey[tostring(key)]
end

function Garages.All()
    local out = {}
    for _, g in pairs(Garages.list) do out[#out + 1] = g end
    for _, g in pairs(Garages.external) do out[#out + 1] = g end
    table.sort(out, function(a, b) return (a.id or 1e9) < (b.id or 1e9) end)
    return out
end

function Garages.KeyFree(key, id)
    local g = Garages.byKey[key]
    return not g or (id and g.id == id)
end

function Garages.Save(id, data)
    local now = os.time()
    if id then
        local g = Garages.list[id]
        if not g then return nil, Text('err_no_garage') end
        local clean = Garages.Clean(data, id)
        if not Garages.KeyFree(clean.key, id) then clean.key = ('g%d'):format(id) end
        MySQL.update.await('UPDATE xs_garages SET data = ?, updated_at = ? WHERE id = ?', { Db.Json(clean), now, id })
        g.data = clean
        index()
        return g
    end
    local clean = Garages.Clean(data)
    local newId = MySQL.insert.await('INSERT INTO xs_garages (data, created_at, updated_at) VALUES (?, ?, ?)', { Db.Json(clean), now, now })
    if not newId then return nil, Text('err_failed') end
    if clean.key == '' or not Garages.KeyFree(clean.key) then clean.key = ('g%d'):format(newId) end
    MySQL.update.await('UPDATE xs_garages SET data = ? WHERE id = ?', { Db.Json(clean), newId })
    local g = { id = newId, data = clean }
    Garages.list[newId] = g
    index()
    return g
end

function Garages.Delete(id)
    local g = Garages.list[id]
    if not g then return false end
    MySQL.query.await('DELETE FROM xs_garages WHERE id = ?', { id })
    MySQL.query.await('DELETE FROM xs_garages_owners WHERE garage_id = ?', { id })
    Garages.list[id] = nil
    index()
    return true
end

function Garages.Standard(entry)
    local data = {
        key = entry.id, label = entry.label, type = entry.type, category = entry.category, enabled = entry.type ~= 'gang',
        desks = { entry.desk }, drops = { entry.spawn }, spawns = { entry.spawn }, standard = entry.id,
        look = { desk = 'ped' },
        job = { name = entry.job or '', grade = 0, duty = entry.type == 'job' },
        gang = { name = entry.gang or '', grade = 0 },
    }
    if entry.type == 'job' and entry.job == 'police' then
        data.fleet = {
            { model = 'police', label = 'Police Cruiser', grade = 0, plate = 'LSPD' },
            { model = 'police2', label = 'Buffalo Cruiser', grade = 1, plate = 'LSPD' },
            { model = 'police3', label = 'Interceptor', grade = 2, plate = 'LSPD' },
            { model = 'policeb', label = 'Police Bike', grade = 0, plate = 'LSPD' },
        }
    end
    return data
end

function Garages.SeedStandard(ids)
    local made = 0
    local want = {}
    if type(ids) == 'table' then for _, id in ipairs(ids) do want[id] = true end end
    for _, entry in ipairs(Standard or {}) do
        if (ids == 'all' or want[entry.id]) and not Garages.byKey[entry.id] then
            local g = Garages.Save(nil, Garages.Standard(entry))
            if g then made = made + 1 end
        end
    end
    return made
end

function Garages.FirstStart()
    local seeded = MySQL.single.await('SELECT data FROM xs_garages_settings WHERE name = ?', { 'seeded' })
    if seeded then return end
    if (Config.Builder or {}).standardOnFirstStart ~= false and next(Garages.list) == nil then
        local made = Garages.SeedStandard('all')
        print(('^2[XS-Garages]^0 Added %d standard garages and impound lots. Change them in /%s.'):format(made, Config.Commands.builder))
    end
    MySQL.query.await('INSERT INTO xs_garages_settings (name, data) VALUES (?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)', { 'seeded', tostring(os.time()) })
end

function Garages.Register(key, opts, resource)
    key = tostring(key or '')
    if key == '' or type(opts) ~= 'table' then return false end
    local desks, drops, spawns = {}, {}, {}
    for _, ap in ipairs(type(opts.accessPoints) == 'table' and opts.accessPoints or {}) do
        local coords = Util.Point(ap.coords)
        local spawn = Util.Point(ap.spawn) or coords
        local drop = Util.Point(ap.dropPoint) or spawn
        if coords then desks[#desks + 1] = coords end
        if drop then drops[#drops + 1] = drop end
        if spawn then spawns[#spawns + 1] = spawn end
    end
    if #spawns == 0 then return false end
    local cat = ({ car = 'car', air = 'air', sea = 'boat', boat = 'boat' })[opts.vehicleType or 'car'] or 'car'
    Garages.external[key] = {
        key = key, external = true, resource = resource or GetInvokingResource() or '', canAccess = opts.canAccess, groups = opts.groups,
        data = {
            key = key, label = Util.Text(opts.label, 48) ~= '' and Util.Text(opts.label, 48) or key, type = 'house', category = cat, enabled = true,
            desks = desks, drops = drops, spawns = spawns, dropRadius = 0, display = false, look = { desk = 'marker' },
            blip = { show = false, sprite = 0, colour = -1, label = '' }, job = { name = '', grade = 0 }, gang = { name = '', grade = 0 },
            personal = true, shared = opts.shared == true, fleet = {}, fees = { takeOut = 0, park = 0, move = -1 },
            private = {}, impound = {}, notes = '',
        },
    }
    index()
    Garages.Changed()
    return true
end

function Garages.Unregister(key)
    if not Garages.external[key] then return false end
    Garages.external[key] = nil
    index()
    Garages.Changed()
    return true
end

local changedQueued = false

function Garages.Changed()
    if changedQueued then return end
    changedQueued = true
    SetTimeout(500, function()
        changedQueued = false
        TriggerClientEvent('XS-Garages:client:refresh', -1)
    end)
end

function Garages.Blip(d)
    local B = Config.Blips or {}
    local base = B[d.type] or B.public or {}
    if d.type == 'public' and d.category == 'boat' then base = B.boat or base end
    if d.type == 'public' and d.category == 'air' then base = B.air or base end
    return {
        show = d.blip.show ~= false and (Config.General or {}).blips ~= false,
        sprite = (d.blip.sprite or 0) > 0 and d.blip.sprite or base.sprite or 357,
        colour = (d.blip.colour or -1) >= 0 and d.blip.colour or base.colour or (B.public or {}).colour or 3,
        label = (d.blip.label or '') ~= '' and d.blip.label or d.label,
    }
end

local function groupOk(src, d)
    if d.type == 'job' then
        local job = Framework.GetJob(src)
        if not job or job.name ~= d.job.name then return false, 'err_wrong_job' end
        if (job.grade or 0) < (d.job.grade or 0) and not job.isBoss then return false, 'err_low_grade' end
        if d.job.duty and not job.onDuty then return false, 'err_off_duty' end
        return true
    elseif d.type == 'gang' then
        local gang = Framework.GetGang(src)
        if not gang or gang.name ~= d.gang.name then return false, 'err_wrong_gang' end
        if (gang.grade or 0) < (d.gang.grade or 0) and not gang.isBoss then return false, 'err_low_grade' end
        return true
    end
    return true
end

function Garages.Access(src, g)
    if not g then return false, Text('err_no_garage') end
    local d = g.data
    if not d.enabled then return false, Text('err_closed') end
    if d.type == 'job' or d.type == 'gang' then
        local ok, why = groupOk(src, d)
        if not ok then return false, Text(why) end
        return true
    elseif d.type == 'private' then
        if not (Config.Private or {}).enabled then return false, Text('err_closed') end
        if Private.HasAccess(src, g.id) then return true end
        return false, Text('err_not_yours')
    elseif d.type == 'house' then
        if type(g.canAccess) ~= 'function' and type(g.canAccess) ~= 'table' then return true end
        local ok, allowed = pcall(g.canAccess, src)
        if ok and allowed then return true end
        return false, Text('err_not_yours')
    end
    return true
end

function Garages.Near(src, g, kinds, extra)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local pos = GetEntityCoords(ped)
    local here = { x = pos.x, y = pos.y, z = pos.z }
    local radius = (g.data.dropRadius or 0) > 0 and g.data.dropRadius or ((Config.Parking or {}).parkRadius or 6.0)
    for _, kind in ipairs(kinds) do
        local list, reach = g.data[kind], 6.0
        if kind == 'drops' or kind == 'spawns' then reach = radius + 6.0 end
        if g.data.category ~= 'car' then reach = reach + 25.0 end
        for _, p in ipairs(list or {}) do
            if Util.Distance(here, p) <= reach + (extra or 0) then return true end
        end
    end
    return false
end

function Garages.Fee(g, kind)
    local d = g.data
    local own = d.fees and d.fees[kind]
    if own and own >= 0 then return own end
    local P = Config.Parking or {}
    if kind == 'takeOut' then return P.takeOutFee or 0 end
    if kind == 'park' then return P.parkFee or 0 end
    if kind == 'move' then return P.moveFee or 0 end
    return 0
end

function Garages.ForPlayer(src)
    local cid = Framework.GetCitizenId(src)
    local out = {}
    for _, g in ipairs(Garages.All()) do
        local d = g.data
        if d.enabled then
            local entry = {
                key = d.key, id = g.id, label = d.label, type = d.type, category = d.category, desks = d.desks, drops = d.drops, spawns = d.spawns,
                dropRadius = d.dropRadius, display = d.display and (Config.Display or {}).enabled ~= false, look = d.look, blip = Garages.Blip(d),
                job = d.type == 'job' and d.job or nil, gang = d.type == 'gang' and d.gang or nil, external = g.external == true,
            }
            if d.type == 'private' then
                local o = Private.owners[g.id]
                entry.private = {
                    owned = o ~= nil, mine = o ~= nil and o.citizenid == cid, access = Private.HasAccess(src, g.id),
                    price = d.private.price, rent = d.private.rent, buy = d.private.buy, rentable = d.private.rentable,
                }
            elseif d.type == 'house' then
                local ok = Garages.Access(src, g)
                entry.access = ok == true
            end
            out[#out + 1] = entry
        end
    end
    return out
end

function Garages.Nearest(pos, category, wantType, skip)
    local best, bestDist = nil, math.huge
    for _, g in pairs(Garages.list) do
        local d = g.data
        if d.enabled and d.key ~= skip and d.type == (wantType or 'public') and Util.Fits(d.category, category) then
            for _, p in ipairs(d.desks[1] and d.desks or d.spawns) do
                local dist = Util.Distance(pos, p)
                if dist < bestDist then best, bestDist = g, dist end
            end
        end
    end
    return best
end

lib.callback.register('XS-Garages:server:garages', function(src)
    while not Garages.ready do Wait(200) end
    return Garages.ForPlayer(src)
end)
