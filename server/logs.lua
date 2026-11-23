Logs = {}

local HOOK_OF = {
    park = 'parking', takeout = 'parking', move = 'parking', fleet = 'parking', lost = 'parking',
    impound = 'impound', release = 'impound', hold = 'impound',
    transfer = 'transfers', share = 'transfers',
    buy = 'private', rent = 'private', sell = 'private', evict = 'private', access = 'private', payment = 'private',
    admin = 'admin', create = 'admin', delete = 'admin',
}

local COLOURS = { parking = 3447003, impound = 15158332, transfers = 3066993, private = 15844367, admin = 9807270 }

local function webhook(kind, title, text)
    local hook = HOOK_OF[kind]
    local url = hook and ((Config.Logs or {}).webhooks or {})[hook]
    if type(url) ~= 'string' or not url:match('^https://') then return end
    local body = json.encode({
        username = 'XS-Garages',
        embeds = { { title = title, description = text, color = COLOURS[hook] or 9807270, timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ') } },
    })
    PerformHttpRequest(url, function() end, 'POST', body, { ['Content-Type'] = 'application/json' })
end

function Logs.Who(src)
    if not src or src == 0 then return { citizenid = 'console', name = 'Console' } end
    return { citizenid = Framework.GetCitizenId(src) or '', name = Framework.GetName(src) or GetPlayerName(src) or '' }
end

function Logs.Add(kind, garage, plate, who, detail, amount)
    if not Db.ready then return end
    who = who or {}
    local name = Util.Text(who.name or '', 100)
    MySQL.insert('INSERT INTO xs_garages_logs (garage, kind, plate, citizenid, name, detail, amount, at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        Util.Text(garage or '', 64), kind, Util.Text(plate or '', 16), who.citizenid or '', name, Util.Text(detail or '', 255), math.floor(tonumber(amount) or 0), os.time(),
    })
    local g = garage and Garages and Garages.Get(garage)
    local where = g and g.data.label or (garage ~= '' and garage) or '—'
    local money = (tonumber(amount) or 0) ~= 0 and (' · ' .. Util.Money(amount)) or ''
    webhook(kind, ('%s · %s'):format(Text('log_kind_' .. kind), where), ('%s%s%s\n%s'):format(name ~= '' and name or '—', plate and plate ~= '' and (' · ' .. plate) or '', money, Util.Text(detail or '', 255)))
end

function Logs.Fetch(filter)
    filter = type(filter) == 'table' and filter or {}
    local where, args = {}, {}
    if type(filter.garage) == 'string' and filter.garage ~= '' then where[#where + 1] = 'garage = ?' args[#args + 1] = filter.garage end
    if type(filter.plate) == 'string' and filter.plate ~= '' then where[#where + 1] = 'plate = ?' args[#args + 1] = Util.Plate(filter.plate) end
    if type(filter.kind) == 'string' and filter.kind ~= '' and filter.kind ~= 'all' then
        local kinds = {}
        for k, hook in pairs(HOOK_OF) do
            if hook == filter.kind or k == filter.kind then kinds[#kinds + 1] = k end
        end
        if #kinds > 0 then
            where[#where + 1] = ('kind IN (%s)'):format(('?,'):rep(#kinds):sub(1, -2))
            for _, k in ipairs(kinds) do args[#args + 1] = k end
        end
    end
    if type(filter.q) == 'string' and filter.q ~= '' then
        where[#where + 1] = '(name LIKE ? OR detail LIKE ? OR citizenid = ? OR plate = ?)'
        local like = '%' .. Util.Text(filter.q, 40):gsub('[%%_]', '') .. '%'
        args[#args + 1], args[#args + 2], args[#args + 3], args[#args + 4] = like, like, Util.Text(filter.q, 64), Util.Plate(filter.q):upper()
    end
    local sql = 'SELECT id, garage, kind, plate, citizenid, name, detail, amount, at FROM xs_garages_logs'
    if #where > 0 then sql = sql .. ' WHERE ' .. table.concat(where, ' AND ') end
    sql = sql .. ' ORDER BY id DESC LIMIT ' .. math.floor(Util.Clamp(filter.limit or 150, 1, 500))
    return MySQL.query.await(sql, args) or {}
end

CreateThread(function()
    while not Db.ready do Wait(1000) end
    while true do
        local keep = math.max(1, tonumber((Config.Logs or {}).keepDays) or 30)
        pcall(MySQL.query.await, 'DELETE FROM xs_garages_logs WHERE at < ?', { os.time() - keep * 86400 })
        Wait(6 * 3600 * 1000)
    end
end)
