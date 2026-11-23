Vehicles = {}

local labels, byHash

local function buildLabels()
    labels, byHash = {}, {}
    for _, v in ipairs(Framework.Vehicles() or {}) do
        local model = tostring(v.model or ''):lower()
        labels[model] = v.label
        local h = tonumber(v.hash) or joaat(model)
        byHash[h] = { model = model, label = v.label }
        if h < 0 then byHash[h + 4294967296] = byHash[h] else byHash[h - 4294967296] = byHash[h] end
    end
end

function Vehicles.ModelOf(row)
    local name = tostring(row.vehicle or '')
    local mods = type(row.mods) == 'table' and row.mods or Db.Decode(row.mods, {})
    local hash = tonumber(row.hash) or tonumber(mods and mods.model)
    if name == '' or name:find('[{%[]') then
        if not byHash then buildLabels() end
        local hit = hash and byHash[hash]
        name = hit and hit.model or ''
    end
    if not hash and name ~= '' then hash = joaat(name) end
    return name:lower(), hash
end

function Vehicles.Label(model, hash)
    if not labels then buildLabels() end
    if model and labels[model] then return labels[model] end
    if hash and byHash[hash] then return byHash[hash].label end
    if model and model ~= '' then return model:sub(1, 1):upper() .. model:sub(2) end
    return Text('car_unknown')
end

function Vehicles.Row(plate)
    plate = Util.Plate(plate)
    if plate == '' then return nil end
    return MySQL.single.await('SELECT * FROM player_vehicles WHERE plate = ? OR plate = ? LIMIT 1', { plate, plate:upper() })
end

function Vehicles.OfOwner(cid)
    if not cid then return {} end
    return MySQL.query.await('SELECT * FROM player_vehicles WHERE citizenid = ?', { cid }) or {}
end

function Vehicles.ParkedAt(key)
    return MySQL.query.await('SELECT * FROM player_vehicles WHERE garage = ? AND state = 1', { key }) or {}
end

function Vehicles.CountAt(key)
    local row = MySQL.single.await('SELECT COUNT(*) AS n FROM player_vehicles WHERE garage = ? AND state = 1', { key })
    return tonumber(row and row.n) or 0
end

function Vehicles.SharedWith(group)
    local metas = MySQL.query.await('SELECT plate FROM xs_garages_vehicles WHERE shared = ?', { group }) or {}
    if #metas == 0 then return {} end
    local plates = {}
    for _, m in ipairs(metas) do plates[#plates + 1] = m.plate end
    return MySQL.query.await(('SELECT * FROM player_vehicles WHERE plate IN (%s)'):format(('?,'):rep(#plates):sub(1, -2)), plates) or {}
end

local META_DEFAULT = { nickname = '', favourite = 0, mileage = 0, category = '', shared = '', bay = 0, parked_at = 0 }

function Vehicles.Meta(plate)
    plate = Util.Plate(plate)
    local row = MySQL.single.await('SELECT * FROM xs_garages_vehicles WHERE plate = ?', { plate })
    local out = Util.Copy(META_DEFAULT)
    out.plate = plate
    for k, v in pairs(row or {}) do out[k] = v end
    return out
end

function Vehicles.Metas(rows)
    local map = {}
    if #rows == 0 then return map end
    local plates = {}
    for _, r in ipairs(rows) do plates[#plates + 1] = Util.Plate(r.plate) end
    local found = MySQL.query.await(('SELECT * FROM xs_garages_vehicles WHERE plate IN (%s)'):format(('?,'):rep(#plates):sub(1, -2)), plates) or {}
    for _, m in ipairs(found) do map[Util.Plate(m.plate)] = m end
    return map
end

local META_COLUMNS = { nickname = true, favourite = true, mileage = true, category = true, shared = true, bay = true, parked_at = true }

function Vehicles.SetMeta(plate, fields)
    plate = Util.Plate(plate)
    if plate == '' then return end
    local cols, vals, updates = { 'plate' }, { plate }, {}
    for k, v in pairs(fields) do
        if META_COLUMNS[k] then
            cols[#cols + 1] = k
            vals[#vals + 1] = v
            updates[#updates + 1] = ('`%s` = VALUES(`%s`)'):format(k, k)
        end
    end
    if #updates == 0 then return end
    local sql = ('INSERT INTO xs_garages_vehicles (%s) VALUES (%s) ON DUPLICATE KEY UPDATE %s'):format(
        table.concat(cols, ', '), ('?,'):rep(#cols):sub(1, -2), table.concat(updates, ', '))
    MySQL.query.await(sql, vals)
end

function Vehicles.Update(plate, fields)
    local sets, args = {}, {}
    for k, v in pairs(fields) do
        if Db.columns[k] then
            sets[#sets + 1] = ('`%s` = ?'):format(k)
            args[#args + 1] = v
        end
    end
    if #sets == 0 then return 0 end
    plate = Util.Plate(plate)
    args[#args + 1] = plate
    args[#args + 1] = plate:upper()
    return MySQL.update.await(('UPDATE player_vehicles SET %s WHERE plate = ? OR plate = ?'):format(table.concat(sets, ', ')), args) or 0
end

function Vehicles.Status(row)
    local state = tonumber(row.state) or 0
    local depot = tonumber(row.depotprice) or 0
    if depot > 0 then return 'impound' end
    if state == 1 then return 'parked' end
    if state == 2 or state == 3 then return 'held' end
    if Spawn.Find(row.plate) then return 'out' end
    return 'lost'
end

function Vehicles.Hold(plate)
    return MySQL.single.await('SELECT * FROM xs_garages_impound WHERE plate = ? AND done = 0 ORDER BY id DESC LIMIT 1', { Util.Plate(plate) })
end

local function groupLabel(shared)
    local kind, name = tostring(shared or ''):match('^(%a+):(.+)$')
    if not kind then return nil end
    local list = kind == 'job' and Framework.Jobs() or Framework.Gangs()
    for _, j in ipairs(list) do
        if j.name == name then return j.label end
    end
    return name
end

local function decide(g, card, row)
    local d = g.data
    local status = card.status
    local L = Config.Lost or {}
    if d.type == 'impound' then
        if not Util.Fits(d.category, card.category ~= '' and card.category or nil) then return 'none', 0, 'wrong_type' end
        if status == 'impound' then return 'release', tonumber(row.depotprice) or 0 end
        if status == 'lost' and d.impound.lost ~= false then return 'recover', L.fee or 0 end
        if status == 'held' then return 'none', 0, 'held' end
        if status == 'out' then return 'track', 0 end
        return 'none', 0, 'parked'
    end
    if status == 'out' then return card.mine and 'track' or 'none', 0, card.mine and nil or 'in_use' end
    if status == 'held' then return 'none', 0, 'held' end
    if status == 'impound' then return 'none', 0, 'impound' end
    if status == 'lost' then
        if L.atGarage and card.mine then return 'recover', L.garageFee or 0 end
        return 'none', 0, 'lost'
    end
    if card.here then return 'take', Garages.Fee(g, 'takeOut') end
    if not card.mine then return 'none', 0, 'elsewhere' end
    local origin = Garages.Get(row.garage)
    if not origin then return 'take', Garages.Fee(g, 'takeOut') end
    if (Config.Parking or {}).anywhere and d.type == 'public' and origin.data.type == 'public' then return 'take', Garages.Fee(g, 'takeOut') end
    return 'take', Garages.Fee(g, 'move') + Garages.Fee(g, 'takeOut'), nil, true
end

function Vehicles.Card(row, meta, g, cid)
    meta = meta or META_DEFAULT
    local model, hash = Vehicles.ModelOf(row)
    local mods = Db.Decode(row.mods, {})
    local origin = Garages.Get(row.garage)
    local card = {
        plate = Util.Plate(row.plate), model = model, hash = hash, label = Vehicles.Label(model, hash), nickname = meta.nickname or '',
        favourite = Util.Truthy(meta.favourite), status = Vehicles.Status(row), garage = row.garage or '',
        garageLabel = origin and origin.data.label or (row.garage and row.garage ~= '' and row.garage or ''),
        here = g ~= nil and row.garage == g.data.key and tonumber(row.state) == 1,
        fuel = math.floor(tonumber(row.fuel) or tonumber(mods.fuelLevel) or 100), engine = math.floor(tonumber(row.engine) or tonumber(mods.engineHealth) or 1000),
        body = math.floor(tonumber(row.body) or tonumber(mods.bodyHealth) or 1000), mileage = Util.Round(tonumber(meta.mileage) or 0, 1),
        parkedAt = tonumber(meta.parked_at) or 0, mine = row.citizenid == cid, shared = tostring(meta.shared or ''), category = meta.category or '',
        colour = tonumber(mods.color1) or (type(mods.color1) == 'table' and -2) or -1,
    }
    if card.shared ~= '' then card.sharedLabel = groupLabel(card.shared) end
    if not card.mine then card.owner = Vehicles.OwnerName(row.citizenid) end
    if g then
        local action, fee, why, moving = decide(g, card, row)
        card.action, card.fee, card.why, card.moving = action, math.floor(fee or 0), why, moving == true
        if card.mine and card.status == 'parked' and not card.here and g.data.type ~= 'impound' then card.canMove = true card.moveFee = Garages.Fee(g, 'move') end
    end
    if card.status == 'held' or card.status == 'impound' then
        local hold = Vehicles.Hold(card.plate)
        if hold then
            card.hold = { untilAt = tonumber(hold.release_at) or 0, reason = hold.reason, officer = hold.officer, fee = tonumber(hold.fee) or 0, at = tonumber(hold.at) or 0 }
        end
        if card.status == 'impound' then card.depot = tonumber(row.depotprice) or 0 end
    end
    return card
end

local names = {}

function Vehicles.OwnerName(cid)
    if not cid then return '' end
    if names[cid] then return names[cid] end
    local player = Framework.GetPlayerByCitizenId(cid)
    local name
    if player then
        name = Framework.FullName(player.PlayerData.charinfo)
    else
        local row = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ?', { cid })
        name = row and Framework.FullName(Db.Decode(row.charinfo, {})) or ''
    end
    names[cid] = name
    return name
end

local CHARS = 'ABCDEFGHJKLMNPRSTUVWXYZ'

function Vehicles.NewPlate(prefix)
    prefix = Util.Text(prefix or '', 4):upper():gsub('[^%w]', '')
    for _ = 1, 50 do
        local plate = prefix
        while #plate < 8 do
            if #plate % 2 == 0 and #plate < 4 then
                local i = math.random(1, #CHARS)
                plate = plate .. CHARS:sub(i, i)
            else
                plate = plate .. tostring(math.random(0, 9))
            end
        end
        if not Vehicles.Row(plate) and not Spawn.Find(plate) then return plate end
    end
    return nil
end

function Vehicles.Create(src, model, props, garageKey, extra)
    local cid = Framework.GetCitizenId(src)
    if not cid then return nil end
    props = props or {}
    props.plate = props.plate or Vehicles.NewPlate()
    props.model = props.model or joaat(model)
    if GetResourceState('qbx_vehicles') == 'started' then
        local ok, id = pcall(function()
            return exports.qbx_vehicles:CreatePlayerVehicle({ model = model, citizenid = cid, props = props, garage = garageKey })
        end)
        if ok and id then
            Vehicles.Update(props.plate, { state = 1, garage = garageKey, depotprice = 0 })
            return props.plate
        end
    end
    local cols = { 'citizenid', 'vehicle', 'hash', 'mods', 'plate', 'garage', 'fuel', 'engine', 'body', 'state', 'depotprice' }
    local vals = { cid, model, tostring(joaat(model)), Db.Json(props), props.plate, garageKey, 100, 1000, 1000, 1, 0 }
    if Db.columns.license then
        cols[#cols + 1] = 'license'
        vals[#vals + 1] = Framework.License(src)
    end
    local ok = pcall(MySQL.insert.await, ('INSERT INTO player_vehicles (%s) VALUES (%s)'):format(table.concat(cols, ', '), ('?,'):rep(#cols):sub(1, -2)), vals)
    if not ok then return nil end
    if extra then Vehicles.SetMeta(props.plate, extra) end
    return props.plate
end
