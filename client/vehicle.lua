Cars = { miles = {} }
Park = { busy = false }

local SUBS = { [joaat('submersible')] = true, [joaat('submersible2')] = true, [joaat('kosatka')] = true, [joaat('avisa')] = true }

lib.callback.register('XS-Garages:client:vehicleType', function(hash)
    hash = tonumber(hash) or 0
    if not IsModelInCdimage(hash) then return 'automobile' end
    if SUBS[hash] then return 'submarine' end
    if IsThisModelATrain(hash) then return 'train' end
    if IsThisModelAHeli(hash) then return 'heli' end
    if IsThisModelAPlane(hash) then return 'plane' end
    if IsThisModelABoat(hash) or IsThisModelAJetski(hash) then return 'boat' end
    if IsThisModelABike(hash) or IsThisModelABicycle(hash) then return 'bike' end
    if GetVehicleClassFromName(hash) == 14 then return 'boat' end
    return 'automobile'
end)

function Cars.Apply(veh, init)
    if not veh or not DoesEntityExist(veh) or type(init) ~= 'table' then return end
    if type(init.props) == 'table' then pcall(lib.setVehicleProperties, veh, init.props) end
    if init.fuel then Fuel.Set(veh, init.fuel) end
    SetVehicleNeedsToBeHotwired(veh, false)
    SetVehRadioStation(veh, 'OFF')
    if init.engineOff then SetVehicleEngineOn(veh, false, true, true) end
    if init.lock then SetVehicleDoorsLocked(veh, 2) end
    local class = GetVehicleClass(veh)
    if class ~= 14 and class ~= 15 and class ~= 16 then SetVehicleOnGroundProperly(veh) end
end

AddStateBagChangeHandler('xsgInit', nil, function(bagName, _, value)
    if type(value) ~= 'table' then return end
    CreateThread(function()
        local veh = GetEntityFromStateBagName(bagName)
        local untilAt = GetGameTimer() + 4000
        while (veh == 0 or not DoesEntityExist(veh)) and GetGameTimer() < untilAt do
            Wait(50)
            veh = GetEntityFromStateBagName(bagName)
        end
        if veh == 0 or not DoesEntityExist(veh) then return end
        if NetworkGetEntityOwner(veh) ~= PlayerId() then return end
        Cars.Apply(veh, value)
        Entity(veh).state:set('xsgInit', nil, true)
    end)
end)

local function entityOf(netId, ms)
    local untilAt = GetGameTimer() + (ms or 6000)
    while GetGameTimer() < untilAt do
        if NetworkDoesNetworkIdExist(netId) then
            local veh = NetworkGetEntityFromNetworkId(netId)
            if veh ~= 0 and DoesEntityExist(veh) then return veh end
        end
        Wait(25)
    end
    return nil
end

function Cars.Land(res)
    local veh = entityOf(res.netId)
    if not veh then
        Util.Fade(false, 300)
        return Util.Notify(Text('err_spawn'), 'error')
    end
    local untilAt = GetGameTimer() + 2500
    while not NetworkHasControlOfEntity(veh) and GetGameTimer() < untilAt do
        NetworkRequestControlOfEntity(veh)
        Wait(10)
    end
    if NetworkHasControlOfEntity(veh) then
        Cars.Apply(veh, { props = res.props, fuel = res.fuel, engineOff = (Config.General or {}).engineOff ~= false, lock = (Config.General or {}).lockOnSpawn })
    end
    if res.warp then
        local ped = PlayerPedId()
        TaskWarpPedIntoVehicle(ped, veh, -1)
        local wait = GetGameTimer() + 1500
        while not IsPedInVehicle(ped, veh, false) and GetGameTimer() < wait do Wait(10) end
        if (Config.General or {}).engineOff ~= false then SetVehicleEngineOn(veh, false, true, true) end
    end
    Cars.miles[Util.Plate(res.plate):upper()] = 0.0
    Util.Fade(false, 300)
    return veh
end

function Cars.TakeMiles(veh)
    local k = Util.Plate(GetVehicleNumberPlateText(veh)):upper()
    local m = Cars.miles[k] or 0.0
    Cars.miles[k] = 0.0
    return m, k
end

CreateThread(function()
    local last, lastVeh
    while true do
        Wait(1000)
        if (Config.Mileage or {}).enabled ~= false then
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
                local pos = GetEntityCoords(veh)
                if lastVeh == veh and last then
                    local d = #(pos - last)
                    if d > 0.5 and d < 150.0 then
                        local k = Util.Plate(GetVehicleNumberPlateText(veh)):upper()
                        Cars.miles[k] = (Cars.miles[k] or 0.0) + d
                    end
                end
                last, lastVeh = pos, veh
            else
                last, lastVeh = nil, nil
            end
        end
    end
end)

function Park.Do(key, veh)
    if Park.busy then return end
    Park.busy = true
    local ok, err = pcall(function()
        local ped = PlayerPedId()
        if (Config.Parking or {}).passengersOut ~= false then
            for seat = 0, math.max(0, GetVehicleMaxNumberOfPassengers(veh) - 1) do
                local p = GetPedInVehicleSeat(veh, seat)
                if p ~= 0 and IsPedAPlayer(p) then return Util.Notify(Text('err_passengers'), 'error') end
            end
        end
        local min = (Config.Parking or {}).minEngine or 0
        if min > 0 and GetVehicleEngineHealth(veh) < min then return Util.Notify(Text('err_wrecked'), 'error') end
        local props = lib.getVehicleProperties(veh) or {}
        local fuel = Fuel.Get(veh)
        props.fuelLevel = fuel
        local miles, k = Cars.TakeMiles(veh)
        local data = {
            props = props, fuel = fuel, engine = GetVehicleEngineHealth(veh), body = GetVehicleBodyHealth(veh), class = GetVehicleClass(veh), mileage = miles,
        }
        SetVehicleEngineOn(veh, false, false, true)
        TaskLeaveVehicle(ped, veh, 0)
        local untilAt = GetGameTimer() + 3500
        while IsPedInVehicle(ped, veh, false) and GetGameTimer() < untilAt do Wait(50) end
        local good, res = Garages.Call('park', key, NetworkGetNetworkIdFromEntity(veh), data)
        if not good then
            Cars.miles[k] = (Cars.miles[k] or 0.0) + miles
            return Util.Notify(res or Text('err_failed'), 'error')
        end
        if type(res) == 'table' and res.fleet then
            Util.Notify(Text('fleet_returned'), 'success')
        elseif type(res) == 'table' and (res.fee or 0) > 0 then
            Util.Notify(Text('parked_fee', { fee = Util.Money(res.fee) }), 'success')
        else
            Util.Notify(Text('parked'), 'success')
        end
    end)
    if not ok then print(('^1[XS-Garages]^0 parking failed: %s'):format(tostring(err))) end
    Park.busy = false
end

local trackBlips = {}

function Cars.Mark(list)
    for _, b in ipairs(trackBlips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    trackBlips = {}
    for i, c in ipairs(list) do
        local b = AddBlipForCoord(c.x + 0.0, c.y + 0.0, c.z + 0.0)
        SetBlipSprite(b, 225)
        SetBlipColour(b, 46)
        SetBlipScale(b, 0.85)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(c.label and ('%s · %s'):format(c.label, c.plate or '') or (c.plate or Text('your_car')))
        EndTextCommandSetBlipName(b)
        trackBlips[#trackBlips + 1] = b
        if i == 1 then SetNewWaypoint(c.x + 0.0, c.y + 0.0) end
    end
    SetTimeout(120000, function()
        for _, b in ipairs(trackBlips) do if DoesBlipExist(b) then RemoveBlip(b) end end
        trackBlips = {}
    end)
end

CreateThread(function()
    while not Framework.name do Wait(200) end
    RegisterCommand(Config.Commands.findCar or 'findcar', function()
        local ok, list = Garages.Call('findCars')
        if not ok then return Util.Notify(list or Text('err_failed'), 'error') end
        if #list == 0 then return Util.Notify(Text('find_none'), 'inform') end
        Cars.Mark(list)
        Util.Notify(Text('find_marked', { n = #list }), 'success')
    end, false)
end)
