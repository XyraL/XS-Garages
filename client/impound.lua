Impound = { allowed = false }

local function refresh()
    Impound.allowed = Garages.Call('canImpound') == true
end

local function form(opts)
    local fees, holds = {}, {}
    for _, f in ipairs(opts.fees or {}) do fees[#fees + 1] = { value = f, label = Util.Money(f) } end
    for _, h in ipairs(opts.holds or {}) do
        holds[#holds + 1] = { value = h, label = h == 0 and Text('impound_no_hold') or Text('impound_hold_hours', { n = h }) }
    end
    local fields = {
        { type = 'select', label = Text('impound_fee'), options = fees, default = fees[1] and fees[1].value, required = true },
    }
    if #holds > 1 then fields[#fields + 1] = { type = 'select', label = Text('impound_hold'), options = holds, default = 0, required = true } end
    fields[#fields + 1] = { type = 'input', label = Text('impound_reason'), placeholder = Text('impound_reason_hint'), max = 200 }
    local input = lib.inputDialog(Text('impound_title'), fields)
    if not input then return nil end
    return { fee = tonumber(input[1]) or 0, hours = #holds > 1 and (tonumber(input[2]) or 0) or 0, reason = input[#holds > 1 and 3 or 2] or '' }
end

function Impound.Start(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return Util.Notify(Text('err_no_vehicle'), 'error') end
    local ok, opts = Garages.Call('impoundOptions')
    if not ok then return Util.Notify(opts or Text('err_failed'), 'error') end
    local choice = form(opts)
    if not choice then return end
    local seconds = (Config.Impound or {}).seconds or 6
    if seconds > 0 then
        local done = lib.progressBar({
            duration = seconds * 1000, label = Text('impound_progress'), useWhileDead = false, canCancel = true,
            disable = { move = true, car = true, combat = true }, anim = { scenario = 'WORLD_HUMAN_CLIPBOARD' },
        })
        ClearPedTasks(PlayerPedId())
        if not done then return end
    end
    if not DoesEntityExist(veh) then return Util.Notify(Text('err_no_vehicle'), 'error') end
    local good, res = Garages.Call('impound', NetworkGetNetworkIdFromEntity(veh), choice)
    if not good then return Util.Notify(res or Text('err_failed'), 'error') end
    Util.Notify(res.owned and Text('impound_done', { plate = res.plate }) or Text('impound_done_local'), 'success')
end

CreateThread(function()
    while not Framework.name do Wait(200) end
    while not Settings.loaded do Wait(200) end
    if not (Config.Impound or {}).enabled then return end
    Target.AddGlobalVehicle('impound', {
        {
            label = Text('opt_impound_vehicle'), icon = 'fas fa-truck-pickup', distance = 3.0,
            canInteract = function(entity) return Impound.allowed and not cache.vehicle and entity and entity ~= 0 end,
            onSelect = function(entity) Impound.Start(entity) end,
        },
    })
    RegisterCommand(Config.Commands.impound or 'impound', function()
        refresh()
        if not Impound.allowed then return Util.Notify(Text('err_not_police'), 'error') end
        local veh = lib.getClosestVehicle(GetEntityCoords(PlayerPedId()), 5.0, false)
        Impound.Start(veh)
    end, false)
end)

Framework.OnLoaded(function() SetTimeout(2500, refresh) end)
Framework.OnJob(function() SetTimeout(500, refresh) end)

CreateThread(function()
    while not Framework.name do Wait(200) end
    Wait(2500)
    if Framework.Loaded() then refresh() end
end)
