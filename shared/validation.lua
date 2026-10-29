Housing = Housing or {}
Housing.Validation = Housing.Validation or {}

local Validation = Housing.Validation
local Util = Housing.Util
local Limits = Housing.Limits

local function invalid(reason)
    return false, reason
end

function Validation.identifier(value)
    if type(value) ~= 'string' then
        return invalid('identifier')
    end
    if #value < 3 or #value > 64 or not value:match('^[a-z0-9_]+$') then
        return invalid('identifier')
    end
    return true, value
end

function Validation.idempotencyKey(value)
    if type(value) ~= 'string' then
        return invalid('idempotency')
    end
    if #value < Limits.minIdempotency or #value > Limits.maxIdempotency then
        return invalid('idempotency')
    end
    if not value:match('^[%w%-]+$') then
        return invalid('idempotency')
    end
    return true, value
end

function Validation.shortString(value, maxLen)
    if type(value) ~= 'string' then
        return invalid('string')
    end
    local trimmed = Util.trim(value)
    maxLen = maxLen or Limits.maxString
    if not trimmed or #trimmed == 0 or #trimmed > maxLen then
        return invalid('string')
    end
    return true, trimmed
end

function Validation.optionalString(value, maxLen)
    if value == nil then
        return true, nil
    end
    return Validation.shortString(value, maxLen)
end

function Validation.money(value)
    if type(value) ~= 'number' or value % 1 ~= 0 then
        return invalid('money')
    end
    if value < Limits.minPrice or value > Limits.maxPrice then
        return invalid('money')
    end
    return true, value
end

function Validation.quantity(value)
    if type(value) ~= 'number' or value % 1 ~= 0 then
        return invalid('quantity')
    end
    if value < 1 or value > Limits.maxQuantity then
        return invalid('quantity')
    end
    return true, value
end

function Validation.coords(value, requireHeading)
    if type(value) ~= 'table' then
        return invalid('coords')
    end
    if not Util.isFiniteNumber(value.x) or not Util.isFiniteNumber(value.y) or not Util.isFiniteNumber(value.z) then
        return invalid('coords')
    end
    if value.x < Limits.coordMin or value.x > Limits.coordMax or value.y < Limits.coordMin or value.y > Limits.coordMax then
        return invalid('coords')
    end
    if value.z < Limits.zMin or value.z > Limits.zMax then
        return invalid('coords')
    end
    local heading = value.w or value.h or 0.0
    if requireHeading and not Util.isFiniteNumber(heading) then
        return invalid('coords')
    end
    if not Util.isFiniteNumber(heading) or heading < -360.0 or heading > 360.0 then
        return invalid('coords')
    end
    return true, { x = value.x + 0.0, y = value.y + 0.0, z = value.z + 0.0, w = heading + 0.0 }
end

function Validation.propertyDefinition(definition, shells)
    if type(definition) ~= 'table' then
        return invalid('property')
    end
    local ok, id = Validation.identifier(definition.id)
    if not ok then return invalid('id') end
    local labelOk, label = Validation.shortString(definition.label, 80)
    if not labelOk then return invalid('label') end
    local description = definition.description or ''
    if type(description) ~= 'string' or #description > Limits.maxText then
        return invalid('description')
    end
    if not Housing.PropertyType[definition.propertyType] then
        return invalid('property_type')
    end
    local priceOk, price = Validation.money(definition.purchasePrice)
    if not priceOk then return invalid('purchase_price') end
    local rentOk, rent = Validation.money(definition.rentalPrice or 0)
    if not rentOk then return invalid('rental_price') end
    local period = definition.rentalPeriodHours or 0
    if type(period) ~= 'number' or period % 1 ~= 0 or period < 0 or period > 24 * 365 then
        return invalid('rental_period')
    end
    local entranceOk, entrance = Validation.coords(definition.entrance, true)
    if not entranceOk then return invalid('entrance') end
    local interiorOk, interior = Validation.coords(definition.interior, true)
    if not interiorOk then return invalid('interior') end
    if definition.propertyType == 'shell' or definition.propertyType == 'apartment' then
        if type(definition.shellModel) ~= 'string' or not shells[definition.shellModel] then
            return invalid('shell_model')
        end
    end
    if definition.propertyType == 'ipl' then
        if type(definition.ipls) ~= 'table' or #definition.ipls < 1 then
            return invalid('ipls')
        end
        for index = 1, #definition.ipls do
            local name = definition.ipls[index]
            if type(name) ~= 'string' or not name:match('^[%w_]+$') or #name > 64 then
                return invalid('ipls')
            end
        end
    end
    if definition.shellOptions then
        if type(definition.shellOptions) ~= 'table' then
            return invalid('shell_options')
        end
        for index = 1, #definition.shellOptions do
            if not shells[definition.shellOptions[index]] then
                return invalid('shell_options')
            end
        end
    end
    local garage = nil
    if definition.garage ~= nil then
        local garageOk, garageCoords = Validation.coords(definition.garage, true)
        if not garageOk then return invalid('garage') end
        garage = garageCoords
    end
    local stashes = definition.stashes or {}
    if type(stashes) ~= 'table' or #stashes > Limits.maxStashesPerProperty then
        return invalid('stashes')
    end
    local seen = {}
    for index = 1, #stashes do
        local stash = stashes[index]
        local keyOk, key = Validation.identifier(stash.key)
        if not keyOk then return invalid('stash_key') end
        if seen[key] then return invalid('duplicate_stash') end
        seen[key] = true
        if stash.slots ~= nil and (type(stash.slots) ~= 'number' or stash.slots < 1 or stash.slots > 200) then
            return invalid('stash_slots')
        end
        if stash.maxWeight ~= nil and (type(stash.maxWeight) ~= 'number' or stash.maxWeight < 1 or stash.maxWeight > 10000000) then
            return invalid('stash_weight')
        end
        if stash.accessLevel and not Housing.AccessRole[stash.accessLevel] then
            return invalid('stash_access')
        end
        if stash.stashType ~= 'shared' and stash.stashType ~= 'personal' and stash.stashType ~= 'restricted' then
            return invalid('stash_type')
        end
    end
    local zoneOk, zone = Validation.zone(definition.zone)
    if not zoneOk then return invalid('zone') end
    return true, {
        id = id,
        label = label,
        description = description,
        propertyType = definition.propertyType,
        purchasePrice = price,
        rentalPrice = rent,
        rentalPeriodHours = period,
        entrance = entrance,
        interior = interior,
        shellModel = definition.shellModel,
        shellOptions = definition.shellOptions,
        ipls = definition.ipls or {},
        image = definition.image or 'default',
        bedrooms = definition.bedrooms or 1,
        bathrooms = definition.bathrooms or 1,
        garages = definition.garages or 0,
        garage = garage,
        stashes = stashes,
        features = definition.features or {},
        zone = zone,
    }
end

function Validation.zone(value)
    if value == nil then
        return true, nil
    end
    if type(value) ~= 'table' or type(value.points) ~= 'table' or #value.points < 3 or #value.points > 64 then
        return invalid('zone')
    end
    local points = {}
    for index = 1, #value.points do
        local point = value.points[index]
        if type(point) ~= 'table' or not Util.isFiniteNumber(point.x) or not Util.isFiniteNumber(point.y) then
            return invalid('zone')
        end
        points[index] = { x = point.x + 0.0, y = point.y + 0.0 }
    end
    if value.minZ ~= nil and not Util.isFiniteNumber(value.minZ) then
        return invalid('zone')
    end
    if value.maxZ ~= nil and not Util.isFiniteNumber(value.maxZ) then
        return invalid('zone')
    end
    if value.minZ ~= nil and value.maxZ ~= nil and value.maxZ < value.minZ then
        return invalid('zone')
    end
    return true, { points = points, minZ = value.minZ, maxZ = value.maxZ }
end

function Validation.imageUrl(value, hosts)
    if type(value) ~= 'string' or #value < 12 or #value > 512 or not value:match('^https://') then
        return invalid('image')
    end
    local host = value:match('^https://([^/%?#]+)')
    if not host then
        return invalid('image')
    end
    host = host:lower()
    local allowed = false
    for index = 1, #(hosts or {}) do
        local rule = tostring(hosts[index]):lower()
        if host == rule or host:sub(-(#rule + 1)) == '.' .. rule then
            allowed = true
        end
    end
    if not allowed then
        return invalid('image_host')
    end
    return true, value
end

function Validation.purchaseRequest(request)
    if type(request) ~= 'table' then
        return invalid('request')
    end
    local idOk, propertyId = Validation.identifier(request.propertyId)
    if not idOk then return invalid('property') end
    local keyOk, idempotencyKey = Validation.idempotencyKey(request.idempotencyKey)
    if not keyOk then return invalid('idempotency') end
    if request.mode ~= 'purchase' and request.mode ~= 'rent' and request.mode ~= 'renew' then
        return invalid('mode')
    end
    if request.expectedPrice ~= nil then
        local priceOk, price = Validation.money(request.expectedPrice)
        if not priceOk then return invalid('price') end
        request = Util.deepCopy(request)
        request.expectedPrice = price
    end
    local shellModel = nil
    if request.shellModel ~= nil then
        if type(request.shellModel) ~= 'string' or #request.shellModel > 64 or not request.shellModel:match('^[%w_]+$') then
            return invalid('shell')
        end
        shellModel = request.shellModel
    end
    return true, {
        propertyId = propertyId,
        idempotencyKey = idempotencyKey,
        mode = request.mode,
        expectedPrice = request.expectedPrice,
        shellModel = shellModel,
    }
end

function Validation.accessGrant(request)
    if type(request) ~= 'table' then
        return invalid('request')
    end
    local idOk, propertyId = Validation.identifier(request.propertyId)
    if not idOk then return invalid('property') end
    local keyOk, idempotencyKey = Validation.idempotencyKey(request.idempotencyKey)
    if not keyOk then return invalid('idempotency') end
    if not Housing.AccessRole[request.role] or request.role == 'owner' then
        return invalid('role')
    end
    local targetOk, targetId = Validation.shortString(request.targetCharacterId or '', 80)
    if not targetOk or not request.targetCharacterId:match('^[%w%:%_%.%-]+$') then
        return invalid('target')
    end
    local frameworkOk, framework = Validation.shortString(request.targetFramework or '', 16)
    if not frameworkOk or not request.targetFramework:match('^[a-z]+$') then
        return invalid('framework')
    end
    local nameOk, displayName = Validation.optionalString(request.displayName, 64)
    if not nameOk then return invalid('name') end
    local hours = request.expiresInHours
    if hours ~= nil and (type(hours) ~= 'number' or hours < 1 or hours > 24 * 30 or hours % 1 ~= 0) then
        return invalid('expiry')
    end
    return true, {
        propertyId = propertyId,
        idempotencyKey = idempotencyKey,
        role = request.role,
        targetCharacterId = targetId,
        targetFramework = framework,
        displayName = displayName,
        expiresInHours = hours,
    }
end

function Validation.keyAction(request)
    if type(request) ~= 'table' then
        return invalid('request')
    end
    local keyOk, idempotencyKey = Validation.idempotencyKey(request.idempotencyKey)
    if not keyOk then return invalid('idempotency') end
    local propertyOk, propertyId = Validation.identifier(request.propertyId)
    if not propertyOk then return invalid('property') end
    local level = request.accessLevel or 'guest'
    if not Housing.AccessRole[level] then
        return invalid('access_level')
    end
    return true, {
        propertyId = propertyId,
        idempotencyKey = idempotencyKey,
        accessLevel = level,
        targetSource = request.targetSource,
        keyId = request.keyId,
    }
end

function Validation.stashRequest(request)
    if type(request) ~= 'table' then
        return invalid('request')
    end
    local propertyOk, propertyId = Validation.identifier(request.propertyId)
    if not propertyOk then return invalid('property') end
    local stashOk, stashKey = Validation.identifier(request.stashKey)
    if not stashOk then return invalid('stash') end
    return true, { propertyId = propertyId, stashKey = stashKey }
end

function Validation.seizeRequest(request)
    if type(request) ~= 'table' then
        return invalid('request')
    end
    local keyOk, idempotencyKey = Validation.idempotencyKey(request.idempotencyKey)
    if not keyOk then return invalid('idempotency') end
    local propertyOk, propertyId = Validation.identifier(request.propertyId)
    if not propertyOk then return invalid('property') end
    local stashOk, stashKey = Validation.identifier(request.stashKey)
    if not stashOk then return invalid('stash') end
    local raidOk, raidId = Validation.idempotencyKey(request.raidId)
    if not raidOk then return invalid('raid') end
    local itemOk, itemName = Validation.shortString(request.itemName or '', 48)
    if not itemOk or not request.itemName:match('^[%w_%-]+$') then
        return invalid('item')
    end
    local qtyOk, quantity = Validation.quantity(request.quantity)
    if not qtyOk then return invalid('quantity') end
    local slot = request.slot
    if slot ~= nil and (type(slot) ~= 'number' or slot < 1 or slot > 500 or slot % 1 ~= 0) then
        return invalid('slot')
    end
    return true, {
        idempotencyKey = idempotencyKey,
        propertyId = propertyId,
        stashKey = stashKey,
        raidId = raidId,
        itemName = itemName,
        quantity = quantity,
        slot = slot,
    }
end

function Validation.warrantRequest(request)
    if type(request) ~= 'table' then
        return invalid('request')
    end
    local keyOk, idempotencyKey = Validation.idempotencyKey(request.idempotencyKey)
    if not keyOk then return invalid('idempotency') end
    local propertyOk, propertyId = Validation.identifier(request.propertyId)
    if not propertyOk then return invalid('property') end
    local reasonOk, reason = Validation.shortString(request.reason or '', Limits.maxReason)
    if not reasonOk then return invalid('reason') end
    local caseOk, caseReference = Validation.optionalString(request.caseReference, 64)
    if not caseOk then return invalid('case') end
    local hours = request.durationHours or 12
    if type(hours) ~= 'number' or hours < 1 or hours > 168 or hours % 1 ~= 0 then
        return invalid('duration')
    end
    local scope = request.scope or { all = true }
    if type(scope) ~= 'table' then
        return invalid('scope')
    end
    return true, {
        idempotencyKey = idempotencyKey,
        propertyId = propertyId,
        reason = reason,
        caseReference = caseReference,
        durationHours = hours,
        scope = scope,
        allowSeizure = request.allowSeizure == true,
    }
end

function Validation.furniturePlace(request)
    if type(request) ~= 'table' then
        return invalid('request')
    end
    local idOk, furnitureId = Validation.idempotencyKey(request.furnitureId)
    if not idOk then return invalid('furniture') end
    local propertyOk, propertyId = Validation.identifier(request.propertyId)
    if not propertyOk then return invalid('property') end
    local coordsOk, coords = Validation.coords(request.offset, true)
    if not coordsOk then return invalid('offset') end
    if math.abs(coords.x) > Limits.maxOffset or math.abs(coords.y) > Limits.maxOffset or math.abs(coords.z) > Limits.maxOffset then
        return invalid('offset')
    end
    return true, { furnitureId = furnitureId, propertyId = propertyId, offset = coords }
end

function Validation.payloadSize(body)
    if type(body) ~= 'string' then
        return false
    end
    return #body <= Limits.maxPayloadBytes
end
