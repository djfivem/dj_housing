Housing = Housing or {}
Housing.Runtime = Housing.Runtime or {}

local booted = false

local function log(message)
    Housing.Util.log('info', message)
end

local function boot()
    math.randomseed(os.time())
    local migrated, migrateErr = Housing.Migrations.apply()
    if not migrated then
        log('database migration failed: ' .. tostring(migrateErr))
        return
    end
    local repo = Housing.MySqlRepository.new()
    local context, report = Housing.Runtime.build(repo)
    local sync = Housing.Services.syncDefinitions(context, Housing.Config.Properties)
    log(('framework=%s inventory=%s ready=%s'):format(report.framework, report.inventory, tostring(report.inventoryReady)))
    if report.frameworkError then
        log('framework blocked: ' .. tostring(report.frameworkError) .. ' ' .. json.encode(report.frameworkExtra or {}))
    end
    if report.inventoryReason then
        log('inventory: ' .. tostring(report.inventoryReason))
    end
    log(('properties inserted=%s updated=%s errors=%s'):format(sync.inserted, sync.updated, #sync.errors))
    for index = 1, #sync.errors do
        log(('property %s invalid: %s'):format(tostring(sync.errors[index].id), tostring(sync.errors[index].error)))
    end
    log('integrations ' .. json.encode(report.integrations))
    if report.inventoryReady and context.inventory.registerStash then
        local properties = repo.listProperties()
        for index = 1, #properties do
            local stashes = repo.listStashes(properties[index].id)
            for stashIndex = 1, #stashes do
                local stash = stashes[stashIndex]
                if stash.stash_type ~= 'personal' then
                    context.inventory.registerStash({
                        id = Housing.Util.stashIdentifier(properties[index].id, stash.stash_key, nil),
                        label = properties[index].label .. ' / ' .. stash.label,
                        slots = stash.slots,
                        maxWeight = stash.max_weight,
                    })
                end
            end
        end
    end
    if context.garages and context.garages.registerAll then
        context.garages.registerAll()
    end
    Housing.Runtime.report = report
end

local function sweep()
    local context = Housing.Runtime.context
    if not context or context.framework.name == 'unconfigured' then
        return
    end
    Housing.Services.expireRentals(context)
    Housing.Services.createBillCycle(context)
    Housing.Services.reconcile(context)
end

if not booted then
    booted = true
    RegisterNetEvent('advanced_housing:request', function(name, requestId, payload)
        local source = source
        if type(requestId) ~= 'string' or #requestId > 64 then
            return
        end
        local result = Housing.Callbacks.dispatch(source, name, payload)
        TriggerClientEvent('advanced_housing:response', source, requestId, result)
    end)

    RegisterNetEvent('advanced_housing:requestGarages', function()
        local source = source
        local context = Housing.Runtime.context
        if context and context.garages and context.garages.registerFor then
            context.garages.registerFor(source)
        end
    end)

    exports('HasGarageAccess', function(source, propertyId)
        return Housing.Garages.hasAccess(source, propertyId)
    end)

    exports('GetPropertyGarages', function()
        return Housing.Garages.list()
    end)

    RegisterNetEvent('advanced_housing:confirmExitFailed', function()
        local source = source
        local context = Housing.Runtime.context
        if not context then return end
        local current = context.instances[source]
        if current and current.bucket and current.bucket > 0 then
            SetPlayerRoutingBucket(source, current.bucket)
        end
    end)

    AddEventHandler('playerDropped', function()
        local source = source
        local context = Housing.Runtime.context
        if context then
            context.clearInstance(source)
        end
    end)

    AddEventHandler('onResourceStop', function(resource)
        if resource ~= GetCurrentResourceName() then return end
        local context = Housing.Runtime.context
        if not context then return end
        for source in pairs(context.instances) do
            context.clearInstance(source)
            TriggerClientEvent('advanced_housing:forceExit', source)
        end
    end)

    AddEventHandler('onResourceStart', function(resource)
        if resource == 'oxmysql' or resource == 'ox_inventory' or resource == 'es_extended' or resource == 'qb-core' or resource == 'qbx_core' or resource == 'qb-inventory' or resource == 'qs-inventory' then
            CreateThread(function()
                Wait(500)
                if GetResourceState('oxmysql') == 'started' then
                    boot()
                end
            end)
        end
    end)

    RegisterCommand(Housing.Config.AdminCommand, function(source, args)
        if source == 0 then
            print(json.encode(Housing.Runtime.report or {}))
            return
        end
        local context = Housing.Runtime.context
        if not context or not context.isAdmin(source) then
            return
        end
        local action = args[1]
        if action == 'diag' then
            TriggerClientEvent('advanced_housing:notify', source, json.encode(Housing.Services.diagnostics(context)), 'inform')
            return
        end
        TriggerClientEvent('advanced_housing:open', source, 'admin')
    end, false)

    CreateThread(function()
        while GetResourceState('oxmysql') ~= 'started' do
            Wait(200)
        end
        boot()
        while true do
            Wait((Housing.Config.Performance.rentalSweepSeconds or 60) * 1000)
            local ok, err = pcall(sweep)
            if not ok then
                Housing.Util.log('error', 'sweep failed: ' .. tostring(err))
            end
        end
    end)
end
