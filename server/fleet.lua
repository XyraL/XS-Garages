Fleet = { out = {} }

local function key(plate)
    return Util.Plate(plate):upper()
end

local function myGrade(src, g)
    if g.data.type == 'job' then
        local job = Framework.GetJob(src)
        return job and job.grade or 0, job and job.isBoss
    end
    local gang = Framework.GetGang(src)
    return gang and gang.grade or 0, gang and gang.isBoss
end

local function countFor(cid)
    local n = 0
    for _, info in pairs(Fleet.out) do
        if info.cid == cid then n = n + 1 end
    end
    return n
end

local function countEntry(garageKey, idx)
    local n = 0
    for _, info in pairs(Fleet.out) do
        if info.garage == garageKey and info.entry == idx then n = n + 1 end
    end
    return n
end

function Fleet.Of(plate)
    local info = Fleet.out[key(plate)]
    if info and info.entity and DoesEntityExist(info.entity) then return info end
    if info then Fleet.out[key(plate)] = nil end
    return nil
end

function Fleet.List(src, g)
    local grade, boss = myGrade(src, g)
    local cid = Framework.GetCitizenId(src)
    local out = {}
    for i, e in ipairs(g.data.fleet) do
        local mine = 0
        for _, info in pairs(Fleet.out) do
            if info.garage == g.data.key and info.entry == i and info.cid == cid then mine = mine + 1 end
        end
        out[#out + 1] = {
            index = i, model = e.model, hash = joaat(e.model), label = e.label ~= '' and e.label or Vehicles.Label(e.model), grade = e.grade,
            locked = grade < e.grade and not boss, mode = e.mode, price = e.price, out = countEntry(g.data.key, i), limit = e.limit, mine = mine,
            livery = e.livery, tuned = e.tuned,
        }
    end
    return out
end

local function propsFor(e, plate)
    local props = { plate = plate, model = joaat(e.model), fuelLevel = 100.0, dirtLevel = 0.0 }
    if e.color1 >= 0 then props.color1 = e.color1 end
    if e.color2 >= 0 then props.color2 = e.color2 end
    if e.livery >= 0 then
        props.livery = e.livery
        props.modLivery = e.livery
    end
    if #e.extras > 0 then
        props.extras = {}
        for x = 0, 20 do props.extras[tostring(x)] = 1 end
        for _, x in ipairs(e.extras) do props.extras[tostring(x)] = 0 end
    end
    if e.tuned then
        props.modEngine, props.modBrakes, props.modTransmission, props.modSuspension, props.modArmor, props.modTurbo = 3, 2, 2, 3, 4, true
    end
    return props
end

local function entryFor(src, g, idx)
    local e = g.data.fleet[tonumber(idx) or 0]
    if not e then return nil, Text('err_no_fleet') end
    local grade, boss = myGrade(src, g)
    if grade < e.grade and not boss then return nil, Text('err_low_grade') end
    return e
end

local signing = {}
local signOut

lib.callback.register('XS-Garages:server:fleetTake', function(src, garageKey, idx)
    local g = Garages.Get(garageKey)
    if not g or (g.data.type ~= 'job' and g.data.type ~= 'gang') then return false, Text('err_no_garage') end
    local ok, why = Garages.Access(src, g)
    if not ok then return false, why end
    if not Garages.Near(src, g, { 'desks', 'spawns', 'drops' }) then return false, Text('err_too_far') end
    local e, bad = entryFor(src, g, idx)
    if not e then return false, bad end
    if e.mode ~= 'borrow' then return false, Text('err_failed') end
    local cid = Framework.GetCitizenId(src)
    if not cid or signing[cid] then return false, Text('err_busy') end
    signing[cid] = true
    local res = { pcall(signOut, src, g, e, idx, cid) }
    signing[cid] = nil
    if not res[1] then
        print(('^1[XS-Garages]^0 motor pool sign-out failed: %s'):format(tostring(res[2])))
        return false, Text('err_failed')
    end
    return res[2], res[3]
end)

function signOut(src, g, e, idx, cid)
    if countFor(cid) >= ((Config.Fleet or {}).perPlayer or 1) then return false, Text('err_fleet_limit') end
    if e.limit > 0 and countEntry(g.data.key, tonumber(idx)) >= e.limit then return false, Text('err_fleet_none_left') end
    local spot = Spawn.FreePoint(g.data.spawns)
    if not spot then return false, Text('err_blocked') end
    local plate = Vehicles.NewPlate(e.plate ~= '' and e.plate or nil)
    if not plate then return false, Text('err_failed') end
    local props = propsFor(e, plate)
    local fuel = (Config.Fleet or {}).fullFuel ~= false and 100 or 60
    local veh, netId = Spawn.Create(src, e.model, g.data.spawns[spot], props, { fuel = fuel })
    if not veh then return false, Text('err_spawn') end
    local info = { fleet = true, cid = cid, src = src, garage = g.data.key, entry = tonumber(idx) }
    Spawn.Track(plate, veh, info)
    Fleet.out[key(plate)] = info
    Entity(veh).state:set('xsgFleet', { garage = g.data.key, entry = tonumber(idx), cid = cid }, true)
    Keys.Give(src, veh, plate)
    Logs.Add('fleet', g.data.key, plate, Logs.Who(src), Text('log_fleet_out', { car = e.label ~= '' and e.label or e.model }))
    return true, { netId = netId, plate = plate, fuel = fuel, props = props, warp = (Config.General or {}).warpIn ~= false, fade = (Config.General or {}).fade ~= false }
end

lib.callback.register('XS-Garages:server:fleetBuy', function(src, garageKey, idx)
    local g = Garages.Get(garageKey)
    if not g or (g.data.type ~= 'job' and g.data.type ~= 'gang') then return false, Text('err_no_garage') end
    local ok, why = Garages.Access(src, g)
    if not ok then return false, why end
    if not Garages.Near(src, g, { 'desks', 'spawns', 'drops' }) then return false, Text('err_too_far') end
    local e, bad = entryFor(src, g, idx)
    if not e then return false, bad end
    if e.mode ~= 'buy' then return false, Text('err_failed') end
    local price = e.price or 0
    if price > 0 and not Framework.Charge(src, price, 'bank', 'xs-garages-fleet') then return false, Text('err_money', { fee = Util.Money(price) }) end
    local plate = Vehicles.NewPlate(e.plate ~= '' and e.plate or nil)
    local props = propsFor(e, plate)
    local made = Vehicles.Create(src, e.model, props, g.data.key, { shared = Garages.GroupKey(g) or '', parked_at = os.time() })
    if not made then
        if price > 0 then Framework.AddMoney(src, 'bank', price, 'xs-garages-refund') end
        return false, Text('err_failed')
    end
    Vehicles.SetMeta(made, { shared = Garages.GroupKey(g) or '', parked_at = os.time() })
    Logs.Add('fleet', g.data.key, made, Logs.Who(src), Text('log_fleet_bought', { car = e.label ~= '' and e.label or e.model }), price)
    return true, Cabinet.Data(src, g)
end)

function Fleet.Return(src, g, veh, info)
    local group = Garages.GroupKey(g)
    local home = Garages.Get(info.garage)
    if not home or Garages.GroupKey(home) ~= group then return false, Text('err_fleet_wrong_garage') end
    local plate = Util.Plate(GetVehicleNumberPlateText(veh))
    Fleet.out[key(plate)] = nil
    Spawn.Remove(veh)
    Logs.Add('fleet', g.data.key, plate, Logs.Who(src), Text('log_fleet_back'))
    return true, { fleet = true }
end

function Fleet.Gone(info)
    if info and info.plate then Fleet.out[key(info.plate)] = nil end
end

function Fleet.Adopt(plate, veh, fleet)
    Fleet.out[key(plate)] = { fleet = true, cid = fleet.cid, garage = fleet.garage, entry = fleet.entry, entity = veh, plate = Util.Plate(plate) }
end

local function returnAll(cid)
    if not cid or (Config.Fleet or {}).returnOnLogout == false then return end
    for k, info in pairs(Fleet.out) do
        if info.cid == cid and info.entity and DoesEntityExist(info.entity) then
            local empty = true
            for seat = -1, 8 do
                local ped = GetPedInVehicleSeat(info.entity, seat)
                if ped and ped ~= 0 and IsPedAPlayer(ped) then empty = false break end
            end
            if empty then
                Fleet.out[k] = nil
                Spawn.Remove(info.entity)
            end
        end
    end
end

Fleet.cids = {}

Framework.OnLoaded(function(src)
    Fleet.cids[src] = Framework.GetCitizenId(src)
end)

Framework.OnUnloaded(function(src)
    local cid = Fleet.cids[src] or Framework.GetCitizenId(src)
    Fleet.cids[src] = nil
    returnAll(cid)
end)
