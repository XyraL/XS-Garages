Settings = { fields = {}, byKey = {} }

local OPEN_WITH = { 'key', 'target' }
local LOST_START = { 'garage', 'impound', 'keep' }
local LOST_REMOVED = { 'impound', 'garage', 'keep' }
local UNITS = { 'mi', 'km' }

Settings.Sections = {
    { id = 'general', icon = 'gear', fields = {
        { 'General.openWith', 'select', options = OPEN_WITH },
        { 'General.attendants', 'bool' },
        { 'General.markers', 'bool' },
        { 'General.blips', 'bool' },
        { 'General.warpIn', 'bool' },
        { 'General.fade', 'bool' },
        { 'General.lockOnSpawn', 'bool' },
        { 'General.engineOff', 'bool' },
        { 'General.deskPed', 'text', max = 48, slug = true, needs = 'General.attendants' },
        { 'General.deskScenario', 'text', max = 64, empty = true, needs = 'General.attendants' },
        { 'General.deskProp', 'text', max = 48, slug = true },
        { 'General.photos', 'text', max = 200, empty = true },
    } },
    { id = 'parking', icon = 'parking', fields = {
        { 'Parking.anywhere', 'bool' },
        { 'Parking.moveFee', 'int', min = 0, max = 1000000, step = 50, unit = '$' },
        { 'Parking.takeOutFee', 'int', min = 0, max = 1000000, step = 10, unit = '$' },
        { 'Parking.parkFee', 'int', min = 0, max = 1000000, step = 10, unit = '$' },
        { 'Parking.ownerOnly', 'bool' },
        { 'Parking.keysParkers', 'bool' },
        { 'Parking.passengersOut', 'bool' },
        { 'Parking.keepDamage', 'bool' },
        { 'Parking.keepFuel', 'bool' },
        { 'Parking.minEngine', 'int', min = 0, max = 1000, step = 50 },
        { 'Parking.parkRadius', 'num', min = 2, max = 30, step = 0.5, unit = 'm' },
        { 'Parking.clearRadius', 'num', min = 1, max = 10, step = 0.5, unit = 'm' },
    } },
    { id = 'lost', icon = 'search', fields = {
        { 'Lost.onRestart', 'select', options = LOST_START },
        { 'Lost.whenRemoved', 'select', options = LOST_REMOVED },
        { 'Lost.fee', 'int', min = 0, max = 1000000, step = 50, unit = '$' },
        { 'Lost.atGarage', 'bool' },
        { 'Lost.garageFee', 'int', min = 0, max = 1000000, step = 50, unit = '$', needs = 'Lost.atGarage' },
        { 'Lost.findCommand', 'bool' },
    } },
    { id = 'impound', icon = 'tow', fields = {
        { 'Impound.enabled', 'bool' },
        { 'Impound.withPoliceSystem', 'bool', needs = 'Impound.enabled' },
        { 'Impound.jobs', 'list', max = 20, slug = true, needs = 'Impound.enabled' },
        { 'Impound.types', 'list', max = 10, slug = true, needs = 'Impound.enabled' },
        { 'Impound.minGrade', 'grade', needs = 'Impound.enabled' },
        { 'Impound.duty', 'bool', needs = 'Impound.enabled' },
        { 'Impound.fees', 'nums', min = 0, max = 1000000, count = 8, unit = '$', needs = 'Impound.enabled' },
        { 'Impound.holds', 'nums', min = 0, max = 720, count = 8, unit = 'h', needs = 'Impound.enabled' },
        { 'Impound.seconds', 'int', min = 0, max = 60, unit = 's', needs = 'Impound.enabled' },
        { 'Impound.society', 'text', max = 48, slug = true, empty = true, needs = 'Impound.enabled' },
        { 'Impound.towJob', 'text', max = 48, slug = true, empty = true, needs = 'Impound.enabled' },
    } },
    { id = 'transfer', icon = 'swap', fields = {
        { 'Transfer.toPlayer', 'bool' },
        { 'Transfer.fee', 'int', min = 0, max = 1000000, step = 50, unit = '$', needs = 'Transfer.toPlayer' },
        { 'Transfer.nearby', 'bool', needs = 'Transfer.toPlayer' },
        { 'Transfer.range', 'num', min = 2, max = 50, step = 0.5, unit = 'm', needs = 'Transfer.nearby' },
        { 'Share.job', 'bool' },
        { 'Share.gang', 'bool' },
    } },
    { id = 'private', icon = 'key', fields = {
        { 'Private.enabled', 'bool' },
        { 'Private.maxOwned', 'int', min = 1, max = 20, needs = 'Private.enabled' },
        { 'Private.maxAccess', 'int', min = 0, max = 50, needs = 'Private.enabled' },
        { 'Private.sellBackPct', 'pct', needs = 'Private.enabled' },
        { 'Private.rentDays', 'num', min = 0.5, max = 60, step = 0.5, unit = 'days', needs = 'Private.enabled' },
        { 'Private.autoPay', 'bool', needs = 'Private.enabled' },
        { 'Private.graceDays', 'num', min = 0, max = 30, step = 0.5, unit = 'days', needs = 'Private.enabled' },
    } },
    { id = 'fleet', icon = 'badge', fields = {
        { 'Fleet.perPlayer', 'int', min = 1, max = 10 },
        { 'Fleet.returnOnLogout', 'bool' },
        { 'Fleet.fullFuel', 'bool' },
    } },
    { id = 'extras', icon = 'gauge', fields = {
        { 'Mileage.enabled', 'bool' },
        { 'Mileage.unit', 'select', options = UNITS, needs = 'Mileage.enabled' },
        { 'Display.enabled', 'bool' },
        { 'Display.distance', 'num', min = 20, max = 300, step = 5, unit = 'm', needs = 'Display.enabled' },
    } },
    { id = 'map', icon = 'mapblip', fields = {
        { 'Blips.onlyMine', 'bool' },
        { 'Blips.public.sprite', 'int', min = 1, max = 900 },
        { 'Blips.public.colour', 'int', min = 0, max = 85 },
        { 'Blips.job.sprite', 'int', min = 1, max = 900 },
        { 'Blips.job.colour', 'int', min = 0, max = 85 },
        { 'Blips.gang.sprite', 'int', min = 1, max = 900 },
        { 'Blips.gang.colour', 'int', min = 0, max = 85 },
        { 'Blips.private.sprite', 'int', min = 1, max = 900 },
        { 'Blips.private.colour', 'int', min = 0, max = 85 },
        { 'Blips.impound.sprite', 'int', min = 1, max = 900 },
        { 'Blips.impound.colour', 'int', min = 0, max = 85 },
        { 'Blips.boat.sprite', 'int', min = 1, max = 900 },
        { 'Blips.air.sprite', 'int', min = 1, max = 900 },
    } },
    { id = 'builder', icon = 'tools', fields = {
        { 'Builder.showExisting', 'bool' },
        { 'Builder.cameraSpeed.normal', 'num', min = 1, max = 30, step = 0.5, unit = 'm/s' },
        { 'Builder.cameraSpeed.fast', 'num', min = 1, max = 60, step = 0.5, unit = 'm/s' },
        { 'Builder.cameraSpeed.slow', 'num', min = 0.2, max = 10, step = 0.1, unit = 'm/s' },
        { 'Spawn.previewCar', 'text', max = 32, slug = true },
        { 'Spawn.previewBoat', 'text', max = 32, slug = true },
        { 'Spawn.previewAir', 'text', max = 32, slug = true },
        { 'Logs.keepDays', 'int', min = 1, max = 365, unit = 'days' },
        { 'Logs.webhooks.parking', 'text', max = 200, empty = true },
        { 'Logs.webhooks.impound', 'text', max = 200, empty = true },
        { 'Logs.webhooks.transfers', 'text', max = 200, empty = true },
        { 'Logs.webhooks.private', 'text', max = 200, empty = true },
        { 'Logs.webhooks.admin', 'text', max = 200, empty = true },
    } },
}

for _, section in ipairs(Settings.Sections) do
    local list = {}
    for _, raw in ipairs(section.fields) do
        local def = { key = raw[1], type = raw[2], section = section.id }
        for k, v in pairs(raw) do
            if type(k) == 'string' then def[k] = v end
        end
        list[#list + 1] = def
        Settings.fields[#Settings.fields + 1] = def
        Settings.byKey[def.key] = def
    end
    section.fields = list
end

local function path(key)
    local parts = {}
    for part in key:gmatch('[^%.]+') do parts[#parts + 1] = tonumber(part) or part end
    return parts
end

function Settings.Read(key)
    local node = Config
    for _, part in ipairs(path(key)) do
        if type(node) ~= 'table' then return nil end
        node = node[part]
    end
    return node
end

function Settings.Write(key, value)
    local parts = path(key)
    local node = Config
    for i = 1, #parts - 1 do
        if type(node[parts[i]]) ~= 'table' then node[parts[i]] = {} end
        node = node[parts[i]]
    end
    node[parts[#parts]] = value
end

function Settings.Same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'table' then return a == b end
    if #a ~= #b then return false end
    for k, v in pairs(a) do
        if not Settings.Same(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

local function slug(value, max)
    return (tostring(value or ''):lower():gsub('[^%w_%-]', '')):sub(1, max or 48)
end

local function within(def, n)
    if def.min and n < def.min then n = def.min end
    if def.max and n > def.max then n = def.max end
    return n
end

function Settings.Clean(def, value)
    local kind = def.type
    if kind == 'bool' then
        if type(value) == 'boolean' then return value end
        if value == 1 or value == '1' or value == 'true' then return true end
        if value == 0 or value == '0' or value == 'false' then return false end
        return nil
    elseif kind == 'int' or kind == 'grade' or kind == 'pct' then
        local n = tonumber(value)
        if not n or n ~= n then return nil end
        n = math.floor(n + 0.5)
        if kind == 'grade' then return math.max(0, math.min(50, n)) end
        if kind == 'pct' then return math.max(0, math.min(100, n)) end
        return within(def, n)
    elseif kind == 'num' then
        local n = tonumber(value)
        if not n or n ~= n then return nil end
        local step = def.step or 0.1
        n = math.floor(n / step + 0.5) * step
        n = math.floor(n * 1000 + 0.5) / 1000
        return within(def, n)
    elseif kind == 'text' then
        if value == nil or type(value) == 'table' then return nil end
        local s = Util.Text(value, 220)
        if def.slug then s = slug(s, 96) end
        s = s:sub(1, def.max or 64)
        if s == '' and not def.empty then return nil end
        return s
    elseif kind == 'select' then
        for _, option in ipairs(def.options or {}) do
            if option == value then return value end
        end
        return nil
    elseif kind == 'item' then
        local s = (value == false or value == nil) and '' or slug(value, 64)
        if s ~= '' then return s end
        if def.off then return false end
        return nil
    elseif kind == 'list' then
        if type(value) ~= 'table' then return nil end
        local out, seen = {}, {}
        for _, v in ipairs(value) do
            local s = def.slug and slug(v, 48) or Util.Text(v, 48)
            if s ~= '' and not seen[s] and #out < (def.max or 20) then
                seen[s] = true
                out[#out + 1] = s
            end
        end
        return out
    elseif kind == 'nums' then
        if type(value) ~= 'table' then return nil end
        local out, seen = {}, {}
        for _, v in ipairs(value) do
            local n = tonumber(v)
            if n then
                n = within(def, math.floor(n + 0.5))
                if not seen[n] and #out < (def.count or 10) then
                    seen[n] = true
                    out[#out + 1] = n
                end
            end
        end
        table.sort(out)
        if #out == 0 then return nil end
        return out
    elseif kind == 'seq' then
        if type(value) ~= 'table' then return nil end
        local allowed = {}
        for _, option in ipairs(def.options or {}) do allowed[option] = true end
        local out = {}
        for _, v in ipairs(value) do
            if allowed[v] and #out < (def.max or 5) then out[#out + 1] = v end
        end
        if #out == 0 then return nil end
        return out
    end
    return nil
end

function Settings.Apply(values)
    if type(values) ~= 'table' then return end
    for key, value in pairs(values) do
        local def = Settings.byKey[key]
        if def then
            local clean = Settings.Clean(def, value)
            if clean ~= nil then Settings.Write(key, clean) end
        end
    end
end

function Settings.Public()
    local sections = {}
    for _, section in ipairs(Settings.Sections) do
        local fields = {}
        for _, def in ipairs(section.fields) do
            local out = {}
            for k, v in pairs(def) do out[k] = v end
            fields[#fields + 1] = out
        end
        sections[#sections + 1] = { id = section.id, icon = section.icon, fields = fields }
    end
    return sections
end
