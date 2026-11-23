Fuel = { name = 'none' }

if IsDuplicityVersion() or not Config then return end

local ORDER = {
    'cdn-fuel', 'ps-fuel', 'lc_fuel', 'lj-fuel', 'qb-fuel', 'Renewed-Fuel', 'okokGasStation',
    'ti_fuel', 'BigDaddy-Fuel', 'x-fuel', 'rcore_fuel', 'qs-fuelstations', 'ND_Fuel',
    'melons_fuel', 'LegacyFuel', 'ox_fuel',
}

local function detect()
    local forced = Config.Bridges and Config.Bridges.fuel or 'auto'
    if forced and forced ~= 'auto' then return forced end
    for _, name in ipairs(ORDER) do
        if GetResourceState(name) == 'started' then return name end
    end
    return 'none'
end

Fuel.name = detect()

local SET = {
    ['cdn-fuel'] = function(v, l) exports['cdn-fuel']:SetFuel(v, l) end,
    ['ps-fuel'] = function(v, l) exports['ps-fuel']:SetFuel(v, l) end,
    ['lc_fuel'] = function(v, l) exports['lc_fuel']:SetFuel(v, l) end,
    ['lj-fuel'] = function(v, l) exports['lj-fuel']:SetFuel(v, l) end,
    ['qb-fuel'] = function(v, l) exports['qb-fuel']:SetFuel(v, l) end,
    ['Renewed-Fuel'] = function(v, l) exports['Renewed-Fuel']:SetFuel(v, l) end,
    ['okokGasStation'] = function(v, l) exports['okokGasStation']:SetFuel(v, l) end,
    ['ti_fuel'] = function(v, l) exports['ti_fuel']:setFuel(v, l) end,
    ['BigDaddy-Fuel'] = function(v, l) exports['BigDaddy-Fuel']:SetFuel(v, l) end,
    ['x-fuel'] = function(v, l) exports['x-fuel']:SetFuel(v, l) end,
    ['rcore_fuel'] = function(v, l) exports['rcore_fuel']:SetVehicleFuel(v, l) end,
    ['qs-fuelstations'] = function(v, l) exports['qs-fuelstations']:SetFuel(v, l) end,
    ['ND_Fuel'] = function(v, l) DecorSetFloat(v, '_ANDY_FUEL_DECORE_', l) end,
    ['LegacyFuel'] = function(v, l) exports['LegacyFuel']:SetFuel(v, l) end,
}

local GET = {
    ['cdn-fuel'] = function(v) return exports['cdn-fuel']:GetFuel(v) end,
    ['ps-fuel'] = function(v) return exports['ps-fuel']:GetFuel(v) end,
    ['lc_fuel'] = function(v) return exports['lc_fuel']:GetFuel(v) end,
    ['lj-fuel'] = function(v) return exports['lj-fuel']:GetFuel(v) end,
    ['qb-fuel'] = function(v) return exports['qb-fuel']:GetFuel(v) end,
    ['Renewed-Fuel'] = function(v) return exports['Renewed-Fuel']:GetFuel(v) end,
    ['okokGasStation'] = function(v) return exports['okokGasStation']:GetFuel(v) end,
    ['ti_fuel'] = function(v) return exports['ti_fuel']:getFuel(v) end,
    ['BigDaddy-Fuel'] = function(v) return exports['BigDaddy-Fuel']:GetFuel(v) end,
    ['x-fuel'] = function(v) return exports['x-fuel']:GetFuel(v) end,
    ['rcore_fuel'] = function(v) return exports['rcore_fuel']:GetVehicleFuelPercentage(v) end,
    ['qs-fuelstations'] = function(v) return exports['qs-fuelstations']:GetFuel(v) end,
    ['ND_Fuel'] = function(v) return DecorGetFloat(v, '_ANDY_FUEL_DECORE_') end,
    ['LegacyFuel'] = function(v) return exports['LegacyFuel']:GetFuel(v) end,
}

function Fuel.Set(vehicle, level)
    if not vehicle or not DoesEntityExist(vehicle) then return end
    level = Util.Clamp(tonumber(level) or 100.0, 0.0, 100.0) + 0.0
    SetVehicleFuelLevel(vehicle, level)
    if DecorIsRegisteredAsType('_FUEL_LEVEL', 1) then DecorSetFloat(vehicle, '_FUEL_LEVEL', level) end
    if NetworkGetEntityIsNetworked(vehicle) then
        pcall(function() Entity(vehicle).state:set('fuel', level, true) end)
    end
    local call = SET[Fuel.name]
    if call then
        local ok, err = pcall(call, vehicle, level)
        if not ok and Config.Debug then print(('^3[XS-Garages]^0 %s fuel set failed: %s'):format(Fuel.name, tostring(err))) end
    end
end

function Fuel.Get(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return 100.0 end
    local call = GET[Fuel.name]
    if call then
        local ok, value = pcall(call, vehicle)
        if ok and tonumber(value) then return Util.Clamp(tonumber(value), 0.0, 100.0) end
    end
    local state = NetworkGetEntityIsNetworked(vehicle) and Entity(vehicle).state.fuel or nil
    if tonumber(state) then return Util.Clamp(tonumber(state), 0.0, 100.0) end
    return Util.Clamp(GetVehicleFuelLevel(vehicle), 0.0, 100.0)
end
