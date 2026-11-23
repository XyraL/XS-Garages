Display = { spawned = {}, loaded = {}, syncing = {} }

local function enabled()
    return (Config.Display or {}).enabled ~= false
end

local function despawn(key, bay)
    local list = Display.spawned[key]
    local e = list and list[bay]
    if not e then return end
    Target.RemoveEntity(('disp_%s_%d'):format(key, bay))
    if DoesEntityExist(e.entity) then DeleteEntity(e.entity) end
    list[bay] = nil
end

local function unload(key)
    for bay in pairs(Display.spawned[key] or {}) do despawn(key, bay) end
    Display.spawned[key] = nil
    Display.loaded[key] = nil
end

function Display.Clear()
    for key in pairs(Display.spawned) do unload(key) end
    Display.loaded = {}
end

function Display.Take(key, plate)
    local ok, res = Garages.Call('takeOut', key, plate)
    if not ok then return Util.Notify(res or Text('err_failed'), 'error') end
    Util.Fade(true, 250)
    Cars.Land(res)
    if (res.fee or 0) > 0 then Util.Notify(Text('took_out_fee', { fee = Util.Money(res.fee) }), 'success') end
end

local function spawnCar(g, e)
    local p = g.spawns[e.bay]
    if not p or not e.hash then return nil end
    if not Util.LoadModel(e.hash, 5000) then return nil end
    local veh = CreateVehicle(e.hash, p.x + 0.0, p.y + 0.0, p.z + 0.0, (p.w or 0.0) + 0.0, false, false)
    if veh == 0 then return nil end
    SetEntityAsMissionEntity(veh, true, true)
    local class = GetVehicleClass(veh)
    if class ~= 14 and class ~= 15 and class ~= 16 then SetVehicleOnGroundProperly(veh) end
    if type(e.props) == 'table' then pcall(lib.setVehicleProperties, veh, e.props) end
    SetVehicleNumberPlateText(veh, e.plate)
    SetVehicleEngineOn(veh, false, true, true)
    FreezeEntityPosition(veh, true)
    SetEntityInvincible(veh, true)
    SetEntityCanBeDamaged(veh, false)
    SetVehicleDoorsLocked(veh, 2)
    SetVehicleUndriveable(veh, true)
    SetModelAsNoLongerNeeded(e.hash)
    if e.mine then
        Target.AddEntity(('disp_%s_%d'):format(g.key, e.bay), veh, {
            { label = Text('opt_take_out'), icon = 'fas fa-key', distance = 3.0, canInteract = function() return not cache.vehicle end, onSelect = function() Display.Take(g.key, e.plate) end },
            { label = Text('opt_garage'), icon = 'fas fa-square-parking', distance = 3.0, canInteract = function() return not cache.vehicle end, onSelect = function() Cabinet.Open(g.key) end },
        }, Garages.OpenWith(g) == 'key')
    end
    return veh
end

function Display.Sync(key)
    local g = Garages.byKey[key]
    if not g or not g.display or not enabled() then return unload(key) end
    if Display.syncing[key] then return end
    Display.syncing[key] = true
    local list = Garages.Call('display', key)
    Display.syncing[key] = nil
    if type(list) ~= 'table' then return end
    Display.spawned[key] = Display.spawned[key] or {}
    local want = {}
    for _, e in ipairs(list) do want[e.bay] = e end
    local mode = Garages.OpenWith(g)
    for bay, have in pairs(Display.spawned[key]) do
        local w = want[bay]
        if not w or Util.Plate(w.plate):upper() ~= Util.Plate(have.plate):upper() or w.mine ~= have.mine or have.mode ~= mode then despawn(key, bay) end
    end
    for bay, e in pairs(want) do
        if not Display.spawned[key][bay] then
            local veh = spawnCar(g, e)
            if veh then Display.spawned[key][bay] = { entity = veh, plate = e.plate, mine = e.mine, mode = mode } end
        end
    end
    Display.loaded[key] = true
end

function Display.Refresh()
    for key in pairs(Display.loaded) do
        local g = Garages.byKey[key]
        if not g or not g.display then unload(key) else CreateThread(function() Display.Sync(key) end) end
    end
end

RegisterNetEvent('XS-Garages:client:display', function(key)
    if Display.loaded[key] then Display.Sync(key) end
end)

local function near(g, pos, dist)
    for _, p in ipairs(g.spawns or {}) do
        if #(pos - vector3(p.x + 0.0, p.y + 0.0, p.z + 0.0)) < dist then return true end
    end
    return false
end

CreateThread(function()
    while true do
        Wait(2000)
        if Garages.ready and enabled() then
            local pos = GetEntityCoords(PlayerPedId())
            local dist = (Config.Display or {}).distance or 70.0
            for _, g in ipairs(Garages.list) do
                if g.display then
                    local close = near(g, pos, dist)
                    if close and not Display.loaded[g.key] then
                        Display.Sync(g.key)
                    elseif not close and Display.loaded[g.key] and not near(g, pos, dist + 25.0) then
                        unload(g.key)
                    end
                end
            end
        elseif not enabled() then
            Display.Clear()
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then Display.Clear() end
end)
