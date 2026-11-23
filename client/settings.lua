local function apply(values)
    if type(values) ~= 'table' then return end
    Settings.Apply(values)
    Settings.loaded = true
    UI.Send('core', 'config', UI.PublicConfig())
    if Garages and Garages.Refresh then Garages.Refresh() end
end

RegisterNetEvent('XS-Garages:client:settings', apply)

CreateThread(function()
    while not Framework.name do Wait(200) end
    apply(lib.callback.await('XS-Garages:server:settings', false))
end)
