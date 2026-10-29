Housing = Housing or {}
Housing.Garages = Housing.Garages or {}

local Auth = Housing.Auth

local autoOrder = {
    { id = 'jg-advancedgarages', resource = 'jg-advancedgarages' },
    { id = 'qb-garages', resource = 'qb-garages' },
}

local function empty(report)
    return {
        name = 'builtin',
        liveVerified = false,
        report = report or 'builtin',
        registerAll = function() end,
        registerFor = function() end,
    }
end

local function garagesOf(ctx)
    local list = {}
    if not ctx then
        return list
    end
    local properties = ctx.repo.listProperties()
    for index = 1, #properties do
        local property = properties[index]
        if property.garage and property.enabled ~= 0 then
            list[#list + 1] = property
        end
    end
    return list
end

function Housing.Garages.notify(propertyId)
    local adapter = Housing.Runtime and Housing.Runtime.garages
    if not adapter or type(adapter.refresh) ~= 'function' or type(propertyId) ~= 'string' then
        return false
    end
    local ok, refreshed = pcall(adapter.refresh, propertyId)
    return ok and refreshed == true
end

function Housing.Garages.hasAccess(source, propertyId)
    local ctx = Housing.Runtime and Housing.Runtime.context
    if not ctx or type(propertyId) ~= 'string' then
        return false
    end
    local player = ctx.framework.getPlayer(source)
    if not player then
        return false
    end
    return Auth.canEnter(ctx, player, propertyId) == true
end

function Housing.Garages.list()
    local ctx = Housing.Runtime and Housing.Runtime.context
    local rows = garagesOf(ctx)
    local list = {}
    for index = 1, #rows do
        list[#list + 1] = {
            propertyId = rows[index].id,
            label = rows[index].label,
            garage = rows[index].garage,
        }
    end
    return list
end

function Housing.Garages.bind(config, env)
    local setting = (config.Integrations.garage or {}).system or 'builtin'
    if setting == 'builtin' then
        return empty('builtin')
    end
    if setting == 'cd_garage' or setting == 'okokGarage' then
        return empty(setting .. ' manages vehicle keys, not house garage locations. The built-in plate list remains.')
    end
    local chosen
    if setting == 'auto' then
        for index = 1, #autoOrder do
            if env.getResourceState(autoOrder[index].resource) == 'started' then
                chosen = autoOrder[index]
                break
            end
        end
        if not chosen then
            return empty('builtin')
        end
    elseif setting == 'qs-advancedgarages' then
        chosen = { id = 'qs-advancedgarages', resource = 'qs-advancedgarages' }
    else
        for index = 1, #autoOrder do
            if autoOrder[index].id == setting then
                chosen = autoOrder[index]
            end
        end
    end
    if not chosen or env.getResourceState(chosen.resource) ~= 'started' then
        return empty(chosen and (chosen.id .. ' is not started. The built-in plate list remains.') or 'builtin')
    end
    if chosen.id == 'jg-advancedgarages' then
        local registered = {}
        local function optionsFor(property)
            local garage = property.garage
            local propertyId = property.id
            return {
                id = 'housing_' .. propertyId,
                name = property.label .. ' Garage',
                coords = { x = garage.x, y = garage.y, z = garage.z },
                spawnPoints = { { x = garage.x, y = garage.y, z = garage.z, w = garage.w or 0.0 } },
                access = function(playerSource)
                    return Housing.Garages.hasAccess(playerSource, propertyId) == true
                end,
                manageInteractions = true,
                distance = 15,
                vehicleType = 'car',
            }
        end
        local function registerAll()
            local ctx = Housing.Runtime and Housing.Runtime.context
            local seen = {}
            for _, property in ipairs(garagesOf(ctx)) do
                local options = optionsFor(property)
                local propertyId = property.id
                seen[propertyId] = true
                local known = registered[propertyId]
                if known then
                    local ok, success = pcall(function()
                        return env.exports['jg-advancedgarages'].updateGarage(known, options)
                    end)
                    if not ok or success ~= true then
                        registered[propertyId] = nil
                    end
                end
                if not registered[propertyId] then
                    local ok, garageId, err = pcall(function()
                        return env.exports['jg-advancedgarages'].registerGarage(options)
                    end)
                    if ok and type(garageId) == 'string' and garageId ~= '' then
                        registered[propertyId] = garageId
                    elseif not ok or garageId == false then
                        Housing.Util.log('error', ('jg-advancedgarages %s: %s'):format(propertyId, tostring(err or garageId)))
                    end
                end
            end
            for propertyId, garageId in pairs(registered) do
                if not seen[propertyId] then
                    pcall(function()
                        env.exports['jg-advancedgarages'].unregisterGarage(garageId)
                    end)
                    registered[propertyId] = nil
                end
            end
        end
        return {
            name = chosen.id,
            liveVerified = false,
            report = 'jg-advancedgarages registerGarage (not executed in this environment)',
            registerAll = registerAll,
            registerFor = function()
                registerAll()
            end,
            refresh = function(propertyId)
                local garageId = registered[propertyId]
                if not garageId then
                    registerAll()
                    garageId = registered[propertyId]
                end
                if not garageId then
                    return false
                end
                local ok, success = pcall(function()
                    return env.exports['jg-advancedgarages'].refreshGarageAccess(garageId)
                end)
                return ok and success == true
            end,
        }
    end
    if chosen.id == 'qb-garages' then
        return {
            name = chosen.id,
            liveVerified = false,
            report = 'qb-garages location only. That resource checks qb-houses keys, not housing keys.',
            registerAll = function() end,
            registerFor = function(source)
                local ctx = Housing.Runtime and Housing.Runtime.context
                for index, property in ipairs(garagesOf(ctx)) do
                    local garage = property.garage
                    env.triggerClient('qb-garages:client:addHouseGarage', source, property.id, {
                        label = property.label,
                        takeVehicle = {
                            x = garage.x,
                            y = garage.y,
                            z = garage.z,
                            w = garage.w or 0.0,
                            h = garage.w or 0.0,
                        },
                    })
                end
            end,
        }
    end
    return {
        name = chosen.id,
        liveVerified = false,
        report = 'qs-advancedgarages CreateGarage has no housing access callback (not executed in this environment)',
        registerAll = function() end,
        registerFor = function(source)
            local ctx = Housing.Runtime and Housing.Runtime.context
            local payload = {}
            for index, property in ipairs(garagesOf(ctx)) do
                local garage = property.garage
                payload[#payload + 1] = {
                    id = 'housing_' .. property.id,
                    label = property.label,
                    x = garage.x,
                    y = garage.y,
                    z = garage.z,
                    w = garage.w or 0.0,
                }
            end
            env.triggerClient('advanced_housing:registerQsGarage', source, payload)
        end,
    }
end
