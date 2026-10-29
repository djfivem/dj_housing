Housing = Housing or {}
Housing.Inventories = Housing.Inventories or {}

local Inventories = Housing.Inventories

function Inventories.detect(config, env)
    local mode = config.Inventory or 'auto'
    local supported = {
        { id = 'ox_inventory', resource = 'ox_inventory' },
        { id = 'qs_inventory', resource = 'qs-inventory' },
        { id = 'ps_inventory', resource = 'ps-inventory' },
        { id = 'lj_inventory', resource = 'lj-inventory' },
        { id = 'qb_inventory', resource = 'qb-inventory' },
        { id = 'origen_inventory', resource = 'origen_inventory' },
        { id = 'codem_inventory', resource = 'codem-inventory' },
    }
    if mode == 'none' or mode == 'custom' then
        return mode
    end
    if mode ~= 'auto' then
        for index = 1, #supported do
            if supported[index].id == mode then
                return mode
            end
        end
        return nil, 'unknown_inventory'
    end
    local found = {}
    for index = 1, #supported do
        if env.getResourceState(supported[index].resource) == 'started' then
            found[#found + 1] = supported[index].id
        end
    end
    if #found > 1 then
        return nil, 'ambiguous_inventory', found
    end
    if #found == 1 then
        return found[1]
    end
    return 'none'
end

local function unavailable(name, reason)
    return {
        name = name,
        liveVerified = false,
        ready = false,
        reason = reason,
        capabilities = { metadata = false, readStash = false, seizure = false, authoritativeStash = false },
        search = function() return {} end,
        addItem = function() return false, 'inventory_unavailable' end,
        removeItem = function() return false, 'inventory_unavailable' end,
        registerStash = function() return false, 'inventory_unavailable' end,
        openStash = function() return false, 'inventory_unavailable' end,
        getStashContents = function() return nil, false end,
        removeStashItem = function() return false, 'unsupported' end,
    }
end

local function slotsFrom(list)
    local items = {}
    if type(list) ~= 'table' then
        return items
    end
    for _, slot in pairs(list) do
        if type(slot) == 'table' and slot.name then
            items[#items + 1] = {
                slot = slot.slot,
                count = slot.count or slot.amount or 1,
                metadata = slot.metadata or slot.info,
                name = slot.name,
                label = slot.label,
            }
        end
    end
    return items
end

function Inventories.ox(config, env)
    if env.getResourceState('ox_inventory') ~= 'started' then
        return unavailable('ox_inventory', 'ox_inventory is not started')
    end
    local adapter = unavailable('ox_inventory')
    adapter.ready = true
    adapter.reason = nil
    adapter.liveVerified = false
    adapter.capabilities = {
        metadata = true,
        uniqueItems = true,
        readStash = true,
        seizure = true,
        authoritativeStash = true,
        runtimeItemRegistration = false,
    }
    function adapter.search(source, item)
        local ok, slots = pcall(function()
            return env.exports.ox_inventory:Search(source, 'slots', item)
        end)
        if not ok then return {} end
        return slotsFrom(slots)
    end
    function adapter.addItem(source, item, count, metadata)
        local ok, success, response = pcall(function()
            return env.exports.ox_inventory:AddItem(source, item, count, metadata)
        end)
        if not ok then return nil, 'uncertain' end
        if success == true or type(success) == 'table' then
            return true, response
        end
        return false, response or success
    end
    function adapter.removeItem(source, item, count, metadata)
        local ok, success = pcall(function()
            return env.exports.ox_inventory:RemoveItem(source, item, count, metadata)
        end)
        if not ok then return nil, 'uncertain' end
        return success == true
    end
    function adapter.registerStash(stash)
        local ok, err = pcall(function()
            env.exports.ox_inventory:RegisterStash(stash.id, stash.label, stash.slots, stash.maxWeight, false)
        end)
        if not ok then return false, err end
        return true
    end
    function adapter.openStash(source, stashId)
        local ok, err = pcall(function()
            env.exports.ox_inventory:forceOpenInventory(source, 'stash', stashId)
        end)
        if not ok then return false, 'inventory_failed' end
        return true
    end
    function adapter.getStashContents(stashId)
        local ok, items = pcall(function()
            env.exports.ox_inventory:GetInventory(stashId, false)
            return env.exports.ox_inventory:GetInventoryItems(stashId, false)
        end)
        if not ok then return nil, false end
        return slotsFrom(items), true
    end
    function adapter.removeStashItem(stashId, item, count, slot)
        local ok, success = pcall(function()
            return env.exports.ox_inventory:RemoveItem(stashId, item, count, nil, slot)
        end)
        if not ok then return nil, 'uncertain' end
        if success == true then return true end
        return false, 'inventory_failed'
    end
    return adapter
end

function Inventories.qb(config, env)
    if env.getResourceState('qb-inventory') ~= 'started' then
        return unavailable('qb_inventory', 'qb-inventory is not started')
    end
    local adapter = unavailable('qb_inventory')
    adapter.ready = true
    adapter.reason = nil
    adapter.liveVerified = false
    adapter.capabilities = {
        metadata = true,
        uniqueItems = true,
        readStash = true,
        seizure = true,
        authoritativeStash = true,
        runtimeItemRegistration = false,
        minimum = 'qb-inventory rewrite with CreateInventory/GetInventory (2024-11 or newer)',
    }
    function adapter.search(source, item)
        local ok, items = pcall(function()
            return env.exports['qb-inventory']:GetItemsByName(source, item)
        end)
        if not ok then return {} end
        return slotsFrom(items)
    end
    function adapter.addItem(source, item, count, metadata)
        local ok, success = pcall(function()
            return env.exports['qb-inventory']:AddItem(source, item, count, false, metadata or false, 'advanced_housing')
        end)
        if not ok then return nil, 'uncertain' end
        return success == true
    end
    function adapter.removeItem(source, item, count, metadata)
        local ok, success = pcall(function()
            return env.exports['qb-inventory']:RemoveItem(source, item, count, false, 'advanced_housing')
        end)
        if not ok then return nil, 'uncertain' end
        return success == true
    end
    function adapter.registerStash(stash)
        local ok = pcall(function()
            env.exports['qb-inventory']:CreateInventory(stash.id, {
                label = stash.label,
                maxweight = stash.maxWeight,
                slots = stash.slots,
            })
        end)
        return ok == true
    end
    function adapter.openStash(source, stashId, opts)
        local ok = pcall(function()
            env.exports['qb-inventory']:OpenInventory(source, stashId, {
                label = opts.label,
                maxweight = opts.maxWeight,
                slots = opts.slots,
            })
        end)
        if not ok then return false, 'inventory_failed' end
        return true
    end
    function adapter.getStashContents(stashId)
        local ok, inventory = pcall(function()
            return env.exports['qb-inventory']:GetInventory(stashId)
        end)
        if not ok or type(inventory) ~= 'table' then
            return nil, false
        end
        return slotsFrom(inventory.items or inventory), true
    end
    function adapter.removeStashItem(stashId, item, count, slot)
        local ok, success = pcall(function()
            return env.exports['qb-inventory']:RemoveItem(stashId, item, count, slot or false, 'advanced_housing_seizure')
        end)
        if not ok then return nil, 'uncertain' end
        if success == true then return true end
        return false, 'inventory_failed'
    end
    return adapter
end

local function legacy(name, resource, config, env)
    if env.getResourceState(resource) ~= 'started' then
        return unavailable(name, resource .. ' is not started')
    end
    local adapter = unavailable(name)
    adapter.ready = true
    adapter.reason = nil
    adapter.liveVerified = false
    adapter.capabilities = {
        metadata = true,
        uniqueItems = true,
        readStash = false,
        seizure = false,
        authoritativeStash = false,
        runtimeItemRegistration = false,
        note = 'Stash open is not server-authoritative in this inventory. Enable Config.LegacyStashOpen only if you accept that.',
    }
    function adapter.search(source, item)
        local ok, items = pcall(function()
            return env.exports[resource]:GetItemsByName(source, item)
        end)
        if not ok then return {} end
        return slotsFrom(items)
    end
    function adapter.addItem(source, item, count, metadata)
        local ok, success = pcall(function()
            return env.exports[resource]:AddItem(source, item, count, false, metadata)
        end)
        if not ok then return nil, 'uncertain' end
        return success == true
    end
    function adapter.removeItem(source, item, count)
        local ok, success = pcall(function()
            return env.exports[resource]:RemoveItem(source, item, count)
        end)
        if not ok then return nil, 'uncertain' end
        return success == true
    end
    function adapter.registerStash()
        return false, 'stash_not_authoritative'
    end
    function adapter.openStash(source, stashId, opts)
        if config.LegacyStashOpen ~= true then
            return false, 'stash_not_authoritative'
        end
        env.triggerClient('advanced_housing:legacyStash', source, stashId, opts, resource)
        return true
    end
    function adapter.getStashContents()
        return nil, false
    end
    function adapter.removeStashItem()
        return false, 'unsupported'
    end
    return adapter
end

function Inventories.lj(config, env)
    return legacy('lj_inventory', 'lj-inventory', config, env)
end

function Inventories.ps(config, env)
    return legacy('ps_inventory', 'ps-inventory', config, env)
end

function Inventories.origen(config, env)
    return legacy('origen_inventory', 'origen_inventory', config, env)
end

function Inventories.codem(config, env)
    return legacy('codem_inventory', 'codem-inventory', config, env)
end

function Inventories.qs(config, env)
    if env.getResourceState('qs-inventory') ~= 'started' then
        return unavailable('qs_inventory', 'qs-inventory is not started')
    end
    local adapter = unavailable('qs_inventory')
    adapter.ready = true
    adapter.reason = nil
    adapter.liveVerified = false
    adapter.capabilities = {
        metadata = true,
        uniqueItems = true,
        readStash = true,
        seizure = true,
        authoritativeStash = true,
        stashIdPrefix = 'Stash_',
        runtimeItemRegistration = false,
    }
    local function stashName(id)
        if id:sub(1, 6) == 'Stash_' then return id end
        return 'Stash_' .. id
    end
    function adapter.search(source, item)
        local ok, items = pcall(function()
            return env.exports['qs-inventory']:GetItemsByName(source, item)
        end)
        if not ok then return {} end
        return slotsFrom(items)
    end
    function adapter.addItem(source, item, count, metadata)
        local ok, success = pcall(function()
            return env.exports['qs-inventory']:AddItem(source, item, count, nil, metadata)
        end)
        if not ok then return nil, 'uncertain' end
        return success == true
    end
    function adapter.removeItem(source, item, count, metadata)
        local ok, success = pcall(function()
            return env.exports['qs-inventory']:RemoveItem(source, item, count, nil, metadata)
        end)
        if not ok then return nil, 'uncertain' end
        return success == true
    end
    function adapter.registerStash(stash)
        return true
    end
    function adapter.openStash(source, stashId, opts)
        local ok = pcall(function()
            env.exports['qs-inventory']:RegisterStash(source, stashId, opts.slots, opts.maxWeight, opts.label)
        end)
        if not ok then return false, 'inventory_failed' end
        return true
    end
    function adapter.getStashContents(stashId)
        local ok, items = pcall(function()
            return env.exports['qs-inventory']:GetStashItems(stashName(stashId))
        end)
        if not ok then return nil, false end
        return slotsFrom(items), true
    end
    function adapter.removeStashItem(stashId, item, count)
        local ok, success = pcall(function()
            return env.exports['qs-inventory']:RemoveItemIntoStash(stashName(stashId), item, count)
        end)
        if not ok then return nil, 'uncertain' end
        if success == false or success == nil then
            return false, 'inventory_failed'
        end
        return true
    end
    return adapter
end

function Inventories.custom(config, env)
    local custom = config.CustomInventory or {}
    if type(custom.resource) ~= 'string' or custom.resource == '' then
        return unavailable('custom', 'Config.CustomInventory.resource is not set')
    end
    if env.getResourceState(custom.resource) ~= 'started' then
        return unavailable('custom', custom.resource .. ' is not started')
    end
    local exportsConfig = custom.exports or {}
    local adapter = unavailable('custom')
    adapter.ready = true
    adapter.reason = nil
    adapter.liveVerified = false
    adapter.capabilities = {
        metadata = exportsConfig.addItem ~= nil,
        readStash = exportsConfig.getStashItems ~= nil,
        seizure = exportsConfig.removeStashItem ~= nil,
        authoritativeStash = exportsConfig.openStash ~= nil and exportsConfig.registerStash ~= nil,
        runtimeItemRegistration = false,
    }
    local function invoke(exportName, ...)
        local args = { ... }
        return env.exports[custom.resource][exportName](table.unpack(args))
    end
    function adapter.search(source, item)
        if not exportsConfig.getItemsByName then return {} end
        local ok, items = pcall(invoke, exportsConfig.getItemsByName, source, item)
        if not ok then return {} end
        return slotsFrom(items)
    end
    function adapter.addItem(source, item, count, metadata)
        if not exportsConfig.addItem then return false, 'inventory_unavailable' end
        local ok, success = pcall(invoke, exportsConfig.addItem, source, item, count, metadata)
        if not ok then return nil, 'uncertain' end
        return success == true
    end
    function adapter.removeItem(source, item, count, metadata)
        if not exportsConfig.removeItem then return false, 'inventory_unavailable' end
        local ok, success = pcall(invoke, exportsConfig.removeItem, source, item, count, metadata)
        if not ok then return nil, 'uncertain' end
        return success == true
    end
    function adapter.registerStash(stash)
        if not exportsConfig.registerStash then return false, 'stash_not_authoritative' end
        local ok = pcall(invoke, exportsConfig.registerStash, stash.id, stash.label, stash.slots, stash.maxWeight, stash.owner)
        return ok == true
    end
    function adapter.openStash(source, stashId, opts)
        if not exportsConfig.openStash then return false, 'stash_not_authoritative' end
        local ok = pcall(invoke, exportsConfig.openStash, source, stashId, opts.slots, opts.maxWeight, opts.label)
        if not ok then return false, 'inventory_failed' end
        return true
    end
    function adapter.getStashContents(stashId)
        if not exportsConfig.getStashItems then return nil, false end
        local ok, items = pcall(invoke, exportsConfig.getStashItems, stashId)
        if not ok then return nil, false end
        return slotsFrom(items), true
    end
    function adapter.removeStashItem(stashId, item, count, slot)
        if not exportsConfig.removeStashItem then return false, 'unsupported' end
        local ok, success = pcall(invoke, exportsConfig.removeStashItem, stashId, item, count, slot)
        if not ok then return nil, 'uncertain' end
        return success == true
    end
    return adapter
end

function Inventories.create(config, env)
    local mode, err, extra = Inventories.detect(config, env)
    if not mode then
        return nil, err, extra
    end
    if mode == 'none' then
        return unavailable('none', 'no inventory selected')
    end
    if mode == 'ox_inventory' then return Inventories.ox(config, env) end
    if mode == 'qb_inventory' then return Inventories.qb(config, env) end
    if mode == 'lj_inventory' then return Inventories.lj(config, env) end
    if mode == 'ps_inventory' then return Inventories.ps(config, env) end
    if mode == 'qs_inventory' then return Inventories.qs(config, env) end
    if mode == 'origen_inventory' then return Inventories.origen(config, env) end
    if mode == 'codem_inventory' then return Inventories.codem(config, env) end
    if mode == 'custom' then return Inventories.custom(config, env) end
    return nil, 'unknown_inventory'
end
