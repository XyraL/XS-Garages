Util = {}

Util.TYPES = { 'public', 'job', 'gang', 'private', 'impound' }
Util.CATEGORIES = { 'car', 'boat', 'air', 'any' }

function Util.Clamp(value, low, high)
    value = tonumber(value) or low
    if value < low then return low end
    if value > high then return high end
    return value
end

function Util.Round(value, places)
    local mult = 10 ^ (places or 0)
    return math.floor((tonumber(value) or 0) * mult + 0.5) / mult
end

function Util.Truthy(value)
    return value == true or value == 1 or value == '1' or value == 'true'
end

function Util.Copy(value)
    if type(value) ~= 'table' then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = Util.Copy(v) end
    return out
end

function Util.Text(value, max)
    if value == nil then return '' end
    value = tostring(value):gsub('[%c]', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if max and #value > max then value = value:sub(1, max) end
    return value
end

function Util.Slug(value, max)
    return (tostring(value or ''):lower():gsub('[^%w_%-]', '')):sub(1, max or 48)
end

function Util.Plate(value)
    return (tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

function Util.SamePlate(a, b)
    return Util.Plate(a):upper() == Util.Plate(b):upper()
end

function Util.Point(value)
    if type(value) ~= 'table' and type(value) ~= 'vector3' and type(value) ~= 'vector4' then return nil end
    local x, y, z = tonumber(value.x), tonumber(value.y), tonumber(value.z)
    if not x or not y or not z then return nil end
    local out = { x = Util.Round(x, 3), y = Util.Round(y, 3), z = Util.Round(z, 3), w = Util.Round(tonumber(value.w or value.h) or 0.0, 2) }
    return out
end

function Util.Distance(a, b)
    if not a or not b then return math.huge end
    local dx, dy, dz = (a.x or 0) - (b.x or 0), (a.y or 0) - (b.y or 0), (a.z or 0) - (b.z or 0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function Util.Money(n)
    local s = tostring(math.floor(tonumber(n) or 0))
    local neg = s:sub(1, 1) == '-'
    if neg then s = s:sub(2) end
    s = s:reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
    return (neg and '-$' or '$') .. s
end

function Util.Span(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local d, h, m = seconds // 86400, (seconds % 86400) // 3600, (seconds % 3600) // 60
    if d > 0 then return ('%dd %dh'):format(d, h) end
    if h > 0 then return ('%dh %02dm'):format(h, m) end
    if m > 0 then return ('%dm'):format(m) end
    return ('%ds'):format(seconds)
end

function Util.Now()
    if IsDuplicityVersion() then return os.time() end
    return math.floor(GetCloudTimeAsInt())
end

function Util.Has(list, value)
    for _, v in ipairs(list or {}) do
        if v == value then return true end
    end
    return false
end

function Util.CategoryOfClass(class)
    class = tonumber(class) or 0
    if class == 14 then return 'boat' end
    if class == 15 or class == 16 then return 'air' end
    return 'car'
end

function Util.Fits(garageCategory, vehicleCategory)
    if not garageCategory or garageCategory == 'any' then return true end
    return garageCategory == (vehicleCategory or 'car')
end

function Util.IsPolice(job)
    if not job or not job.name then return false end
    local I = Config.Impound or {}
    if Util.Has(I.jobs, job.name) then return true end
    if job.type and Util.Has(I.types, job.type) then return true end
    return false
end
