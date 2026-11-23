local function boot()
    while not Framework.name do Wait(200) end
    if not Db.Setup() then return end
    Settings.Load()
    Garages.Load()
    Private.Load()
    Garages.FirstStart()
    Lost.Startup()
    Display.Load()
    Garages.Changed()
    local n = 0
    for _ in pairs(Garages.list) do n = n + 1 end
    print(('^2[XS-Garages]^0 ready · %d garages · keys: %s · fuel set on the client · banking: %s'):format(n, Keys.name or 'none', Banking.name or 'none'))
    for _, name in ipairs({ 'qb-garages', 'qbx_garages', 'jg-advancedgarages', 'cd_garage', 'okokGarage' }) do
        if GetResourceState(name) == 'started' then
            print(('^3[XS-Garages]^0 %s is running too. Two garage scripts fight over the same cars, so stop %s.'):format(name, name))
        end
    end
end

CreateThread(function()
    local ok, e = pcall(boot)
    if not ok then print(('^1[XS-Garages]^0 could not start: %s'):format(tostring(e))) end
end)

lib.callback.register('XS-Garages:server:isAdmin', function(src)
    return Builder.Allowed(src)
end)

lib.callback.register('XS-Garages:server:canImpound', function(src)
    return Impound.Offered() and Impound.Role(src) ~= nil
end)

AddEventHandler('onResourceStop', function(resource)
    for key, g in pairs(Garages.external) do
        if g.resource == resource then Garages.Unregister(key) end
    end
end)
