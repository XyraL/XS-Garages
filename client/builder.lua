Builder = { open = false, showing = false }

local function round(n, p)
    return Util.Round(n, p or 3)
end

local function here()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local streetHash = GetStreetNameAtCoord(pos.x, pos.y, pos.z)
    local zone = GetNameOfZone(pos.x, pos.y, pos.z)
    local veh = cache.vehicle
    local at = veh and GetEntityCoords(veh) or pos
    return {
        x = round(pos.x), y = round(pos.y), z = round(pos.z - 0.98), w = round(GetEntityHeading(ped), 2),
        vx = round(at.x), vy = round(at.y), vz = round(at.z), vw = round(veh and GetEntityHeading(veh) or GetEntityHeading(ped), 2), inVehicle = veh ~= nil,
        street = GetStreetNameFromHashKey(streetHash), area = GetLabelText(zone),
    }
end

local function show(on)
    Builder.open = on
    UI.Focus('builder', on)
    UI.Send('builder', on and 'show' or 'hide', {})
end

local function load()
    local ok, data = Garages.Call('builderData')
    if not ok then return false, data end
    data.here = here()
    return true, data
end

function Builder.Open()
    local ok, data = load()
    if not ok then return Util.Notify(data or Text('err_not_admin'), 'error') end
    if Cabinet.open then Cabinet.Close() end
    UI.Send('builder', 'open', data)
    Builder.open = true
    UI.Focus('builder', true)
end

UI.OnClose('builder', function()
    Builder.open = false
    UI.Send('builder', 'close', {})
    UI.Focus('builder', false)
end)

local PREVIEW = { car = 'previewCar', boat = 'previewBoat', air = 'previewAir', any = 'previewCar' }

UI.Handle('b:refresh', function() return load() end)
UI.Handle('b:here', function() return true, here() end)

UI.Handle('b:place', function(p)
    p = p or {}
    show(false)
    local ok, result = pcall(function()
        local vehicle = p.kind == 'spawns'
        local model
        if vehicle then model = (Config.Spawn or {})[PREVIEW[p.category or 'car'] or 'previewCar'] or 'sultan' end
        if p.kind == 'desks' and p.look == 'prop' then model = p.prop ~= '' and p.prop or (Config.General or {}).deskProp end
        if p.kind == 'desks' and p.look == 'ped' then model = nil end
        return Placement.Start({ label = p.label, mode = 'point', previewModel = model, previewVehicle = vehicle, origin = p.origin, existing = p.existing })
    end)
    show(true)
    if not ok then
        print(('^1[XS-Garages]^0 placing failed: %s'):format(tostring(result)))
        return false, Text('err_failed')
    end
    if not result then return false, Text('cancelled') end
    return true, { x = round(result.x), y = round(result.y), z = round(result.z), w = round(result.w or 0.0, 2) }
end)

UI.Handle('b:teleport', function(p)
    if not p or not p.x then return false end
    if not Garages.Call('builderTeleport') then return false, Text('err_not_admin') end
    local ped = PlayerPedId()
    DoScreenFadeOut(200)
    Wait(220)
    RequestCollisionAtCoord(p.x + 0.0, p.y + 0.0, p.z + 0.0)
    SetEntityCoordsNoOffset(ped, p.x + 0.0, p.y + 0.0, p.z + 1.0, false, false, false)
    if p.w then SetEntityHeading(ped, p.w + 0.0) end
    local untilAt = GetGameTimer() + 3000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < untilAt do Wait(20) end
    DoScreenFadeIn(250)
    return true
end)

UI.Handle('b:showPoints', function(p)
    local g = p and p.garage
    if not g then return false end
    show(false)
    Builder.showing = true
    CreateThread(function()
        local untilAt = GetGameTimer() + 9000
        local radius = (g.dropRadius or 0) > 0 and g.dropRadius or ((Config.Parking or {}).parkRadius or 6.0)
        lib.showTextUI(Text('builder_showing'), { position = 'left-center' })
        while GetGameTimer() < untilAt do
            for _, d in ipairs(g.desks or {}) do
                DrawMarker(2, d.x + 0.0, d.y + 0.0, d.z + 1.2, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 0.4, 0.4, 0.4, 242, 179, 61, 220, true, false, 2, false, nil, nil, false)
            end
            for _, d in ipairs(g.drops or {}) do
                DrawMarker(1, d.x + 0.0, d.y + 0.0, d.z - 0.6, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, radius * 2.0, radius * 2.0, 0.4, 61, 200, 255, 80, false, false, 2, false, nil, nil, false)
            end
            for i, d in ipairs(g.spawns or {}) do
                local r = math.rad(d.w or 0.0)
                local tip = vector3(d.x - math.sin(r) * 2.4, d.y + math.cos(r) * 2.4, d.z)
                DrawMarker(43, d.x + 0.0, d.y + 0.0, d.z - 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, d.w or 0.0, 2.2, 4.6, 0.3, 61, 255, 122, 70, false, false, 2, false, nil, nil, false)
                DrawLine(d.x + 0.0, d.y + 0.0, d.z + 0.0, tip.x, tip.y, tip.z, 61, 255, 122, 255)
            end
            if IsControlJustPressed(0, 194) or IsControlJustPressed(0, 177) then break end
            Wait(0)
        end
        lib.hideTextUI()
        Builder.showing = false
        show(true)
    end)
    return true
end)

UI.Handle('b:save', function(p) return Garages.Call('builderSave', p.id, p.data) end)
UI.Handle('b:delete', function(p) return Garages.Call('builderDelete', p.id) end)
UI.Handle('b:standard', function(p) return Garages.Call('builderStandard', p.ids) end)
UI.Handle('b:cars', function(p) return Garages.Call('builderCars', p) end)
UI.Handle('b:impounds', function() return Garages.Call('builderImpounds') end)
UI.Handle('b:owner', function(p) return Garages.Call('builderOwner', p.id, p.action, p.payload) end)
UI.Handle('b:players', function(p) return Garages.Call('builderPlayers', p.q) end)
UI.Handle('b:logs', function(p) return Garages.Call('builderLogs', p) end)
UI.Handle('b:settings', function(p) return Garages.Call('builderSettingsSave', p) end)

UI.Handle('b:car', function(p)
    local ok, res = Garages.Call('builderCar', p.plate, p.action, p.payload)
    if not ok then return false, res end
    if p.action == 'where' and type(res) == 'table' then
        SetNewWaypoint(res.x + 0.0, res.y + 0.0)
        return true, res
    end
    return true, res
end)

CreateThread(function()
    while not Framework.name do Wait(200) end
    RegisterCommand(Config.Commands.builder or 'garagebuilder', function()
        if Builder.open then return end
        Builder.Open()
    end, false)
end)
