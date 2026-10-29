Housing = Housing or {}
Housing.MemoryRepository = Housing.MemoryRepository or {}

local Util = Housing.Util

local function clone(value)
    return Util.deepCopy(value)
end

local function assign(row, fields)
    if not fields then
        return
    end
    for key, value in pairs(fields) do
        if value == Housing.Null then
            row[key] = nil
        else
            row[key] = clone(value)
        end
    end
end

local function accessKey(propertyId, framework, characterId)
    return propertyId .. '\0' .. framework .. '\0' .. characterId
end

function Housing.MemoryRepository.new(clock)
    local state = {
        properties = {},
        stashes = {},
        ownership = {},
        tenancies = {},
        access = {},
        keys = {},
        transactions = {},
        payouts = {},
        balances = {},
        bills = {},
        furniture = {},
        upgrades = {},
        vehicles = {},
        warrants = {},
        raids = {},
        evidence = {},
        transfers = {},
        audit = {},
        migrations = {},
        utilityRates = {},
        auditSeq = 0,
    }

    local repo = {}

    local function now()
        if clock then
            return clock()
        end
        return os.time()
    end

    function repo.getProperty(id)
        local row = state.properties[id]
        return row and clone(row) or nil
    end

    function repo.listProperties()
        local list = {}
        for _, row in pairs(state.properties) do
            list[#list + 1] = clone(row)
        end
        table.sort(list, function(a, b) return a.id < b.id end)
        return list
    end

    function repo.insertProperty(row)
        if state.properties[row.id] then
            return false
        end
        state.properties[row.id] = clone(row)
        return true
    end

    function repo.updateProperty(id, fields)
        local row = state.properties[id]
        if not row then
            return false
        end
        assign(row, fields)
        row.updated_at = now()
        return true
    end

    function repo.casPropertyStatus(id, fromStatus, toStatus, fields, where)
        local row = state.properties[id]
        if not row or row.status ~= fromStatus then
            return false
        end
        if where then
            for key, value in pairs(where) do
                if row[key] ~= value then
                    return false
                end
            end
        end
        row.status = toStatus
        row.updated_at = now()
        assign(row, fields)
        return true
    end

    function repo.insertStash(row)
        local key = row.property_id .. '\0' .. row.stash_key
        if state.stashes[key] then
            return false
        end
        state.stashes[key] = clone(row)
        return true
    end

    function repo.updateStash(propertyId, stashKey, fields)
        local row = state.stashes[propertyId .. '\0' .. stashKey]
        if not row then
            return false
        end
        assign(row, fields)
        return true
    end

    function repo.getStash(propertyId, stashKey)
        local row = state.stashes[propertyId .. '\0' .. stashKey]
        return row and clone(row) or nil
    end

    function repo.listStashes(propertyId)
        local list = {}
        for _, row in pairs(state.stashes) do
            if row.property_id == propertyId then
                list[#list + 1] = clone(row)
            end
        end
        table.sort(list, function(a, b) return a.stash_key < b.stash_key end)
        return list
    end

    function repo.getOwnership(propertyId)
        local row = state.ownership[propertyId]
        return row and clone(row) or nil
    end

    function repo.setOwnership(row)
        state.ownership[row.property_id] = clone(row)
        return true
    end

    function repo.clearOwnership(propertyId)
        state.ownership[propertyId] = nil
        return true
    end

    function repo.countOwnership(framework, characterId)
        local count = 0
        for _, row in pairs(state.ownership) do
            if row.framework == framework and row.character_id == characterId then
                count = count + 1
            end
        end
        return count
    end

    function repo.listOwnershipFor(framework, characterId)
        local list = {}
        for _, row in pairs(state.ownership) do
            if row.framework == framework and row.character_id == characterId then
                list[#list + 1] = clone(row)
            end
        end
        return list
    end

    function repo.insertTenancy(row)
        if state.tenancies[row.id] then
            return false
        end
        state.tenancies[row.id] = clone(row)
        return true
    end

    function repo.getTenancy(id)
        local row = state.tenancies[id]
        return row and clone(row) or nil
    end

    function repo.getActiveTenancy(propertyId)
        for _, row in pairs(state.tenancies) do
            if row.property_id == propertyId and row.status == 'active' then
                return clone(row)
            end
        end
        return nil
    end

    function repo.updateTenancy(id, fields)
        local row = state.tenancies[id]
        if not row then
            return false
        end
        assign(row, fields)
        return true
    end

    function repo.casTenancy(id, fromStatus, fields)
        local row = state.tenancies[id]
        if not row or row.status ~= fromStatus then
            return false
        end
        assign(row, fields)
        return true
    end

    function repo.expireDueTenancies(at)
        local expired = {}
        for _, row in pairs(state.tenancies) do
            if row.status == 'active' and row.expires_at <= at then
                row.status = 'expired'
                expired[#expired + 1] = clone(row)
            end
        end
        return expired
    end

    function repo.getAccess(propertyId, framework, characterId)
        local row = state.access[accessKey(propertyId, framework, characterId)]
        return row and clone(row) or nil
    end

    function repo.listAccess(propertyId)
        local list = {}
        for _, row in pairs(state.access) do
            if row.property_id == propertyId then
                list[#list + 1] = clone(row)
            end
        end
        return list
    end

    function repo.upsertAccess(row)
        state.access[accessKey(row.property_id, row.framework, row.character_id)] = clone(row)
        return true
    end

    function repo.revokeAllAccess(propertyId, revokedAt, revokedBy)
        local count = 0
        for _, row in pairs(state.access) do
            if row.property_id == propertyId and not row.revoked_at then
                row.revoked_at = revokedAt
                row.revoked_by = revokedBy
                count = count + 1
            end
        end
        return count
    end

    function repo.insertKey(row)
        if state.keys[row.id] then
            return false
        end
        state.keys[row.id] = clone(row)
        return true
    end

    function repo.getKey(id)
        local row = state.keys[id]
        return row and clone(row) or nil
    end

    function repo.listKeys(propertyId)
        local list = {}
        for _, row in pairs(state.keys) do
            if row.property_id == propertyId then
                list[#list + 1] = clone(row)
            end
        end
        return list
    end

    function repo.updateKey(id, fields)
        local row = state.keys[id]
        if not row then
            return false
        end
        assign(row, fields)
        return true
    end

    function repo.casKeyState(id, fromState, fields)
        local row = state.keys[id]
        if not row or row.state ~= fromState then
            return false
        end
        assign(row, fields)
        return true
    end

    function repo.revokeKeysForProperty(propertyId, revokedAt, revokedBy)
        local count = 0
        for _, row in pairs(state.keys) do
            if row.property_id == propertyId and row.state ~= 'revoked' then
                row.state = 'revoked'
                row.revoked_at = revokedAt
                row.revoked_by = revokedBy
                count = count + 1
            end
        end
        return count
    end

    function repo.insertTransaction(row)
        if state.transactions[row.id] then
            return false
        end
        local stored = clone(row)
        stored.updated_at = stored.updated_at or now()
        state.transactions[row.id] = stored
        return true
    end

    function repo.getTransaction(id)
        local row = state.transactions[id]
        return row and clone(row) or nil
    end

    function repo.casTransaction(id, fromMoneyState, fields)
        local row = state.transactions[id]
        if not row or row.money_state ~= fromMoneyState then
            return false
        end
        assign(row, fields)
        row.updated_at = now()
        return true
    end

    function repo.listPendingTransactions()
        local list = {}
        for _, row in pairs(state.transactions) do
            if row.status == 'pending' or row.status == 'needs_review' then
                list[#list + 1] = clone(row)
            end
        end
        return list
    end

    function repo.insertPayout(row)
        if state.payouts[row.id] then
            return false
        end
        state.payouts[row.id] = clone(row)
        return true
    end

    function repo.casPayout(id, fromStatus, fields)
        local row = state.payouts[id]
        if not row or row.status ~= fromStatus then
            return false
        end
        assign(row, fields)
        return true
    end

    function repo.listPendingPayouts(framework, characterId)
        local list = {}
        for _, row in pairs(state.payouts) do
            if row.status == 'pending' and row.framework == framework and row.character_id == characterId then
                list[#list + 1] = clone(row)
            end
        end
        return list
    end

    function repo.getBalance(framework, characterId, accountName)
        local row = state.balances[framework .. '\0' .. characterId .. '\0' .. accountName]
        return row and row.balance or 0
    end

    function repo.ensureBalance(framework, characterId, accountName, amount)
        local key = framework .. '\0' .. characterId .. '\0' .. accountName
        if not state.balances[key] then
            state.balances[key] = { balance = amount }
        end
        return state.balances[key].balance
    end

    function repo.tryRemoveBalance(framework, characterId, accountName, amount)
        local key = framework .. '\0' .. characterId .. '\0' .. accountName
        local row = state.balances[key]
        if not row or amount < 0 or row.balance < amount then
            return false
        end
        row.balance = row.balance - amount
        return true
    end

    function repo.addBalance(framework, characterId, accountName, amount)
        if amount < 0 then
            return false
        end
        local key = framework .. '\0' .. characterId .. '\0' .. accountName
        local row = state.balances[key]
        if not row then
            row = { balance = 0 }
            state.balances[key] = row
        end
        row.balance = row.balance + amount
        return true
    end

    function repo.insertBill(row)
        if state.bills[row.id] then
            return false
        end
        state.bills[row.id] = clone(row)
        return true
    end

    function repo.getBill(id)
        local row = state.bills[id]
        return row and clone(row) or nil
    end

    function repo.listBills(propertyId, status)
        local list = {}
        for _, row in pairs(state.bills) do
            if row.property_id == propertyId and (not status or row.status == status) then
                list[#list + 1] = clone(row)
            end
        end
        return list
    end

    function repo.casBill(id, fromStatus, fields)
        local row = state.bills[id]
        if not row or row.status ~= fromStatus then
            return false
        end
        assign(row, fields)
        return true
    end

    function repo.hasBillForWeek(propertyId, billType, weekId)
        for _, row in pairs(state.bills) do
            if row.property_id == propertyId and row.bill_type == billType and row.week_id == weekId then
                return true
            end
        end
        return false
    end

    function repo.listUtilityRates(weekId)
        local map = {}
        for _, row in pairs(state.utilityRates) do
            if row.week_id == weekId then
                map[row.bill_type] = row.amount
            end
        end
        return map
    end

    function repo.saveUtilityRate(weekId, billType, amount, rolledAt)
        local key = tostring(weekId) .. '\0' .. billType
        if state.utilityRates[key] then
            return false
        end
        state.utilityRates[key] = {
            week_id = weekId,
            bill_type = billType,
            amount = amount,
            rolled_at = rolledAt,
        }
        return true
    end

    function repo.insertFurniture(row)
        if state.furniture[row.id] then
            return false
        end
        state.furniture[row.id] = clone(row)
        return true
    end

    function repo.getFurniture(id)
        local row = state.furniture[id]
        return row and clone(row) or nil
    end

    function repo.listFurniture(propertyId)
        local list = {}
        for _, row in pairs(state.furniture) do
            if row.property_id == propertyId then
                list[#list + 1] = clone(row)
            end
        end
        return list
    end

    function repo.updateFurniture(id, fields)
        local row = state.furniture[id]
        if not row then
            return false
        end
        assign(row, fields)
        return true
    end

    function repo.countFurniture(propertyId)
        local count = 0
        for _, row in pairs(state.furniture) do
            if row.property_id == propertyId then
                count = count + 1
            end
        end
        return count
    end

    function repo.insertUpgrade(row)
        local key = row.property_id .. '\0' .. row.upgrade_id
        if state.upgrades[key] then
            return false
        end
        state.upgrades[key] = clone(row)
        return true
    end

    function repo.listUpgrades(propertyId)
        local list = {}
        for _, row in pairs(state.upgrades) do
            if row.property_id == propertyId then
                list[#list + 1] = clone(row)
            end
        end
        return list
    end

    function repo.insertVehicle(row)
        if state.vehicles[row.id] then
            return false
        end
        state.vehicles[row.id] = clone(row)
        return true
    end

    function repo.listVehicles(propertyId)
        local list = {}
        for _, row in pairs(state.vehicles) do
            if row.property_id == propertyId then
                list[#list + 1] = clone(row)
            end
        end
        return list
    end

    function repo.getVehicleByPlate(propertyId, plate)
        for _, row in pairs(state.vehicles) do
            if row.property_id == propertyId and row.plate == plate and row.state == 'stored' then
                return clone(row)
            end
        end
        return nil
    end

    function repo.updateVehicle(id, fields)
        local row = state.vehicles[id]
        if not row then
            return false
        end
        assign(row, fields)
        return true
    end

    function repo.countStoredVehicles(propertyId)
        local count = 0
        for _, row in pairs(state.vehicles) do
            if row.property_id == propertyId and row.state == 'stored' then
                count = count + 1
            end
        end
        return count
    end

    function repo.insertWarrant(row)
        if state.warrants[row.id] then
            return false
        end
        state.warrants[row.id] = clone(row)
        return true
    end

    function repo.getWarrant(id)
        local row = state.warrants[id]
        return row and clone(row) or nil
    end

    function repo.casWarrant(id, fromStatus, fields)
        local row = state.warrants[id]
        if not row or row.status ~= fromStatus then
            return false
        end
        assign(row, fields)
        return true
    end

    function repo.listWarrants(propertyId)
        local list = {}
        for _, row in pairs(state.warrants) do
            if not propertyId or row.property_id == propertyId then
                list[#list + 1] = clone(row)
            end
        end
        return list
    end

    function repo.insertRaid(row)
        if state.raids[row.id] then
            return false
        end
        state.raids[row.id] = clone(row)
        return true
    end

    function repo.getRaid(id)
        local row = state.raids[id]
        return row and clone(row) or nil
    end

    function repo.casRaid(id, fromState, fields)
        local row = state.raids[id]
        if not row or row.state ~= fromState then
            return false
        end
        if fields and fields.state and not Housing.CanTransitionRaid(fromState, fields.state) then
            return false
        end
        assign(row, fields)
        return true
    end

    function repo.findOpenRaid(propertyId)
        for _, row in pairs(state.raids) do
            if row.property_id == propertyId and Housing.OpenRaidStates[row.state] then
                return clone(row)
            end
        end
        return nil
    end

    function repo.listRaids(propertyId)
        local list = {}
        for _, row in pairs(state.raids) do
            if not propertyId or row.property_id == propertyId then
                list[#list + 1] = clone(row)
            end
        end
        return list
    end

    function repo.insertEvidence(row)
        if state.evidence[row.id] then
            return false
        end
        state.evidence[row.id] = clone(row)
        return true
    end

    function repo.getEvidence(id)
        local row = state.evidence[id]
        return row and clone(row) or nil
    end

    function repo.casEvidence(id, fromStatus, fields)
        local row = state.evidence[id]
        if not row or row.status ~= fromStatus then
            return false
        end
        assign(row, fields)
        return true
    end

    function repo.listEvidence(propertyId)
        local list = {}
        for _, row in pairs(state.evidence) do
            if not propertyId or row.property_id == propertyId then
                list[#list + 1] = clone(row)
            end
        end
        return list
    end

    function repo.insertTransfer(row)
        if state.transfers[row.id] then
            return false
        end
        state.transfers[row.id] = clone(row)
        return true
    end

    function repo.insertAudit(row)
        state.auditSeq = state.auditSeq + 1
        local stored = clone(row)
        stored.id = state.auditSeq
        state.audit[#state.audit + 1] = stored
        return stored.id
    end

    function repo.listAudit(propertyId, limit)
        local list = {}
        for index = #state.audit, 1, -1 do
            local row = state.audit[index]
            if not propertyId or row.property_id == propertyId then
                list[#list + 1] = clone(row)
                if limit and #list >= limit then
                    break
                end
            end
        end
        return list
    end

    function repo.getSchemaVersion(version)
        return state.migrations[version] == true
    end

    function repo.setSchemaVersion(version)
        state.migrations[version] = true
        return true
    end

    return repo
end
