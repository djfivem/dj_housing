local root = arg[0]:match('^(.*)/tests/run%.lua$') or '.'
local function load(path)
    local chunk, err = loadfile(root .. '/' .. path)
    if not chunk then
        error(err)
    end
    chunk()
end

load('shared/init.lua')
load('shared/constants.lua')
load('shared/enums.lua')
load('shared/utilities.lua')
load('shared/validation.lua')
load('shared/locales.lua')
load('config/shared.lua')
load('config/framework.lua')
load('config/inventory.lua')
load('config/permissions.lua')
load('config/performance.lua')
load('config/evidence.lua')
load('config/police.lua')
load('config/shells.lua')
load('config/housing.lua')
load('config/properties.lua')
load('server/repository_memory.lua')
load('server/domain/ratelimit.lua')
load('server/domain/auth.lua')
load('server/domain/money.lua')
load('server/domain/utilities.lua')
load('server/domain/transaction.lua')
load('server/domain/rental.lua')
load('server/domain/keys.lua')
load('server/domain/stash.lua')
load('server/domain/police.lua')
load('server/domain/property_ops.lua')
load('server/domain/reconcile.lua')
load('server/domain/dashboard.lua')
load('server/adapters/framework.lua')
load('server/adapters/inventory.lua')
load('server/adapters/images.lua')
load('server/adapters/banking.lua')
load('server/adapters/garages.lua')
load('server/adapters/integrations.lua')

local passed = 0
local failed = 0
local function check(name, cond)
    if cond then
        passed = passed + 1
        print('PASS ' .. name)
    else
        failed = failed + 1
        print('FAIL ' .. name)
    end
end

local time = 1700000000
local function clock()
    return time
end
local idn = 0
local function ids()
    idn = idn + 1
    return string.format('id-%08d-test', idn)
end
local locks = {}
local instances = {}
local positions = {}
local wallets = {
    [1] = 5000000,
    [2] = 5000000,
    [3] = 1000,
    [4] = 1000,
}
local players = {
    [1] = { source = 1, framework = 'standalone', characterId = 'license:diesel', name = 'Diesel', job = { name = 'unemployed', grade = 0 } },
    [2] = { source = 2, framework = 'standalone', characterId = 'license:other', name = 'Other', job = { name = 'unemployed', grade = 0 } },
    [3] = { source = 3, framework = 'standalone', characterId = 'license:cop', name = 'Cop', job = { name = 'police', grade = 4 } },
    [4] = { source = 4, framework = 'standalone', characterId = 'license:chief', name = 'Chief', job = { name = 'police', grade = 5 } },
}
local carried = {}
local stashes = {}
local inventory = {
    name = 'mock',
    ready = true,
    capabilities = { readStash = true, seizure = true, authoritativeStash = true },
    search = function(source, item)
        local list = {}
        for index = 1, #(carried[source] or {}) do
            local row = carried[source][index]
            if row.name == item then
                list[#list + 1] = row
            end
        end
        return list
    end,
    addItem = function(source, item, count, metadata)
        carried[source] = carried[source] or {}
        carried[source][#carried[source] + 1] = { name = item, count = count, metadata = metadata, slot = #carried[source] + 1 }
        return true
    end,
    removeItem = function(source, item, count, metadata)
        for index = 1, #(carried[source] or {}) do
            local row = carried[source][index]
            if row.name == item and (not metadata or not metadata.keyId or (row.metadata and row.metadata.keyId == metadata.keyId)) then
                table.remove(carried[source], index)
                return true
            end
        end
        return false
    end,
    registerStash = function() return true end,
    openStash = function() return true end,
    getStashContents = function(stashId)
        return stashes[stashId] or {}, true
    end,
    removeStashItem = function(stashId, item, count)
        local list = stashes[stashId] or {}
        for index = 1, #list do
            if list[index].name == item and list[index].count >= count then
                list[index].count = list[index].count - count
                return true
            end
        end
        return false, 'inventory_failed'
    end,
}
local framework = {
    name = 'standalone',
    getPlayer = function(source) return players[source] end,
    getSourceByCharacter = function(_, characterId)
        for source, player in pairs(players) do
            if player.characterId == characterId then return source end
        end
        return nil
    end,
    getMoney = function(source) return wallets[source] or 0 end,
    removeMoney = function(source, _, amount)
        if (wallets[source] or 0) < amount then return false end
        wallets[source] = wallets[source] - amount
        return true
    end,
    addMoney = function(source, _, amount)
        wallets[source] = (wallets[source] or 0) + amount
        return true
    end,
    notify = function() end,
    hasAdmin = function(source) return source == 9 end,
}

local function makeCtx()
    local repo = Housing.MemoryRepository.new(clock)
    local ctx = {
        repo = repo,
        framework = framework,
        inventory = inventory,
        config = {
            account = 'bank',
            permissions = Housing.Config.Permissions,
            housing = Housing.Config.Housing,
            police = Housing.Config.Police,
            evidence = Housing.Config.Evidence,
            shells = Housing.Config.Shells,
            furniture = Housing.Config.Furniture,
            upgrades = Housing.Config.Upgrades,
            performance = Housing.Config.Performance,
            keyItem = Housing.Config.KeyItem,
            images = Housing.Config.Images,
            reservationTimeoutSeconds = 180,
        },
        rateLimiter = Housing.RateLimiter.new({
            purchase = { burst = 100, refillPerSecond = 100 },
            stash = { burst = 100, refillPerSecond = 100 },
            key = { burst = 100, refillPerSecond = 100 },
            raid = { burst = 100, refillPerSecond = 100 },
            admin = { burst = 100, refillPerSecond = 100 },
            ui = { burst = 100, refillPerSecond = 100 },
            default = { burst = 100, refillPerSecond = 100 },
        }, clock),
        now = clock,
        ids = ids,
        randomInt = function(min)
            return min
        end,
        lockCharacter = function(id)
            if locks[id] then return false end
            locks[id] = true
            return true
        end,
        unlockCharacter = function(id) locks[id] = nil end,
        playerKey = function(source) return tostring(source) end,
        position = function(source) return positions[source] end,
        instance = function(source) return instances[source] end,
        isAdmin = function(source) return source == 9 end,
        vehicle = function() return { plate = 'HOUSE1', modelHash = 123 } end,
        hooks = nil,
    }
    local report = Housing.Services.syncDefinitions(ctx, Housing.Config.Properties)
    return ctx, report
end

local ctx, syncReport = makeCtx()
check('definitions load', syncReport.inserted == 4 and #syncReport.errors == 0)
check('zone synced', ctx.repo.getProperty('vinewood_hills_mansion').zone and #ctx.repo.getProperty('vinewood_hills_mansion').zone.points >= 3)
local again = Housing.Services.syncDefinitions(ctx, Housing.Config.Properties)
check('definitions do not duplicate', again.inserted == 0 and again.updated == 4)

local dup = Housing.Util.deepCopy(Housing.Config.Properties)
dup[#dup + 1] = dup[1]
local dupReport = Housing.Services.syncDefinitions(ctx, dup)
check('duplicate property id rejected', dupReport.errors[#dupReport.errors].error == 'duplicate_id')

local bad = { id = 'bad', label = 'Bad', propertyType = 'shell', purchasePrice = -1 }
check('invalid property rejected', select(1, Housing.Validation.propertyDefinition(bad, Housing.Config.Shells)) == false)

local mansion = ctx.repo.getProperty('vinewood_hills_mansion')
positions[1] = mansion.entrance
positions[2] = mansion.entrance
positions[3] = mansion.entrance
positions[4] = mansion.entrance

local before = wallets[1]
local bought = Housing.Services.purchase(ctx, 1, {
    propertyId = 'vinewood_hills_mansion',
    idempotencyKey = 'purchase-key-0001',
    mode = 'purchase',
    expectedPrice = 2500000,
    shellModel = 'shell_michael',
})
check('purchase succeeds', bought.ok == true)
check('purchase debits once', wallets[1] == before - 2500000)
check('owner record exists', ctx.repo.getOwnership('vinewood_hills_mansion').character_id == 'license:diesel')
check('property status owned', ctx.repo.getProperty('vinewood_hills_mansion').status == 'owned')
local replay = Housing.Services.purchase(ctx, 1, {
    propertyId = 'vinewood_hills_mansion',
    idempotencyKey = 'purchase-key-0001',
    mode = 'purchase',
    expectedPrice = 2500000,
})
check('replay does not charge again', replay.ok and replay.data.replay and wallets[1] == before - 2500000)

local mismatch = Housing.Services.purchase(ctx, 2, {
    propertyId = 'sandy_shores_trailer',
    idempotencyKey = 'purchase-key-0002',
    mode = 'purchase',
    expectedPrice = 1,
})
check('client price mismatch rejected', mismatch.ok == false and mismatch.error == 'price_mismatch')
check('mismatch leaves property available', ctx.repo.getProperty('sandy_shores_trailer').status == 'available')

wallets[2] = 10
local poor = Housing.Services.purchase(ctx, 2, {
    propertyId = 'sandy_shores_trailer',
    idempotencyKey = 'purchase-key-0003',
    mode = 'purchase',
    expectedPrice = 180000,
})
check('insufficient funds rejected', poor.error == 'insufficient_funds')
check('insufficient funds leaves property available', ctx.repo.getProperty('sandy_shores_trailer').status == 'available')
wallets[2] = 5000000

local nested = false
ctx.hooks = {
    afterReserve = function()
        nested = true
        local other = Housing.Services.purchase(ctx, 2, {
            propertyId = 'mirror_park_house',
            idempotencyKey = 'purchase-key-0004',
            mode = 'purchase',
            expectedPrice = 650000,
        })
        check('concurrent second buyer loses', other.ok == false)
    end,
}
local first = Housing.Services.purchase(ctx, 1, {
    propertyId = 'mirror_park_house',
    idempotencyKey = 'purchase-key-0005',
    mode = 'purchase',
    expectedPrice = 650000,
})
ctx.hooks = nil
check('concurrent hook ran', nested)
check('first buyer owns mirror park', first.ok and ctx.repo.getOwnership('mirror_park_house').character_id == 'license:diesel')

local shellDenied = Housing.Services.purchase(ctx, 2, {
    propertyId = 'sandy_shores_trailer',
    idempotencyKey = 'purchase-key-0006',
    mode = 'purchase',
    expectedPrice = 180000,
    shellModel = 'shell_michael',
})
check('client shell outside allow list rejected', shellDenied.error == 'shell_not_allowed')

local balance = wallets[1]
ctx.hooks = {
    afterReserve = function()
        ctx.repo.updateProperty('sandy_shores_trailer', { status = 'available', reservation_token = nil })
    end,
}
local compensated = Housing.Services.purchase(ctx, 1, {
    propertyId = 'sandy_shores_trailer',
    idempotencyKey = 'purchase-key-0007',
    mode = 'purchase',
    expectedPrice = 180000,
})
ctx.hooks = nil
check('failed grant is compensated', compensated.ok == false and wallets[1] == balance)

local rented = Housing.Services.rent(ctx, 2, {
    propertyId = 'del_perro_apartment',
    idempotencyKey = 'rent-key-0000001',
    mode = 'rent',
    expectedPrice = 4500,
})
check('rental starts', rented.ok == true)
time = rented.data.expiresAt + 10
local expiredCount = Housing.Services.expireRentals(ctx)
check('rental expires', expiredCount == 1 and ctx.repo.getProperty('del_perro_apartment').status == 'available')
time = 1700000000

local forged = Housing.Auth.holdsKey(ctx, players[2], 'vinewood_hills_mansion', 'guest')
check('stranger without key is denied', forged == false)
inventory.addItem(2, 'housing_key', 1, { keyId = 'forged-key', propertyId = 'vinewood_hills_mansion' })
check('forged key metadata rejected', Housing.Auth.holdsKey(ctx, players[2], 'vinewood_hills_mansion', 'guest') == false)
local issued = Housing.Services.issueKey(ctx, 1, {
    propertyId = 'vinewood_hills_mansion',
    idempotencyKey = 'key-issue-000001',
    accessLevel = 'guest',
    targetSource = 2,
})
check('guest key issued', issued.ok == true)
check('valid key grants guest access', Housing.Auth.holdsKey(ctx, players[2], 'vinewood_hills_mansion', 'guest') == true)
check('mansion key does not open trailer', Housing.Auth.holdsKey(ctx, players[2], 'sandy_shores_trailer', 'guest') == false)
local revoked = Housing.Services.revokeKey(ctx, 1, { keyId = issued.data.keyId })
check('revoked key stops access', revoked.ok and Housing.Auth.holdsKey(ctx, players[2], 'vinewood_hills_mansion', 'guest') == false)

local stashDenied = Housing.Services.openStash(ctx, 2, { propertyId = 'vinewood_hills_mansion', stashKey = 'shared' })
check('unauthorised stash rejected', stashDenied.error == 'stash_forbidden' or stashDenied.error == 'proximity_failed' or stashDenied.error == 'not_authorised')
instances[1] = 'vinewood_hills_mansion'
local stashOk = Housing.Services.openStash(ctx, 1, { propertyId = 'vinewood_hills_mansion', stashKey = 'shared' })
check('owner stash opens', stashOk.ok == true)
local cross = Housing.Services.openStash(ctx, 1, { propertyId = 'vinewood_hills_mansion', stashKey = 'not_a_stash' })
check('unknown stash rejected', cross.error == 'stash_not_found')
local otherStash = Housing.Services.openStash(ctx, 1, { propertyId = 'del_perro_apartment', stashKey = 'shared' })
check('cross property stash rejected', otherStash.ok == false)

local warrant = Housing.Services.requestWarrant(ctx, 3, {
    idempotencyKey = 'warrant-00000001',
    propertyId = 'vinewood_hills_mansion',
    reason = 'Stolen goods reported inside the mansion.',
    caseReference = 'CASE-14',
    durationHours = 12,
    scope = { all = true },
    allowSeizure = true,
})
check('officer can request warrant', warrant.ok == true)
local selfApproved = Housing.Services.decideWarrant(ctx, 3, { warrantId = 'warrant-00000001', decision = 'authorise' })
check('self approval rejected', selfApproved.error == 'self_approval')
local approved = Housing.Services.decideWarrant(ctx, 4, { warrantId = 'warrant-00000001', decision = 'authorise' })
check('different officer can authorise', approved.ok == true)
local civilian = Housing.Services.openRaid(ctx, 1, {
    propertyId = 'vinewood_hills_mansion',
    idempotencyKey = 'raid-key-0000001',
    warrantId = 'warrant-00000001',
    officerSources = { 3 },
})
check('civilian cannot open raid', civilian.error == 'not_authorised')
local raid = Housing.Services.openRaid(ctx, 3, {
    propertyId = 'vinewood_hills_mansion',
    idempotencyKey = 'raid-key-0000002',
    warrantId = 'warrant-00000001',
    officerSources = { 4 },
})
check('raid requested', raid.ok == true)
local authorisedRaid = Housing.Services.setRaidState(ctx, 4, { raidId = raid.data.raidId, state = 'authorised' })
check('raid authorised', authorisedRaid.ok == true)
local active = Housing.Services.setRaidState(ctx, 3, { raidId = raid.data.raidId, state = 'active' })
check('raid becomes active', active.ok == true)
local sharedId = Housing.Util.stashIdentifier('vinewood_hills_mansion', 'shared', nil)
stashes[sharedId] = { { name = 'goldbar', label = 'Gold', count = 2, slot = 1 } }
local inspected = Housing.Services.inspectStash(ctx, 3, { propertyId = 'vinewood_hills_mansion', stashKey = 'shared' })
check('inspection returns stash contents', inspected.ok and inspected.data.items[1].name == 'goldbar')
local unrelated = Housing.Services.inspectStash(ctx, 3, { propertyId = 'del_perro_apartment', stashKey = 'shared' })
check('unrelated property search rejected', unrelated.ok == false)
local seized = Housing.Services.seizeItem(ctx, 3, {
    idempotencyKey = 'seize-key-000001',
    propertyId = 'vinewood_hills_mansion',
    stashKey = 'shared',
    raidId = raid.data.raidId,
    itemName = 'goldbar',
    quantity = 1,
})
check('seizure records evidence', seized.ok and seized.data.status == 'seized')
check('seizure removed one item', stashes[sharedId][1].count == 1)
local seizedAgain = Housing.Services.seizeItem(ctx, 3, {
    idempotencyKey = 'seize-key-000001',
    propertyId = 'vinewood_hills_mansion',
    stashKey = 'shared',
    raidId = raid.data.raidId,
    itemName = 'goldbar',
    quantity = 1,
})
check('seizure retry does not remove twice', seizedAgain.data.replay == true and stashes[sharedId][1].count == 1)

local evidence = ctx.repo.getEvidence('seize-key-000001')
check('evidence persisted', evidence and evidence.status == 'seized')

local env = {
    getResourceState = function(name)
        return (name == 'qb-core' or name == 'qbx_core') and 'started' or 'missing'
    end,
}
local mode, err = Housing.Frameworks.detect(Housing.Config, env)
check('ambiguous frameworks are rejected', mode == nil and err == 'ambiguous_framework')
local alone = { getResourceState = function(name) return name == 'es_extended' and 'started' or 'missing' end }
check('single esx framework detected', Housing.Frameworks.detect(Housing.Config, alone) == 'esx')
local none = { getResourceState = function() return 'missing' end }
check('no framework falls back to standalone', Housing.Frameworks.detect(Housing.Config, none) == 'standalone')
local explicit = { Framework = 'qbox', Frameworks = Housing.Config.Frameworks, Permissions = Housing.Config.Permissions }
check('explicit framework is honoured', Housing.Frameworks.detect(explicit, env) == 'qbox')

local repo = Housing.MemoryRepository.new(clock)
local standalone = Housing.Frameworks.standalone(Housing.Config, {
    getPlayerIdentifierByType = function(source) return source == 1 and 'license:diesel' or nil end,
    getPlayerName = function() return 'Diesel' end,
    isAceAllowed = function() return false end,
    triggerClient = function() end,
}, repo)
check('standalone player resolves', standalone.getPlayer(1).characterId == 'license:diesel')
check('standalone is not admin by default', standalone.hasAdmin(1) == false)
check('standalone refuses overdraft', standalone.removeMoney(1, 'bank', 50, 'test') == false)
standalone.addMoney(1, 'bank', 100, 'test')
check('standalone ledger persists', standalone.getMoney(1, 'bank') == 100 and standalone.removeMoney(1, 'bank', 40, 'test') == true)

local invEnv = { getResourceState = function(name)
    if name == 'ox_inventory' or name == 'qb-inventory' then return 'started' end
    return 'missing'
end }
local selected, invErr = Housing.Inventories.detect(Housing.Config, invEnv)
check('ambiguous inventories are rejected', selected == nil and invErr == 'ambiguous_inventory')

local limited = Housing.RateLimiter.new({ default = { burst = 1, refillPerSecond = 0 } }, function() return 100 end)
check('rate limit allows first', limited.allow('a', 'default') == true)
check('rate limit blocks second', limited.allow('a', 'default') == false)

check('raid transition guard', Housing.CanTransitionRaid('requested', 'active') == false)
check('raid authorise transition', Housing.CanTransitionRaid('requested', 'authorised') == true)
check('bucket stable', Housing.Util.bucketFor('vinewood_hills_mansion') == Housing.Util.bucketFor('vinewood_hills_mansion'))
check('bucket not zero', Housing.Util.bucketFor('vinewood_hills_mansion') > 0)

check('zone needs three points', select(1, Housing.Validation.zone({ points = { { x = 0, y = 0 }, { x = 1, y = 1 } } })) == false)
local badZone = Housing.Util.deepCopy(Housing.Config.Properties[1])
badZone.id = 'bad_zone_house'
badZone.zone = { points = { { x = 1, y = 1 } } }
local zoneReport = Housing.Services.syncDefinitions(ctx, { badZone })
check('short zone rejected', zoneReport.errors[1] and zoneReport.errors[1].error == 'zone')
check('image host rejected', select(1, Housing.Validation.imageUrl('https://evil.example/house.jpg', Housing.Config.Images.allowedHosts)) == false)
check('image host accepted', select(1, Housing.Validation.imageUrl('https://r2.fivemanage.com/images/house.jpg', Housing.Config.Images.allowedHosts)) == true)
local savedImage = Housing.Services.setPropertyImage(ctx, 1, {
    propertyId = 'vinewood_hills_mansion',
    imageUrl = 'https://r2.fivemanage.com/images/house.jpg',
})
check('owner can save a house image', savedImage.ok == true)
local strangerImage = Housing.Services.setPropertyImage(ctx, 2, {
    propertyId = 'vinewood_hills_mansion',
    imageUrl = 'https://r2.fivemanage.com/images/other.jpg',
})
check('stranger cannot set a house image', strangerImage.ok == false and strangerImage.error == 'not_authorised')
Housing.Services.syncDefinitions(ctx, Housing.Config.Properties)
check('sync keeps a player image', ctx.repo.getProperty('vinewood_hills_mansion').image_url == 'https://r2.fivemanage.com/images/house.jpg')

local utilityBills = {}
for _, bill in ipairs(ctx.repo.listBills('vinewood_hills_mansion')) do
    utilityBills[bill.bill_type] = bill.amount
end
check('weekly utility bills use the rolled minimum', utilityBills.water == 75 and utilityBills.electricity == 90 and utilityBills.garbage == 40)
local beforeUtilityCount = #ctx.repo.listBills('vinewood_hills_mansion')
local duplicateUtilities = Housing.Utilities.issueProperty(ctx, { id = 'vinewood_hills_mansion' })
check('the same week is not billed twice', duplicateUtilities == 0 and #ctx.repo.listBills('vinewood_hills_mansion') == beforeUtilityCount)

local frozen = 1700000000
local sequence = { 111, 142, 88, 201, 233, 77 }
local cursor = 0
local utilityCtx = {
    repo = Housing.MemoryRepository.new(function() return frozen end),
    config = { housing = Housing.Config.Housing },
    now = function() return frozen end,
    ids = ids,
    randomInt = function()
        cursor = cursor + 1
        return sequence[cursor]
    end,
}
local rates, week = Housing.Utilities.current(utilityCtx)
check('utility week id', week == math.floor(1700000000 / (168 * 3600)))
check('rates roll in sorted type order', rates.electricity == 111 and rates.garbage == 142 and rates.water == 88)
local stable = Housing.Utilities.current(utilityCtx)
check('the same week keeps its rates', stable.electricity == 111 and stable.garbage == 142 and stable.water == 88 and cursor == 3)
frozen = frozen + (168 * 3600)
local nextRates = Housing.Utilities.current(utilityCtx)
check('the next week rolls new rates', nextRates.electricity == 201 and nextRates.garbage == 233 and nextRates.water == 77 and cursor == 6)

local presigned = Housing.Images.presign({
    config = { images = Housing.Config.Images },
    env = {
        getConvar = function() return 'server-key' end,
        http = function(_, _, headers)
            if headers.Authorization ~= 'server-key' then return 401, '' end
            return 200, '{"data":{"presignedUrl":"https://fmapi.net/api/presigned/abc"}}'
        end,
    },
})
check('fivemanage presign stays on the server', presigned == 'https://fmapi.net/api/presigned/abc')
local missingKey = Housing.Images.presign({
    config = { images = Housing.Config.Images },
    env = { getConvar = function() return '' end, http = function() return 200, '{}' end },
})
check('presign refuses a missing key', missingKey == nil)

local statements = {}
local banking = Housing.Banking.bind({
    Account = 'bank',
    Integrations = { banking = { system = 'qb-banking' } },
}, {
    getResourceState = function(name) return name == 'qb-banking' and 'started' or 'missing' end,
    exports = {
        ['qb-banking'] = {
            CreateBankStatement = function(source, account, amount, _, kind, accountType)
                statements[#statements + 1] = { source = source, account = account, amount = amount, kind = kind, accountType = accountType }
                return true
            end,
        },
    },
})
banking.record(7, { characterId = 'cid', name = 'Diesel' }, { label = 'Water', amount = 100, bill_type = 'water' })
check('banking writes a statement', statements[1] and statements[1].source == 7 and statements[1].amount == 100 and statements[1].kind == 'withdraw' and statements[1].accountType == 'player')

local registered = {}
Housing.Runtime = Housing.Runtime or {}
Housing.Runtime.context = ctx
local garageAdapter = Housing.Garages.bind({
    Integrations = { garage = { system = 'jg-advancedgarages' } },
}, {
    getResourceState = function(name) return name == 'jg-advancedgarages' and 'started' or 'missing' end,
    exports = {
        ['jg-advancedgarages'] = {
            registerGarage = function(payload)
                registered[#registered + 1] = payload
            end,
        },
    },
})
garageAdapter.registerAll()
local ownerGarage = false
for index = 1, #registered do
    if registered[index].id == 'housing_vinewood_hills_mansion' and registered[index].access(1) == true then
        ownerGarage = type(registered[index].coords) == 'table'
    end
end
check('jg garage uses housing access', #registered == 4 and ownerGarage)
local keyGarage = Housing.Garages.bind({
    Integrations = { garage = { system = 'cd_garage' } },
}, { getResourceState = function() return 'started' end })
check('cd_garage is not treated as a house registrar', keyGarage.name == 'builtin')

local dispatched = {}
local dispatchAdapter = Housing.Integrations.bind(Housing.Config, {
    getResourceState = function(name) return name == 'cd_dispatch' and 'started' or 'missing' end,
    triggerClient = function(_, _, payload, system)
        dispatched[#dispatched + 1] = { system = system, jobs = payload.jobs }
    end,
    triggerEvent = function() end,
    exports = {},
})
dispatchAdapter.dispatch({ message = 'Raid', coords = { x = 1, y = 2, z = 3 }, propertyId = 'vinewood_hills_mansion' })
check('one dispatch system is selected', dispatched[1] and dispatched[1].system == 'cd_dispatch' and dispatched[1].jobs[1] == 'police')

local origenEnv = { getResourceState = function(name) return name == 'origen_inventory' and 'started' or 'missing' end }
check('origen inventory detected', Housing.Inventories.detect(Housing.Config, origenEnv) == 'origen_inventory')
local codemEnv = { getResourceState = function(name) return name == 'codem-inventory' and 'started' or 'missing' end }
check('codem inventory detected', Housing.Inventories.detect(Housing.Config, codemEnv) == 'codem_inventory')

print(string.format('RESULT %d passed, %d failed', passed, failed))
if failed > 0 then
    os.exit(1)
end
