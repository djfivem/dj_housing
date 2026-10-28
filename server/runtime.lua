Housing = Housing or {}

local function liveEnv()
    return {
        getResourceState = GetResourceState,
        exports = exports,
        isAceAllowed = IsPlayerAceAllowed,
        getPlayerIdentifierByType = GetPlayerIdentifierByType,
        getPlayerName = GetPlayerName,
        triggerClient = TriggerClientEvent,
        triggerEvent = TriggerEvent,
        findSourceByIdentifier = function(identifier)
            local players = GetPlayers()
            for index = 1, #players do
                local source = tonumber(players[index])
                if source and GetPlayerIdentifierByType(source, 'license') == identifier then
                    return source
                end
            end
            return nil
        end,
    }
end

function Housing.Runtime.build(repo)
    local env = liveEnv()
    local framework, frameworkErr, frameworkExtra = Housing.Frameworks.create(Housing.Config, env, repo)
    local inventory, inventoryErr, inventoryExtra = Housing.Inventories.create(Housing.Config, env)
    local integrations = Housing.Integrations.bind(Housing.Config, env)
    local locks = {}
    local instances = {}
    local ids = {}
    local sequence = 0
    local function nextId()
        sequence = sequence + 1
        return Housing.Util.uuid(math.random) .. string.format('%04x', sequence % 65535)
    end
    if not framework then
        framework = {
            name = 'unconfigured',
            getPlayer = function() return nil end,
            getSourceByCharacter = function() return nil end,
            getMoney = function() return 0 end,
            removeMoney = function() return false end,
            addMoney = function() return false end,
            notify = function() end,
            hasAdmin = function() return false end,
            reason = frameworkErr,
            extra = frameworkExtra,
        }
    end
    if not inventory then
        inventory = {
            name = 'unconfigured',
            ready = false,
            reason = inventoryErr,
            extra = inventoryExtra,
            search = function() return {} end,
            addItem = function() return false, 'inventory_unavailable' end,
            removeItem = function() return false, 'inventory_unavailable' end,
            registerStash = function() return false, 'inventory_unavailable' end,
            openStash = function() return false, 'inventory_unavailable' end,
            getStashContents = function() return nil, false end,
            removeStashItem = function() return false, 'unsupported' end,
        }
    end
    local ctx = {
        repo = repo,
        framework = framework,
        inventory = inventory,
        config = {
            account = Housing.Config.Account,
            permissions = Housing.Config.Permissions,
            housing = Housing.Config.Housing,
            police = Housing.Config.Police,
            evidence = Housing.Config.Evidence,
            shells = Housing.Config.Shells,
            furniture = Housing.Config.Furniture,
            upgrades = Housing.Config.Upgrades,
            performance = Housing.Config.Performance,
            keyItem = Housing.Config.KeyItem,
            reservationTimeoutSeconds = Housing.Config.Performance.reservationTimeoutSeconds,
        },
        rateLimiter = Housing.RateLimiter.new(Housing.Config.RateLimits, os.time),
        now = os.time,
        ids = nextId,
        lockCharacter = function(id)
            if locks[id] then return false end
            locks[id] = true
            return true
        end,
        unlockCharacter = function(id)
            locks[id] = nil
        end,
        playerKey = function(source)
            local player = framework.getPlayer(source)
            return player and (player.framework .. ':' .. player.characterId) or ('src:' .. tostring(source))
        end,
        position = function(source)
            local ped = GetPlayerPed(source)
            if not ped or ped == 0 then return nil end
            local coords = GetEntityCoords(ped)
            return { x = coords.x, y = coords.y, z = coords.z }
        end,
        instance = function(source)
            return instances[source] and instances[source].propertyId or nil
        end,
        vehicle = function(source)
            local ped = GetPlayerPed(source)
            if not ped or ped == 0 then return nil end
            local vehicle = GetVehiclePedIsIn(ped, false)
            if not vehicle or vehicle == 0 then return nil end
            return {
                plate = (GetVehicleNumberPlateText(vehicle) or ''):gsub('%s+$', ''),
                modelHash = GetEntityModel(vehicle),
                entity = vehicle,
            }
        end,
        isAdmin = function(source)
            return framework.hasAdmin(source)
        end,
        hasPoliceAce = function(source)
            return IsPlayerAceAllowed(source, Housing.Config.Permissions.policeAce)
        end,
        doorlock = integrations.doorlock,
        dispatch = integrations.dispatch,
        evidenceExternal = integrations.evidenceExternal,
        instances = instances,
        integrations = integrations.report,
    }
    function ctx.setInstance(source, data, returnCoords)
        if data.bucket and data.bucket > 0 then
            SetPlayerRoutingBucket(source, data.bucket)
            SetRoutingBucketPopulationEnabled(data.bucket, false)
        end
        instances[source] = {
            propertyId = data.propertyId,
            bucket = data.bucket or 0,
            returnCoords = returnCoords,
        }
    end
    function ctx.clearInstance(source)
        local current = instances[source]
        if current and current.bucket and current.bucket > 0 then
            SetPlayerRoutingBucket(source, 0)
        end
        instances[source] = nil
        return current
    end
    Housing.Runtime.context = ctx
    Housing.Runtime.ids = ids
    return ctx, {
        framework = framework.name,
        frameworkError = framework.reason,
        frameworkExtra = framework.extra,
        inventory = inventory.name,
        inventoryReady = inventory.ready ~= false,
        inventoryReason = inventory.reason,
        inventoryExtra = inventory.extra,
        capabilities = inventory.capabilities,
        integrations = integrations.report,
    }
end
