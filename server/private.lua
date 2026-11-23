Private = { owners = {} }

local function days(n)
    return math.floor((tonumber(n) or 0) * 86400 + 0.5)
end

function Private.Load()
    Private.owners = {}
    for _, row in ipairs(MySQL.query.await('SELECT * FROM xs_garages_owners') or {}) do
        Private.owners[tonumber(row.garage_id)] = {
            citizenid = row.citizenid, name = row.name, kind = row.kind, price = tonumber(row.price) or 0, since = tonumber(row.since) or 0,
            paid_until = tonumber(row.paid_until) or 0, access = Db.Decode(row.access, {}) or {},
        }
    end
end

local function save(id)
    local o = Private.owners[id]
    if not o then
        MySQL.query.await('DELETE FROM xs_garages_owners WHERE garage_id = ?', { id })
        return
    end
    MySQL.query.await([[INSERT INTO xs_garages_owners (garage_id, citizenid, name, kind, price, since, paid_until, access) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE citizenid = VALUES(citizenid), name = VALUES(name), kind = VALUES(kind), price = VALUES(price), since = VALUES(since),
        paid_until = VALUES(paid_until), access = VALUES(access)]], { id, o.citizenid, o.name, o.kind, o.price, o.since, o.paid_until, Db.Json(o.access or {}) })
end

function Private.HasAccess(src, id)
    local o = Private.owners[id]
    if not o then return false end
    local cid = Framework.GetCitizenId(src)
    if not cid then return false end
    if o.citizenid == cid then return true end
    for _, a in ipairs(o.access or {}) do
        if a.cid == cid then return true end
    end
    return false
end

function Private.Count(cid)
    local n = 0
    for _, o in pairs(Private.owners) do
        if o.citizenid == cid then n = n + 1 end
    end
    return n
end

function Private.Info(src, g)
    local o = Private.owners[g.id]
    local cid = Framework.GetCitizenId(src)
    local d = g.data
    local P = Config.Private or {}
    local info = {
        owned = o ~= nil, mine = o ~= nil and o.citizenid == cid, access = Private.HasAccess(src, g.id), price = d.private.price, rent = d.private.rent,
        buy = d.private.buy, rentable = d.private.rentable, slots = d.private.slots, used = Vehicles.CountAt(d.key), rentDays = P.rentDays or 7,
        sellBack = math.floor((o and o.price or d.private.price) * (P.sellBackPct or 0) / 100), maxAccess = P.maxAccess or 0,
    }
    if o then
        info.kind, info.owner, info.paidUntil, info.since = o.kind, o.name, o.paid_until, o.since
        if info.mine then info.people = o.access or {} end
    end
    return info
end

local function garageOf(src, garageKey)
    local g = Garages.Get(garageKey)
    if not g or g.data.type ~= 'private' or not g.id then return nil, Text('err_no_garage') end
    if not (Config.Private or {}).enabled or not g.data.enabled then return nil, Text('err_closed') end
    if not Garages.Near(src, g, { 'desks', 'spawns', 'drops' }) then return nil, Text('err_too_far') end
    return g
end

local function take(src, garageKey, kind)
    local g, why = garageOf(src, garageKey)
    if not g then return false, why end
    if Private.owners[g.id] then return false, Text('err_taken') end
    local d = g.data
    if kind == 'owned' and not d.private.buy then return false, Text('err_failed') end
    if kind == 'rented' and not d.private.rentable then return false, Text('err_failed') end
    local cid = Framework.GetCitizenId(src)
    if Private.Count(cid) >= ((Config.Private or {}).maxOwned or 1) then return false, Text('err_private_limit') end
    local price = kind == 'owned' and d.private.price or d.private.rent
    if price > 0 and not Framework.Charge(src, price, 'bank', 'xs-garages-private') then return false, Text('err_money', { fee = Util.Money(price) }) end
    local now = os.time()
    Private.owners[g.id] = {
        citizenid = cid, name = Framework.GetName(src) or '', kind = kind, price = price, since = now,
        paid_until = kind == 'rented' and (now + days((Config.Private or {}).rentDays or 7)) or 0, access = {},
    }
    save(g.id)
    Logs.Add(kind == 'owned' and 'buy' or 'rent', d.key, '', Logs.Who(src), '', price)
    Garages.Changed()
    return true, Cabinet.Data(src, g)
end

lib.callback.register('XS-Garages:server:privateBuy', function(src, garageKey) return take(src, garageKey, 'owned') end)
lib.callback.register('XS-Garages:server:privateRent', function(src, garageKey) return take(src, garageKey, 'rented') end)

local function evictCars(g, why)
    local target = Garages.Nearest(g.data.desks[1] or g.data.spawns[1], g.data.category, 'public')
    local key = target and target.data.key or ''
    for _, r in ipairs(Vehicles.ParkedAt(g.data.key)) do Vehicles.SetMeta(r.plate, { bay = 0 }) end
    MySQL.update.await('UPDATE player_vehicles SET garage = ? WHERE garage = ? AND state = 1', { key, g.data.key })
    Display.Rebuild(g.data.key)
    return target and target.data.label or ''
end

function Private.Release(id, who, kind, refund, src)
    local g = Garages.Get(id)
    local o = Private.owners[id]
    if not g or not o then return false end
    if refund and refund > 0 and src then Framework.AddMoney(src, 'bank', refund, 'xs-garages-sell') end
    local movedTo = evictCars(g)
    Private.owners[id] = nil
    save(id)
    Logs.Add(kind, g.data.key, '', who, movedTo ~= '' and Text('log_cars_moved', { garage = movedTo }) or '', refund or 0)
    Garages.Changed()
    return true, movedTo
end

lib.callback.register('XS-Garages:server:privateSell', function(src, garageKey)
    local g, why = garageOf(src, garageKey)
    if not g then return false, why end
    local o = Private.owners[g.id]
    if not o or o.citizenid ~= Framework.GetCitizenId(src) then return false, Text('err_not_yours') end
    local refund = 0
    if o.kind == 'owned' then refund = math.floor(o.price * ((Config.Private or {}).sellBackPct or 0) / 100) end
    local _, movedTo = Private.Release(g.id, Logs.Who(src), 'sell', refund, src)
    return true, { refund = refund, movedTo = movedTo }
end)

lib.callback.register('XS-Garages:server:privatePay', function(src, garageKey)
    local g, why = garageOf(src, garageKey)
    if not g then return false, why end
    local o = Private.owners[g.id]
    if not o or o.citizenid ~= Framework.GetCitizenId(src) or o.kind ~= 'rented' then return false, Text('err_not_yours') end
    local price = g.data.private.rent
    if price > 0 and not Framework.Charge(src, price, 'bank', 'xs-garages-rent') then return false, Text('err_money', { fee = Util.Money(price) }) end
    o.paid_until = math.max(o.paid_until, os.time()) + days((Config.Private or {}).rentDays or 7)
    save(g.id)
    Logs.Add('payment', g.data.key, '', Logs.Who(src), '', price)
    return true, Cabinet.Data(src, g)
end)

lib.callback.register('XS-Garages:server:privateAccess', function(src, garageKey, action, target)
    local g, why = garageOf(src, garageKey)
    if not g then return false, why end
    local o = Private.owners[g.id]
    if not o or o.citizenid ~= Framework.GetCitizenId(src) then return false, Text('err_not_yours') end
    o.access = o.access or {}
    if action == 'add' then
        target = tonumber(target)
        local cid = target and Framework.GetCitizenId(target)
        if not cid or cid == o.citizenid then return false, Text('err_no_player') end
        if #o.access >= ((Config.Private or {}).maxAccess or 0) then return false, Text('err_access_limit') end
        for _, a in ipairs(o.access) do if a.cid == cid then return false, Text('err_has_access') end end
        o.access[#o.access + 1] = { cid = cid, name = Framework.GetName(target) or '' }
        Framework.Notify(target, Text('got_access', { garage = g.data.label }), 'success')
        Logs.Add('access', g.data.key, '', Logs.Who(src), Text('log_access_add', { name = Framework.GetName(target) or '' }))
    elseif action == 'remove' then
        for i, a in ipairs(o.access) do
            if a.cid == target then
                table.remove(o.access, i)
                Logs.Add('access', g.data.key, '', Logs.Who(src), Text('log_access_remove', { name = a.name }))
                break
            end
        end
    else
        return false, Text('err_failed')
    end
    save(g.id)
    Garages.Changed()
    return true, Cabinet.Data(src, g)
end)

function Private.AdminSet(id, cid, name, kind)
    local g = Garages.Get(id)
    if not g then return false end
    if not cid then
        if Private.owners[id] then Private.Release(id, { citizenid = 'admin', name = 'Admin' }, 'evict', 0) end
        return true
    end
    local now = os.time()
    Private.owners[id] = {
        citizenid = cid, name = name or '', kind = kind == 'rented' and 'rented' or 'owned', price = g.data.private.price, since = now,
        paid_until = kind == 'rented' and (now + days((Config.Private or {}).rentDays or 7)) or 0, access = {},
    }
    save(id)
    Garages.Changed()
    return true
end

local function rentTick()
    local P = Config.Private or {}
    local now = os.time()
    for id, o in pairs(Private.owners) do
        if o.kind == 'rented' and o.paid_until > 0 and o.paid_until <= now then
            local g = Garages.Get(id)
            if not g then
                Private.owners[id] = nil
                save(id)
            else
                local price = g.data.private.rent
                local paid = false
                local src = Framework.SourceOf(o.citizenid)
                if P.autoPay ~= false and src then paid = price <= 0 or Framework.RemoveMoney(src, 'bank', price, 'xs-garages-rent') end
                if paid then
                    o.paid_until = o.paid_until + days(P.rentDays or 7)
                    save(id)
                    Logs.Add('payment', g.data.key, '', { citizenid = o.citizenid, name = o.name }, Text('log_auto_rent'), price)
                    if src then Framework.Notify(src, Text('rent_paid', { garage = g.data.label, fee = Util.Money(price) }), 'inform') end
                elseif now > o.paid_until + days(P.graceDays or 0) then
                    Private.Release(id, { citizenid = o.citizenid, name = o.name }, 'evict', 0)
                    if src then Framework.Notify(src, Text('rent_evicted', { garage = g.data.label }), 'error') end
                elseif src and not o.warned then
                    o.warned = true
                    Framework.Notify(src, Text('rent_due', { garage = g.data.label, fee = Util.Money(price) }), 'error')
                end
            end
        end
    end
end

CreateThread(function()
    while not Garages.ready do Wait(1000) end
    while true do
        Wait(5 * 60 * 1000)
        local ok, e = pcall(rentTick)
        if not ok then print(('^1[XS-Garages]^0 rent check failed: %s'):format(tostring(e))) end
    end
end)
