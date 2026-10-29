Housing = Housing or {}
Housing.Util = Housing.Util or {}

local Util = Housing.Util

function Util.ok(data)
    return { ok = true, data = data or {} }
end

function Util.fail(code, detail)
    return { ok = false, error = code, detail = detail }
end

function Util.isFiniteNumber(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

function Util.trim(value)
    if type(value) ~= 'string' then
        return nil
    end
    return (value:gsub('^%s+', ''):gsub('%s+$', ''))
end

function Util.clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

function Util.deepCopy(value, seen)
    if type(value) ~= 'table' then
        return value
    end
    if value == Housing.Null then
        return Housing.Null
    end
    seen = seen or {}
    if seen[value] then
        return seen[value]
    end
    local copy = {}
    seen[value] = copy
    for key, item in pairs(value) do
        copy[Util.deepCopy(key, seen)] = Util.deepCopy(item, seen)
    end
    return copy
end

function Util.uuid(rng)
    rng = rng or math.random
    local function nybble()
        return rng(0, 15)
    end
    local chars = {}
    for index = 1, 36 do
        local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
        local marker = template:sub(index, index)
        if marker == '-' or marker == '4' then
            chars[index] = marker
        elseif marker == 'x' then
            chars[index] = string.format('%x', nybble())
        else
            chars[index] = string.format('%x', 8 + (nybble() % 4))
        end
    end
    return table.concat(chars)
end

function Util.bucketFor(propertyId)
    local hash = 2166136261
    for index = 1, #propertyId do
        hash = (hash ~ string.byte(propertyId, index)) & 0xffffffff
        hash = (hash * 16777619) & 0xffffffff
    end
    local bucket = (hash % 60000) + 1
    if bucket == 0 then
        bucket = 1
    end
    return bucket
end

function Util.shellOrigin(propertyId)
    local slot = Util.bucketFor(propertyId)
    local column = slot % 12
    local row = math.floor(slot / 12) % 12
    local layer = math.floor(slot / 144)
    return {
        x = 2500.0 + (column * 90.0),
        y = 2500.0 + (row * 90.0),
        z = -220.0 - (layer * 45.0),
        w = 0.0,
    }
end

function Util.offsetCoords(origin, offset)
    local heading = math.rad(origin.w or 0.0)
    local cosH = math.cos(heading)
    local sinH = math.sin(heading)
    local ox = offset.x or 0.0
    local oy = offset.y or 0.0
    return {
        x = origin.x + (ox * cosH) - (oy * sinH),
        y = origin.y + (ox * sinH) + (oy * cosH),
        z = origin.z + (offset.z or 0.0),
        w = ((origin.w or 0.0) + (offset.w or 0.0)) % 360.0,
    }
end

function Util.distance(a, b)
    if not a or not b then
        return math.huge
    end
    local dx = (a.x or 0.0) - (b.x or 0.0)
    local dy = (a.y or 0.0) - (b.y or 0.0)
    local dz = (a.z or 0.0) - (b.z or 0.0)
    return math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
end

function Util.stashIdentifier(propertyId, stashKey, ownerCharacterId)
    if ownerCharacterId then
        return ('ah:%s:%s:%s'):format(propertyId, stashKey, ownerCharacterId)
    end
    return ('ah:%s:%s'):format(propertyId, stashKey)
end

function Util.truncate(value, maxLen)
    if type(value) ~= 'string' then
        return nil
    end
    if #value <= maxLen then
        return value
    end
    return value:sub(1, maxLen)
end

function Util.now(clock)
    if clock then
        return clock()
    end
    return os.time()
end

function Util.copyList(list)
    local copy = {}
    for index = 1, #(list or {}) do
        copy[index] = Util.deepCopy(list[index])
    end
    return copy
end

function Util.contains(list, value)
    for index = 1, #(list or {}) do
        if list[index] == value then
            return true
        end
    end
    return false
end

function Util.sanitizeMetadata(metadata)
    if type(metadata) ~= 'table' then
        return nil
    end
    local clean = {}
    local count = 0
    for key, value in pairs(metadata) do
        count = count + 1
        if count > 16 or type(key) ~= 'string' or #key > 32 then
            return nil, 'metadata'
        end
        local valueType = type(value)
        if valueType == 'string' then
            if #value > 160 then
                return nil, 'metadata'
            end
            clean[key] = value
        elseif valueType == 'number' then
            if not Util.isFiniteNumber(value) then
                return nil, 'metadata'
            end
            clean[key] = value
        elseif valueType == 'boolean' then
            clean[key] = value
        else
            return nil, 'metadata'
        end
    end
    return clean
end

function Util.log(level, message)
    print(('[advanced_housing] [%s] %s'):format(level, message))
end
