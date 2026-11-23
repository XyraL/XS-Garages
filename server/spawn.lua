Spawn = { out = {}, byEntity = {}, storing = {}, types = {} }
Lost = {}

local VALID = { automobile = true, bike = true, boat = true, heli = true, plane = true, submarine = true, trailer = true, train = true }

local function key(plate)
    return Util.Plate(plate):upper()
end

local cache, cacheAt = nil, 0

local function world()
    if cache and GetGameTimer() - cacheAt < 1000 then return cache end
    cache = {}
    for _, veh in ipairs(GetAllVehicles() or {}) do
        if DoesEntityExist(veh) then cache[key(GetVehicleNumberPlateText(veh))] = veh end
    end
    cacheAt = GetGameTimer()
    return cache
end

function Spawn.Invalidate()
    cache = nil
end

function Spawn.Find(plate)
    local k = key(plate)
    if k == '' then return nil end
    local e = Spawn.out[k]
    if e and e.entity and DoesEntityExist(e.entity) then return e.entity, e end
    if e then
        Spawn.out[k] = nil
        if e.entity then Spawn.byEntity[e.entity] = nil end
    end
    local veh = world()[k]
    if veh and DoesEntityExist(veh) then return veh end
    return nil
end

function Spawn.TypeOf(src, hash)
    local mine = Spawn.types[src]
    if mine and mine[hash] then return mine[hash] end
    local ok, t = pcall(lib.callback.await, 'XS-Garages:client:vehicleType', src, hash)
    if ok and VALID[t] then
        Spawn.types[src] = mine or {}
        Spawn.types[src][hash] = t
        return t
    end
    return 'automobile'
end

AddEventHandler('playerDropped', function()
    Spawn.types[source] = nil
end)

function Spawn.Free(p, radius)
    local at = vector3(p.x + 0.0, p.y + 0.0, p.z + 0.0)
    for _, veh in ipairs(GetAllVehicles() or {}) do
        if DoesEntityExist(veh) and #(GetEntityCoords(veh) - at) < radius then return false end
    end
    return true
end

function Spawn.FreePoint(list, prefer, taken)
    taken = taken or {}
    local radius = (Config.Parking or {}).clearRadius or 3.0
    if prefer and list[prefer] and not taken[prefer] and Spawn.Free(list[prefer], radius) then return prefer end
    for i, p in ipairs(list or {}) do
        if not taken[i] and Spawn.Free(p, radius) then return i end
    end
    return nil
end

function Spawn.Create(src, model, at, props, opts)
    opts = opts or {}
    local hash = type(model) == 'number' and model or joaat(model)
    local vtype = Spawn.TypeOf(src, hash)
    local ok, veh = pcall(CreateVehicleServerSetter, hash, vtype, at.x + 0.0, at.y + 0.0, at.z + 0.0, (at.w or 0.0) + 0.0)
    if not ok then return nil end
    local untilAt = GetGameTimer() + 6000
    while (not veh or veh == 0 or not DoesEntityExist(veh)) and GetGameTimer() < untilAt do Wait(10) end
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    untilAt = GetGameTimer() + 3000
    while NetworkGetEntityOwner(veh) == -1 and GetGameTimer() < untilAt do Wait(10) end
    pcall(SetEntityOrphanMode, veh, 2)
    if props and props.plate then SetVehicleNumberPlateText(veh, props.plate) end
    local plate = Util.Plate(props and props.plate or GetVehicleNumberPlateText(veh))
    Entity(veh).state:set('xsgPlate', plate, true)
    Entity(veh).state:set('xsgInit', {
        props = props or {}, fuel = opts.fuel, engineOff = (Config.General or {}).engineOff ~= false, lock = opts.lock == true,
    }, true)
    Spawn.Invalidate()
    return veh, NetworkGetNetworkIdFromEntity(veh)
end

function Spawn.Track(plate, veh, info)
    local k = key(plate)
    info = info or {}
    info.entity, info.plate, info.at = veh, Util.Plate(plate), os.time()
    Spawn.out[k] = info
    Spawn.byEntity[veh] = k
    Spawn.Invalidate()
end

function Spawn.Remove(veh)
    if not veh then return end
    Spawn.storing[veh] = true
    local k = Spawn.byEntity[veh]
    if k then Spawn.out[k] = nil end
    Spawn.byEntity[veh] = nil
    if DoesEntityExist(veh) then DeleteEntity(veh) end
    SetTimeout(8000, function() Spawn.storing[veh] = nil end)
    Spawn.Invalidate()
end

function Lost.Removed(info)
    if not info or not info.plate then return end
    local mode = (Config.Lost or {}).whenRemoved or 'impound'
    local plate = info.plate
    if mode == 'impound' then
        local fee = math.floor((Config.Lost or {}).fee or 0)
        local n = MySQL.update.await('UPDATE player_vehicles SET depotprice = ? WHERE (plate = ? OR plate = ?) AND state = 0 AND depotprice = 0', { math.max(1, fee), plate, plate:upper() })
        if (n or 0) > 0 then Logs.Add('lost', info.garage or '', plate, { citizenid = info.cid or '', name = '' }, Text('log_lost_impound')) end
    elseif mode == 'garage' then
        local n = MySQL.update.await('UPDATE player_vehicles SET state = 1 WHERE (plate = ? OR plate = ?) AND state = 0 AND depotprice = 0', { plate, plate:upper() })
        if (n or 0) > 0 then Logs.Add('lost', info.garage or '', plate, { citizenid = info.cid or '', name = '' }, Text('log_lost_garage')) end
    end
end

AddEventHandler('entityRemoved', function(entity)
    local k = Spawn.byEntity[entity]
    if not k then return end
    Spawn.byEntity[entity] = nil
    local info = Spawn.out[k]
    if info and info.entity == entity then Spawn.out[k] = nil end
    Spawn.Invalidate()
    if Spawn.storing[entity] then return end
    if info and info.fleet then
        if Fleet and Fleet.Gone then Fleet.Gone(info) end
        return
    end
    CreateThread(function() Lost.Removed(info) end)
end)

function Lost.Startup()
    local fresh = GetGameTimer() < 10 * 60 * 1000
    local still = {}
    for _, veh in ipairs(GetAllVehicles() or {}) do
        if DoesEntityExist(veh) then
            local state = Entity(veh).state
            local plate = state and state.xsgPlate
            if plate then
                still[#still + 1] = Util.Plate(plate)
                still[#still + 1] = Util.Plate(plate):upper()
                local fleet = state.xsgFleet
                Spawn.Track(plate, veh, { fleet = fleet ~= nil, garage = fleet and fleet.garage or nil, cid = fleet and fleet.cid or nil, entry = fleet and fleet.entry or nil })
                if fleet and Fleet and Fleet.Adopt then Fleet.Adopt(plate, veh, fleet) end
            end
        end
    end
    if not fresh then return end
    local mode = (Config.Lost or {}).onRestart or 'garage'
    local skip, args = '', {}
    if #still > 0 then
        skip = (' AND plate NOT IN (%s)'):format(('?,'):rep(#still):sub(1, -2))
        args = still
    end
    if mode == 'garage' then
        local n = MySQL.update.await('UPDATE player_vehicles SET state = 1 WHERE state = 0 AND depotprice = 0' .. skip, args) or 0
        if n > 0 then print(('^2[XS-Garages]^0 %d cars left out were put back in their garages.'):format(n)) end
    elseif mode == 'impound' then
        local fee = math.max(1, math.floor((Config.Lost or {}).fee or 0))
        local q = { fee }
        for _, p in ipairs(args) do q[#q + 1] = p end
        local n = MySQL.update.await('UPDATE player_vehicles SET depotprice = ? WHERE state = 0 AND depotprice = 0' .. skip, q) or 0
        if n > 0 then print(('^2[XS-Garages]^0 %d cars left out were sent to the impound lot.'):format(n)) end
    end
end
