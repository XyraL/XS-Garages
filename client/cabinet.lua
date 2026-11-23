Cabinet = { open = false, key = nil }

local function annotate(data)
    if type(data) ~= 'table' then return data end
    local cat = data.garage and data.garage.category or 'any'
    for _, c in ipairs(data.cars or {}) do
        if (c.category or '') == '' and c.hash then c.category = Util.CategoryOfClass(GetVehicleClassFromName(c.hash)) end
        c.fits = Util.Fits(cat, c.category)
    end
    return data
end

local function close()
    if not Cabinet.open then return end
    Cabinet.open = false
    Cabinet.key = nil
    UI.Send('garage', 'close', {})
    UI.Focus('garage', false)
end

function Cabinet.Close()
    close()
end

UI.OnClose('garage', close)

function Cabinet.Open(key)
    if Cabinet.open then return end
    local ok, data = Garages.Call('open', key)
    if not ok then return Util.Notify(data or Text('err_failed'), 'error') end
    Cabinet.open = true
    Cabinet.key = key
    UI.Send('garage', 'open', annotate(data))
    UI.Focus('garage', true)
end

exports('OpenGarage', function(key) Cabinet.Open(key) end)

local function reload()
    if not Cabinet.open then return false end
    local ok, data = Garages.Call('open', Cabinet.key)
    if ok then UI.Send('garage', 'update', annotate(data)) end
    return ok, annotate(data)
end

local function landing(res)
    close()
    Util.Fade(true, 250)
    Cars.Land(res)
    if (res.fee or 0) > 0 then Util.Notify(Text('took_out_fee', { fee = Util.Money(res.fee) }), 'success') end
end

UI.Handle('c:take', function(p)
    local ok, res = Garages.Call('takeOut', Cabinet.key, p.plate)
    if not ok then return false, res end
    CreateThread(function() landing(res) end)
    return true
end)

UI.Handle('c:fleet', function(p)
    local ok, res = Garages.Call('fleetTake', Cabinet.key, p.index)
    if not ok then return false, res end
    CreateThread(function() landing(res) end)
    return true
end)

UI.Handle('c:fleetBuy', function(p)
    local ok, res = Garages.Call('fleetBuy', Cabinet.key, p.index)
    if not ok then return false, res end
    return true, annotate(res)
end)

UI.Handle('c:move', function(p)
    local ok, res = Garages.Call('move', Cabinet.key, p.plate)
    if not ok then return false, res end
    return true, annotate(res)
end)

UI.Handle('c:rename', function(p)
    local ok, res = Garages.Call('rename', p.plate, p.name)
    if not ok then return false, res end
    return reload()
end)

UI.Handle('c:favourite', function(p)
    local ok, res = Garages.Call('favourite', p.plate, p.on == true)
    if not ok then return false, res end
    return true
end)

UI.Handle('c:share', function(p)
    local ok, res = Garages.Call('share', p.plate, p.kind or '')
    if not ok then return false, res end
    return reload()
end)

UI.Handle('c:nearby', function()
    return true, Garages.Call('nearby') or {}
end)

UI.Handle('c:give', function(p)
    local ok, res = Garages.Call('give', p.plate, p.target)
    if not ok then return false, res end
    return reload()
end)

UI.Handle('c:track', function(p)
    local ok, res = Garages.Call('track', p.plate)
    if not ok then return false, res end
    Cars.Mark({ { x = res.x, y = res.y, z = res.z, plate = p.plate, label = p.label } })
    return true
end)

local function withData(ok, res)
    if not ok then return false, res end
    return true, annotate(res)
end

UI.Handle('c:privateBuy', function() return withData(Garages.Call('privateBuy', Cabinet.key)) end)
UI.Handle('c:privateRent', function() return withData(Garages.Call('privateRent', Cabinet.key)) end)
UI.Handle('c:privatePay', function() return withData(Garages.Call('privatePay', Cabinet.key)) end)
UI.Handle('c:privateAccess', function(p) return withData(Garages.Call('privateAccess', Cabinet.key, p.action, p.target)) end)

UI.Handle('c:privateSell', function()
    local ok, res = Garages.Call('privateSell', Cabinet.key)
    if not ok then return false, res end
    CreateThread(close)
    if (res.refund or 0) > 0 then Util.Notify(Text('private_sold', { fee = Util.Money(res.refund) }), 'success') else Util.Notify(Text('private_left'), 'success') end
    return true
end)

UI.Handle('c:reload', function() return reload() end)

RegisterNetEvent('XS-Garages:client:close', close)
