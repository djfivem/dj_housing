Housing = Housing or {}

local handlers = {}

local function ctx()
    return Housing.Runtime.context
end

local function playerReady(source)
    local current = ctx()
    if not current or current.framework.name == 'unconfigured' then
        return nil, Housing.Util.fail('framework_unavailable', current and current.framework.reason or 'framework')
    end
    return current
end

handlers.dashboard = function(source, payload)
    local current, blocked = playerReady(source)
    if not current then return blocked end
    return Housing.Services.dashboard(current, source, payload and payload.propertyId or nil)
end

handlers.purchase = function(source, payload)
    local current, blocked = playerReady(source)
    if not current then return blocked end
    return Housing.Services.purchase(current, source, payload)
end

handlers.rent = function(source, payload)
    local current, blocked = playerReady(source)
    if not current then return blocked end
    return Housing.Services.rent(current, source, payload)
end

handlers.renew = function(source, payload)
    local current, blocked = playerReady(source)
    if not current then return blocked end
    return Housing.Services.renewRent(current, source, payload)
end

handlers.sell = function(source, payload)
    local current, blocked = playerReady(source)
    if not current then return blocked end
    return Housing.Services.sellToState(current, source, payload)
end

handlers.list = function(source, payload)
    local current, blocked = playerReady(source)
    if not current then return blocked end
    return Housing.Services.listProperty(current, source, payload)
end

handlers.unlist = function(source, payload)
    local current, blocked = playerReady(source)
    if not current then return blocked end
    return Housing.Services.unlistProperty(current, source, payload and payload.propertyId or nil)
end

handlers.enter = function(source, payload)
    local current, blocked = playerReady(source)
    if not current then return blocked end
    local result = Housing.Services.enterProperty(current, source, payload and payload.propertyId or nil)
    if result.ok then
        local position = current.position(source)
        current.setInstance(source, result.data, position or result.data.entrance)
        result.data.returnCoords = current.instances[source].returnCoords
    end
    return result
end

handlers.exit = function(source)
    local current, blocked = playerReady(source)
    if not current then return blocked end
    local previous = current.clearInstance(source)
    if not previous then
        return Housing.Util.fail('not_found')
    end
    return Housing.Util.ok({
        propertyId = previous.propertyId,
        returnCoords = previous.returnCoords,
        bucket = 0,
    })
end

handlers.payBill = function(source, payload)
    local current, blocked = playerReady(source)
    if not current then return blocked end
    return Housing.Services.payBill(current, source, payload)
end

handlers.payAll = function(source, payload)
    local current, blocked = playerReady(source)
    if not current then return blocked end
    return Housing.Services.payAllBills(current, source, payload and payload.propertyId or nil)
end

handlers.buyFurniture = function(source, payload)
    local current, blocked = playerReady(source)
    if not current then return blocked end
    return Housing.Services.buyFurniture(current, source, payload)
end

handlers.placeFurniture = function(source, payload)
    local current, blocked = playerReady(source)
    if not current then return blocked end
    return Housing.Services.placeFurniture(current, source, payload)
end

handlers.buyUpgrade = function(source, payload)
    local current, blocked = playerReady(source)
    if not current then return blocked end
    return Housing.Services.buyUpgrade(current, source, payload)
end

handlers.storeVehicle = function(source, payload)
    local current, blocked = playerReady(source)
    if not current then return blocked end
    local result = Housing.Services.storeVehicle(current, source, payload and payload.propertyId or nil)
    if result.ok then
        local vehicle = current.vehicle(source)
        if vehicle and vehicle.entity then
            DeleteEntity(vehicle.entity)
        end
    end
    return result
end

handlers.takeVehicle = function(source, payload)
    local current, blocked = playerReady(source)
    if not current then return blocked end
    return Housing.Services.takeVehicle(current, source, payload)
end

handlers.restoreVehicle = function(source, payload)
    local current, blocked = playerReady(source)
    if not current then return blocked end
    return Housing.Services.restoreVehicle(current, source, payload)
end

handlers.openStash = function(source, payload)
    local current, blocked = playerReady(source)
    if not current then return blocked end
    return Housing.Services.openStash(current, source, payload)
end

handlers.grantAccess = function(source, payload)
    local current, blocked = playerReady(source)
    if not current then return blocked end
    return Housing.Services.grantAccess(current, source, payload)
end

handlers.revokeAccess = function(source, payload)
    local current, blocked = playerReady(source)
    if not current then return blocked end
    return Housing.Services.revokeAccess(current, source, payload)
end

handlers.issueKey = function(source, payload)
    local current, blocked = playerReady(source)
    if not current then return blocked end
    return Housing.Services.issueKey(current, source, payload or {})
end

handlers.revokeKey = function(source, payload)
    local current, blocked = playerReady(source)
    if not current then return blocked end
    return Housing.Services.revokeKey(current, source, payload)
end

handlers.transferKey = function(source, payload)
    local current, blocked = playerReady(source)
    if not current then return blocked end
    return Housing.Services.transferKey(current, source, payload)
end

handlers.revokePropertyKeys = function(source, payload)
    local current, blocked = playerReady(source)
    if not current then return blocked end
    return Housing.Services.revokePropertyKeys(current, source, payload and payload.propertyId or nil)
end

handlers.recoverKey = function(source, payload)
    local current, blocked = playerReady(source)
    if not current then return blocked end
    return Housing.Services.recoverKey(current, source, payload and payload.keyId or nil)
end

handlers.requestWarrant = function(source, payload)
    local current, blocked = playerReady(source)
    if not current then return blocked end
    return Housing.Services.requestWarrant(current, source, payload)
end

handlers.decideWarrant = function(source, payload)
    local current, blocked = playerReady(source)
    if not current then return blocked end
    return Housing.Services.decideWarrant(current, source, payload)
end

handlers.openRaid = function(source, payload)
    local current, blocked = playerReady(source)
    if not current then return blocked end
    return Housing.Services.openRaid(current, source, payload)
end

handlers.setRaidState = function(source, payload)
    local current, blocked = playerReady(source)
    if not current then return blocked end
    return Housing.Services.setRaidState(current, source, payload)
end

handlers.inspectStash = function(source, payload)
    local current, blocked = playerReady(source)
    if not current then return blocked end
    return Housing.Services.inspectStash(current, source, payload)
end

handlers.seize = function(source, payload)
    local current, blocked = playerReady(source)
    if not current then return blocked end
    return Housing.Services.seizeItem(current, source, payload)
end

handlers.transferEvidence = function(source, payload)
    local current, blocked = playerReady(source)
    if not current then return blocked end
    return Housing.Services.transferEvidence(current, source, payload)
end

handlers.adminEnable = function(source, payload)
    local current, blocked = playerReady(source)
    if not current then return blocked end
    return Housing.Services.setPropertyEnabled(current, source, payload and payload.propertyId, payload and payload.enabled == true)
end

handlers.adminArchive = function(source, payload)
    local current, blocked = playerReady(source)
    if not current then return blocked end
    return Housing.Services.archiveProperty(current, source, payload)
end

handlers.adminTransfer = function(source, payload)
    local current, blocked = playerReady(source)
    if not current then return blocked end
    return Housing.Services.adminTransfer(current, source, payload)
end

handlers.adminRepair = function(source, payload)
    local current, blocked = playerReady(source)
    if not current then return blocked end
    return Housing.Services.repairProperty(current, source, payload and payload.propertyId)
end

handlers.setPropertyImage = function(source, payload)
    local current, blocked = playerReady(source)
    if not current then return blocked end
    return Housing.Services.setPropertyImage(current, source, payload)
end

handlers.prepareImageUpload = function(source, payload)
    local current, blocked = playerReady(source)
    if not current then return blocked end
    return Housing.Services.prepareImageUpload(current, source, payload)
end

handlers.collectPayouts = function(source)
    local current, blocked = playerReady(source)
    if not current then return blocked end
    return Housing.Services.collectPayouts(current, source)
end

function Housing.Callbacks.dispatch(source, name, payload)
    if type(name) ~= 'string' or not handlers[name] then
        return Housing.Util.fail('invalid_payload')
    end
    local encoded = json.encode(payload or {})
    if not encoded or not Housing.Validation.payloadSize(encoded) then
        return Housing.Util.fail('invalid_payload')
    end
    local current = ctx()
    if current and not current.rateLimiter.allow('src:' .. tostring(source), 'ui') and name == 'dashboard' then
        return Housing.Util.fail('rate_limited')
    end
    local ok, result = pcall(handlers[name], source, payload or {})
    if not ok then
        Housing.Util.log('error', ('callback %s failed: %s'):format(name, tostring(result)))
        return Housing.Util.fail('internal_error')
    end
    return result
end

function Housing.Callbacks.names()
    local list = {}
    for name in pairs(handlers) do
        list[#list + 1] = name
    end
    return list
end
