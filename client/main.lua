Garages = { list = {}, byKey = {}, ready = false, blips = {}, desks = {}, zones = {} }

function Util.LoadModel(model, timeout)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return false end
    if HasModelLoaded(hash) then return true end
    RequestModel(hash)
    local untilAt = GetGameTimer() + (timeout or 8000)
    while not HasModelLoaded(hash) and GetGameTimer() < untilAt do Wait(20) end
    return HasModelLoaded(hash)
end

function Util.Notify(msg, kind)
    if not msg or msg == '' then return end
    Framework.Notify(msg, kind)
end

function Util.Fade(out, ms)
    if (Config.General or {}).fade == false then return end
    ms = ms or 300
    if out then
        DoScreenFadeOut(ms)
        local untilAt = GetGameTimer() + ms + 1500
        while not IsScreenFadedOut() and GetGameTimer() < untilAt do Wait(10) end
    else
        DoScreenFadeIn(ms)
    end
end

function Garages.Call(name, ...)
    return UI.Await(name, ...)
end

local function v3(p)
    return vector3(p.x + 0.0, p.y + 0.0, p.z + 0.0)
end

function Garages.Visible(g)
    if not g then return false end
    if g.type == 'job' then
        local job = Framework.Job()
        if not job or job.name ~= g.job.name then return false end
        return (job.grade or 0) >= (g.job.grade or 0) or job.isBoss == true
    elseif g.type == 'gang' then
        local gang = Framework.Gang()
        if not gang or gang.name ~= g.gang.name then return false end
        return (gang.grade or 0) >= (g.gang.grade or 0) or gang.isBoss == true
    elseif g.type == 'private' then
        local p = g.private or {}
        if p.access then return true end
        return not p.owned
    elseif g.type == 'house' then
        return g.access == true
    end
    return true
end

local function blipShown(g)
    if not g.blip or not g.blip.show or (Config.General or {}).blips == false then return false end
    if g.type == 'house' then return false end
    if g.type == 'private' then
        local p = g.private or {}
        if not p.owned then return true end
        if (Config.Blips or {}).onlyMine ~= false then return p.access == true end
        return true
    end
    return Garages.Visible(g)
end

local function clearBlips()
    for _, b in pairs(Garages.blips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    Garages.blips = {}
end

function Garages.Blips()
    clearBlips()
    for _, g in ipairs(Garages.list) do
        local at = g.desks[1] or g.spawns[1]
        if at and blipShown(g) then
            local b = AddBlipForCoord(at.x + 0.0, at.y + 0.0, at.z + 0.0)
            SetBlipSprite(b, g.blip.sprite)
            SetBlipColour(b, g.blip.colour)
            SetBlipScale(b, 0.7)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(g.blip.label)
            EndTextCommandSetBlipName(b)
            Garages.blips[g.key] = b
        end
    end
end

function Garages.OpenWith(g)
    local own = g and g.look and g.look.open
    if own == 'key' or own == 'target' then return own end
    return (Config.General or {}).openWith == 'target' and 'target' or 'key'
end

local function deskLabel(g)
    if g.type == 'impound' then return Text('opt_impound') end
    if g.type == 'private' and g.private and not g.private.owned then return Text('opt_private_sale') end
    if g.type == 'job' or g.type == 'gang' then return Text('opt_motor_pool') end
    return Text('opt_garage')
end

local function deskOptions(g)
    return {
        {
            label = deskLabel(g), icon = g.type == 'impound' and 'fas fa-truck-pickup' or 'fas fa-square-parking', distance = 2.5,
            canInteract = function() return not cache.vehicle and Garages.Visible(Garages.byKey[g.key]) end,
            onSelect = function() Cabinet.Open(g.key) end,
        },
    }
end

local function removeDesk(id)
    local d = Garages.desks[id]
    if not d then return end
    Target.RemoveEntity(id)
    if d.entity and DoesEntityExist(d.entity) then DeleteEntity(d.entity) end
    Target.Remove(id)
    Garages.desks[id] = nil
end

local function clearDesks()
    for id in pairs(Garages.desks) do removeDesk(id) end
end

local function lookOf(g)
    local look = g.look or {}
    local G = Config.General or {}
    local kind = look.desk or 'ped'
    if kind == 'ped' and G.attendants ~= true then kind = 'marker' end
    return kind, (look.ped ~= '' and look.ped) or G.deskPed or 's_m_y_valet_01', (look.scenario ~= '' and look.scenario) or G.deskScenario or '', (look.prop ~= '' and look.prop) or G.deskProp or 'prop_parknmeter_01'
end

local function groundZ(p)
    local found, z = GetGroundZFor_3dCoord(p.x + 0.0, p.y + 0.0, p.z + 1.5, false)
    if found and math.abs(z - p.z) < 2.0 then return z end
    return p.z + 0.0
end

local function spawnDesk(id, g, p)
    local d = Garages.desks[id]
    local kind, ped, scenario, prop = lookOf(g)
    if kind == 'ped' then
        if not Util.LoadModel(ped, 5000) then kind = 'marker' else
            local z = groundZ(p)
            local e = CreatePed(4, joaat(ped), p.x + 0.0, p.y + 0.0, z, (p.w or 0.0) + 0.0, false, false)
            SetEntityAsMissionEntity(e, true, true)
            SetBlockingOfNonTemporaryEvents(e, true)
            SetEntityInvincible(e, true)
            FreezeEntityPosition(e, true)
            SetPedCanRagdoll(e, false)
            if scenario ~= '' then TaskStartScenarioInPlace(e, scenario, 0, true) end
            SetModelAsNoLongerNeeded(joaat(ped))
            d.entity = e
        end
    elseif kind == 'prop' then
        if not Util.LoadModel(prop, 5000) then kind = 'marker' else
            local e = CreateObjectNoOffset(joaat(prop), p.x + 0.0, p.y + 0.0, groundZ(p), false, false, false)
            SetEntityHeading(e, (p.w or 0.0) + 0.0)
            FreezeEntityPosition(e, true)
            SetModelAsNoLongerNeeded(joaat(prop))
            d.entity = e
        end
    end
    local prompt = Garages.OpenWith(g) == 'key'
    if d.entity then
        Target.AddEntity(id, d.entity, deskOptions(g), prompt)
    else
        d.marker = kind == 'marker'
        Target.AddPoint(id, v3(p) + vector3(0.0, 0.0, 1.0), 1.4, deskOptions(g), prompt)
    end
    d.spawned = true
end

function Garages.Rebuild()
    clearDesks()
    for _, g in ipairs(Garages.list) do
        for i, p in ipairs(g.desks or {}) do
            local id = ('%s_%d'):format(g.key, i)
            Garages.desks[id] = { key = g.key, point = p, spawned = false }
        end
    end
    Garages.Blips()
end

function Garages.Refresh()
    CreateThread(function()
        local list = Garages.Call('garages')
        if type(list) ~= 'table' then return end
        Garages.list = list
        Garages.byKey = {}
        for _, g in ipairs(list) do Garages.byKey[g.key] = g end
        Garages.Rebuild()
        Garages.ready = true
        if Display and Display.Refresh then Display.Refresh() end
    end)
end

RegisterNetEvent('XS-Garages:client:refresh', function()
    if Framework.Loaded() then Garages.Refresh() end
end)

CreateThread(function()
    while true do
        Wait(1000)
        if Garages.ready then
            local pos = GetEntityCoords(PlayerPedId())
            for id, d in pairs(Garages.desks) do
                local g = Garages.byKey[d.key]
                local dist = #(pos - v3(d.point))
                if g and not d.spawned and dist < 60.0 and Garages.Visible(g) then
                    spawnDesk(id, g, d.point)
                elseif d.spawned and (dist > 80.0 or not Garages.Visible(g)) then
                    Target.RemoveEntity(id)
                    if d.entity and DoesEntityExist(d.entity) then DeleteEntity(d.entity) end
                    Target.Remove(id)
                    d.entity, d.spawned, d.marker = nil, false, nil
                end
            end
        end
    end
end)

function Garages.CategoryOf(veh)
    return Util.CategoryOfClass(GetVehicleClass(veh))
end

local function parkRadius(g)
    return (g.dropRadius or 0) > 0 and g.dropRadius or ((Config.Parking or {}).parkRadius or 6.0)
end

local function nearestDrop(pos, veh)
    local cat = Garages.CategoryOf(veh)
    local best, bestDist, bestPoint = nil, math.huge, nil
    for _, g in ipairs(Garages.list) do
        if g.type ~= 'impound' and Util.Fits(g.category, cat) and Garages.Visible(g) and (g.type ~= 'private' or (g.private and g.private.access)) then
            local radius = parkRadius(g) + (cat ~= 'car' and 20.0 or 0.0)
            for _, p in ipairs(g.drops or {}) do
                local dist = #(pos - v3(p))
                if dist <= radius and dist < bestDist then best, bestDist, bestPoint = g, dist, p end
            end
            if g.display then
                for _, p in ipairs(g.spawns or {}) do
                    local dist = #(pos - v3(p))
                    if dist <= 3.0 and dist < bestDist then best, bestDist, bestPoint = g, dist, p end
                end
            end
        end
    end
    return best, bestPoint
end

local function drawMarkers(pos)
    if (Config.General or {}).markers == false then return end
    for _, g in ipairs(Garages.list) do
        if Garages.Visible(g) then
            for _, p in ipairs(g.drops or {}) do
                if #(pos - v3(p)) < 40.0 then
                    local r = parkRadius(g)
                    DrawMarker(1, p.x + 0.0, p.y + 0.0, p.z - 0.6, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, r * 0.6, r * 0.6, 0.35, 242, 179, 61, 70, false, false, 2, false, nil, nil, false)
                end
            end
        end
    end
end

local function drawDeskMarkers(pos)
    if (Config.General or {}).markers == false then return end
    for _, d in pairs(Garages.desks) do
        if d.marker and #(pos - v3(d.point)) < 25.0 then
            DrawMarker(36, d.point.x + 0.0, d.point.y + 0.0, d.point.z + 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.7, 0.7, 0.7, 242, 179, 61, 170, true, false, 2, true, nil, nil, false)
        end
    end
end

local function parkPaused()
    if IsNuiFocused() then return 'focus' end
    if (Placement ~= nil and Placement.active == true) or (Builder ~= nil and Builder.showing == true) then return 'builder' end
    return nil
end

CreateThread(function()
    local shown = nil
    while true do
        local wait = 600
        local pause = parkPaused()
        if Garages.ready and not pause then
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local veh = cache.vehicle
            if veh and GetPedInVehicleSeat(veh, -1) == ped then
                local g = nearestDrop(pos, veh)
                local near = g ~= nil
                if not near then
                    for _, other in ipairs(Garages.list) do
                        for _, p in ipairs(other.drops or {}) do
                            if #(pos - v3(p)) < 45.0 then near = true break end
                        end
                        if near then break end
                    end
                end
                if near then
                    drawMarkers(pos)
                    wait = 0
                else
                    wait = 400
                end
                if g then
                    local text = ('[E] %s · %s'):format(Text('prompt_park'), g.label)
                    if shown ~= text then
                        lib.showTextUI(text, { position = 'right-center', icon = 'square-parking' })
                        shown = text
                    end
                    if IsControlJustReleased(0, 38) and not Park.busy then
                        lib.hideTextUI()
                        shown = nil
                        Park.Do(g.key, veh)
                    end
                elseif shown then
                    lib.hideTextUI()
                    shown = nil
                end
            else
                if shown then
                    lib.hideTextUI()
                    shown = nil
                end
                drawDeskMarkers(pos)
                for _, d in pairs(Garages.desks) do
                    if d.marker and #(pos - v3(d.point)) < 25.0 then wait = 0 break end
                end
            end
        elseif shown then
            if pause ~= 'builder' then lib.hideTextUI() end
            shown = nil
        end
        Wait(wait)
    end
end)

local function start()
    local untilAt = GetGameTimer() + 10000
    while not Settings.loaded and GetGameTimer() < untilAt do Wait(100) end
    Garages.Refresh()
end

Framework.OnLoaded(function() SetTimeout(1500, start) end)
Framework.OnUnloaded(function()
    clearDesks()
    clearBlips()
    Garages.list, Garages.byKey, Garages.ready = {}, {}, false
    if Display and Display.Clear then Display.Clear() end
end)
Framework.OnJob(function()
    if Garages.ready then Garages.Refresh() end
end)

CreateThread(function()
    while not Framework.name do Wait(200) end
    Wait(1000)
    if Framework.Loaded() then start() end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    clearDesks()
    clearBlips()
    lib.hideTextUI()
end)
