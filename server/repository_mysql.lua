Housing = Housing or {}
Housing.MySqlRepository = Housing.MySqlRepository or {}

local jsonColumns = {
    entrance = 'entrance_json',
    interior = 'interior_json',
    shell_options = 'shell_options_json',
    ipls = 'ipls_json',
    garage = 'garage_json',
    doors = 'doors_json',
    features = 'features_json',
    scope_json = 'scope_json',
    officers_json = 'officers_json',
    detail_json = 'detail_json',
    metadata_json = 'metadata_json',
    offset_json = 'offset_json',
}

local function encode(value)
    if value == Housing.Null or value == nil then
        return nil
    end
    if type(value) == 'table' then
        return json.encode(value)
    end
    return value
end

local function decode(value)
    if type(value) ~= 'string' then
        return value
    end
    local first = value:sub(1, 1)
    if first ~= '{' and first ~= '[' then
        return value
    end
    local ok, parsed = pcall(json.decode, value)
    if ok then
        return parsed
    end
    return value
end

local function propertyFrom(row)
    if not row then return nil end
    row.entrance = decode(row.entrance_json)
    row.interior = decode(row.interior_json)
    row.shell_options = decode(row.shell_options_json)
    row.ipls = decode(row.ipls_json)
    row.garage = decode(row.garage_json)
    row.doors = decode(row.doors_json)
    row.features = decode(row.features_json)
    return row
end

local function affected(result)
    return result == 1 or result == true
end

function Housing.MySqlRepository.new()
    local repo = {}

    function repo.getProperty(id)
        return propertyFrom(MySQL.single.await('SELECT * FROM housing_properties WHERE id = ?', { id }))
    end

    function repo.listProperties()
        local rows = MySQL.query.await('SELECT * FROM housing_properties ORDER BY id ASC', {}) or {}
        for index = 1, #rows do
            propertyFrom(rows[index])
        end
        return rows
    end

    function repo.insertProperty(row)
        local ok = pcall(function()
            MySQL.insert.await([[
                INSERT INTO housing_properties
                (id, label, description, property_type, purchase_price, rental_price, rental_period_hours,
                 entrance_json, interior_json, shell_model, shell_options_json, ipls_json, image_key,
                 bedrooms, bathrooms, garages, garage_json, doors_json, features_json, status,
                 reservation_token, listed, listing_price, enabled, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ]], {
                row.id, row.label, row.description, row.property_type, row.purchase_price, row.rental_price,
                row.rental_period_hours, encode(row.entrance), encode(row.interior), row.shell_model,
                encode(row.shell_options), encode(row.ipls), row.image_key, row.bedrooms, row.bathrooms,
                row.garages, encode(row.garage), encode(row.doors), encode(row.features), row.status,
                row.reservation_token, row.listed or 0, row.listing_price, row.enabled or 1, row.created_at, row.updated_at,
            })
        end)
        return ok
    end

    function repo.updateProperty(id, fields)
        local columns = {
            label = true, description = true, property_type = true, purchase_price = true, rental_price = true,
            rental_period_hours = true, shell_model = true, image_key = true, bedrooms = true, bathrooms = true,
            garages = true, status = true, reservation_token = true, listed = true, listing_price = true, enabled = true,
            entrance = true, interior = true, shell_options = true, ipls = true, garage = true, doors = true, features = true,
        }
        local sets, params = {}, {}
        for key, value in pairs(fields) do
            if columns[key] then
                local column = jsonColumns[key] or key
                sets[#sets + 1] = column .. ' = ?'
                params[#params + 1] = encode(value)
            end
        end
        if #sets == 0 then return false end
        sets[#sets + 1] = 'updated_at = ?'
        params[#params + 1] = os.time()
        params[#params + 1] = id
        local changed = MySQL.update.await('UPDATE housing_properties SET ' .. table.concat(sets, ', ') .. ' WHERE id = ?', params)
        return (changed or 0) > 0
    end

    function repo.casPropertyStatus(id, fromStatus, toStatus, fields, where)
        fields = fields or {}
        fields.status = toStatus
        local columns = {
            status = true, reservation_token = true, listed = true, listing_price = true, enabled = true,
        }
        local sets, params = { 'updated_at = ?' }, { os.time() }
        for key, value in pairs(fields) do
            if columns[key] then
                sets[#sets + 1] = key .. ' = ?'
                params[#params + 1] = encode(value)
            end
        end
        local sql = 'UPDATE housing_properties SET ' .. table.concat(sets, ', ') .. ' WHERE id = ? AND status = ?'
        params[#params + 1] = id
        params[#params + 1] = fromStatus
        if where then
            for key, value in pairs(where) do
                if key == 'listed' or key == 'reservation_token' then
                    sql = sql .. ' AND ' .. key .. ' = ?'
                    params[#params + 1] = value
                end
            end
        end
        return affected(MySQL.update.await(sql, params))
    end

    function repo.insertStash(row)
        local ok = pcall(function()
            MySQL.insert.await([[
                INSERT INTO housing_stashes (property_id, stash_key, label, stash_type, access_level, slots, max_weight)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ]], { row.property_id, row.stash_key, row.label, row.stash_type, row.access_level, row.slots, row.max_weight })
        end)
        return ok
    end

    function repo.updateStash(propertyId, stashKey, fields)
        local changed = MySQL.update.await(
            'UPDATE housing_stashes SET slots = COALESCE(?, slots), max_weight = COALESCE(?, max_weight), label = COALESCE(?, label) WHERE property_id = ? AND stash_key = ?',
            { fields.slots, fields.max_weight, fields.label, propertyId, stashKey }
        )
        return (changed or 0) > 0
    end

    function repo.getStash(propertyId, stashKey)
        return MySQL.single.await('SELECT * FROM housing_stashes WHERE property_id = ? AND stash_key = ?', { propertyId, stashKey })
    end

    function repo.listStashes(propertyId)
        return MySQL.query.await('SELECT * FROM housing_stashes WHERE property_id = ? ORDER BY stash_key', { propertyId }) or {}
    end

    function repo.getOwnership(propertyId)
        return MySQL.single.await('SELECT * FROM housing_ownership WHERE property_id = ?', { propertyId })
    end

    function repo.setOwnership(row)
        MySQL.update.await([[
            INSERT INTO housing_ownership (property_id, framework, character_id, display_name, purchased_at, purchase_price, acquisition, shell_model)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE framework = VALUES(framework), character_id = VALUES(character_id), display_name = VALUES(display_name),
            purchased_at = VALUES(purchased_at), purchase_price = VALUES(purchase_price), acquisition = VALUES(acquisition), shell_model = VALUES(shell_model)
        ]], { row.property_id, row.framework, row.character_id, row.display_name, row.purchased_at, row.purchase_price, row.acquisition, row.shell_model })
        return true
    end

    function repo.clearOwnership(propertyId)
        MySQL.update.await('DELETE FROM housing_ownership WHERE property_id = ?', { propertyId })
        return true
    end

    function repo.countOwnership(framework, characterId)
        return MySQL.scalar.await('SELECT COUNT(*) FROM housing_ownership WHERE framework = ? AND character_id = ?', { framework, characterId }) or 0
    end

    function repo.listOwnershipFor(framework, characterId)
        return MySQL.query.await('SELECT * FROM housing_ownership WHERE framework = ? AND character_id = ?', { framework, characterId }) or {}
    end

    function repo.insertTenancy(row)
        local ok = pcall(function()
            MySQL.insert.await([[
                INSERT INTO housing_tenancies (id, property_id, framework, character_id, display_name, started_at, expires_at, price_paid, status)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ]], { row.id, row.property_id, row.framework, row.character_id, row.display_name, row.started_at, row.expires_at, row.price_paid, row.status })
        end)
        return ok
    end

    function repo.getTenancy(id)
        return MySQL.single.await('SELECT * FROM housing_tenancies WHERE id = ?', { id })
    end

    function repo.getActiveTenancy(propertyId)
        return MySQL.single.await("SELECT * FROM housing_tenancies WHERE property_id = ? AND status = 'active' LIMIT 1", { propertyId })
    end

    function repo.updateTenancy(id, fields)
        return affected(MySQL.update.await('UPDATE housing_tenancies SET expires_at = COALESCE(?, expires_at), price_paid = COALESCE(?, price_paid), status = COALESCE(?, status) WHERE id = ?', {
            fields.expires_at, fields.price_paid, fields.status, id,
        }))
    end

    function repo.casTenancy(id, fromStatus, fields)
        return affected(MySQL.update.await('UPDATE housing_tenancies SET expires_at = COALESCE(?, expires_at), price_paid = COALESCE(?, price_paid), status = COALESCE(?, status) WHERE id = ? AND status = ?', {
            fields.expires_at, fields.price_paid, fields.status, id, fromStatus,
        }))
    end

    function repo.expireDueTenancies(at)
        local rows = MySQL.query.await("SELECT * FROM housing_tenancies WHERE status = 'active' AND expires_at <= ?", { at }) or {}
        if #rows > 0 then
            MySQL.update.await("UPDATE housing_tenancies SET status = 'expired' WHERE status = 'active' AND expires_at <= ?", { at })
        end
        return rows
    end

    function repo.getAccess(propertyId, framework, characterId)
        return MySQL.single.await('SELECT * FROM housing_access WHERE property_id = ? AND framework = ? AND character_id = ?', { propertyId, framework, characterId })
    end

    function repo.listAccess(propertyId)
        return MySQL.query.await('SELECT * FROM housing_access WHERE property_id = ?', { propertyId }) or {}
    end

    function repo.upsertAccess(row)
        MySQL.update.await([[
            INSERT INTO housing_access (property_id, framework, character_id, display_name, role, granted_by, granted_at, expires_at, revoked_at, revoked_by)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE display_name = VALUES(display_name), role = VALUES(role), granted_by = VALUES(granted_by),
            granted_at = VALUES(granted_at), expires_at = VALUES(expires_at), revoked_at = VALUES(revoked_at), revoked_by = VALUES(revoked_by)
        ]], { row.property_id, row.framework, row.character_id, row.display_name, row.role, row.granted_by, row.granted_at, row.expires_at, row.revoked_at, row.revoked_by })
        return true
    end

    function repo.revokeAllAccess(propertyId, revokedAt, revokedBy)
        return MySQL.update.await('UPDATE housing_access SET revoked_at = ?, revoked_by = ? WHERE property_id = ? AND revoked_at IS NULL', { revokedAt, revokedBy, propertyId }) or 0
    end

    function repo.insertKey(row)
        local ok = pcall(function()
            MySQL.insert.await([[
                INSERT INTO housing_keys (id, property_id, holder_framework, holder_character_id, issued_by, access_level, state, issued_at, expires_at, revoked_at, revoked_by, inventory_state)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ]], { row.id, row.property_id, row.holder_framework, row.holder_character_id, row.issued_by, row.access_level, row.state, row.issued_at, row.expires_at, row.revoked_at, row.revoked_by, row.inventory_state })
        end)
        return ok
    end

    function repo.getKey(id)
        return MySQL.single.await('SELECT * FROM housing_keys WHERE id = ?', { id })
    end

    function repo.listKeys(propertyId)
        return MySQL.query.await('SELECT * FROM housing_keys WHERE property_id = ?', { propertyId }) or {}
    end

    function repo.updateKey(id, fields)
        return affected(MySQL.update.await([[
            UPDATE housing_keys SET state = COALESCE(?, state), inventory_state = COALESCE(?, inventory_state),
            revoked_at = COALESCE(?, revoked_at), revoked_by = COALESCE(?, revoked_by),
            holder_framework = COALESCE(?, holder_framework), holder_character_id = COALESCE(?, holder_character_id)
            WHERE id = ?
        ]], { fields.state, fields.inventory_state, fields.revoked_at, fields.revoked_by, fields.holder_framework, fields.holder_character_id, id }))
    end

    function repo.casKeyState(id, fromState, fields)
        return affected(MySQL.update.await([[
            UPDATE housing_keys SET state = COALESCE(?, state), inventory_state = COALESCE(?, inventory_state),
            revoked_at = COALESCE(?, revoked_at), revoked_by = COALESCE(?, revoked_by)
            WHERE id = ? AND state = ?
        ]], { fields.state, fields.inventory_state, fields.revoked_at, fields.revoked_by, id, fromState }))
    end

    function repo.revokeKeysForProperty(propertyId, revokedAt, revokedBy)
        return MySQL.update.await("UPDATE housing_keys SET state = 'revoked', revoked_at = ?, revoked_by = ?, inventory_state = 'revoked' WHERE property_id = ? AND state <> 'revoked'", { revokedAt, revokedBy, propertyId }) or 0
    end

    function repo.insertTransaction(row)
        local ok = pcall(function()
            MySQL.insert.await([[
                INSERT INTO housing_transactions
                (id, property_id, framework, actor_character_id, tx_type, amount, account_name, status, money_state, grant_state, reservation_token, error_code, detail_json, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ]], { row.id, row.property_id, row.framework, row.actor_character_id, row.tx_type, row.amount, row.account_name, row.status, row.money_state, row.grant_state, row.reservation_token, row.error_code, encode(row.detail_json), row.created_at, row.updated_at })
        end)
        return ok
    end

    function repo.getTransaction(id)
        local row = MySQL.single.await('SELECT * FROM housing_transactions WHERE id = ?', { id })
        if row then row.detail_json = decode(row.detail_json) end
        return row
    end

    function repo.casTransaction(id, fromMoneyState, fields)
        return affected(MySQL.update.await([[
            UPDATE housing_transactions
            SET status = COALESCE(?, status), money_state = COALESCE(?, money_state), grant_state = COALESCE(?, grant_state),
                reservation_token = COALESCE(?, reservation_token), error_code = COALESCE(?, error_code), updated_at = ?
            WHERE id = ? AND money_state = ?
        ]], { fields.status, fields.money_state, fields.grant_state, fields.reservation_token, fields.error_code, os.time(), id, fromMoneyState }))
    end

    function repo.listPendingTransactions()
        local rows = MySQL.query.await("SELECT * FROM housing_transactions WHERE status IN ('pending', 'needs_review')", {}) or {}
        for index = 1, #rows do rows[index].detail_json = decode(rows[index].detail_json) end
        return rows
    end

    function repo.insertPayout(row)
        local ok = pcall(function()
            MySQL.insert.await([[
                INSERT INTO housing_payouts (id, framework, character_id, amount, account_name, reason_text, status, property_id, created_at, paid_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ]], { row.id, row.framework, row.character_id, row.amount, row.account_name, row.reason_text, row.status, row.property_id, row.created_at, row.paid_at })
        end)
        return ok
    end

    function repo.casPayout(id, fromStatus, fields)
        return affected(MySQL.update.await('UPDATE housing_payouts SET status = COALESCE(?, status), paid_at = COALESCE(?, paid_at) WHERE id = ? AND status = ?', {
            fields.status, fields.paid_at, id, fromStatus,
        }))
    end

    function repo.listPendingPayouts(framework, characterId)
        return MySQL.query.await("SELECT * FROM housing_payouts WHERE framework = ? AND character_id = ? AND status = 'pending'", { framework, characterId }) or {}
    end

    function repo.getBalance(framework, characterId, accountName)
        return MySQL.scalar.await('SELECT balance FROM housing_balances WHERE framework = ? AND character_id = ? AND account_name = ?', { framework, characterId, accountName }) or 0
    end

    function repo.ensureBalance(framework, characterId, accountName, amount)
        MySQL.update.await([[
            INSERT INTO housing_balances (framework, character_id, account_name, balance) VALUES (?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE balance = balance
        ]], { framework, characterId, accountName, amount })
        return repo.getBalance(framework, characterId, accountName)
    end

    function repo.tryRemoveBalance(framework, characterId, accountName, amount)
        if amount < 0 then return false end
        return affected(MySQL.update.await('UPDATE housing_balances SET balance = balance - ? WHERE framework = ? AND character_id = ? AND account_name = ? AND balance >= ?', {
            amount, framework, characterId, accountName, amount,
        }))
    end

    function repo.addBalance(framework, characterId, accountName, amount)
        if amount < 0 then return false end
        MySQL.update.await([[
            INSERT INTO housing_balances (framework, character_id, account_name, balance) VALUES (?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE balance = balance + VALUES(balance)
        ]], { framework, characterId, accountName, amount })
        return true
    end

    function repo.insertBill(row)
        local ok = pcall(function()
            MySQL.insert.await('INSERT INTO housing_bills (id, property_id, bill_type, label, amount, status, due_at, paid_at, paid_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', {
                row.id, row.property_id, row.bill_type, row.label, row.amount, row.status, row.due_at, row.paid_at, row.paid_by,
            })
        end)
        return ok
    end

    function repo.getBill(id)
        return MySQL.single.await('SELECT * FROM housing_bills WHERE id = ?', { id })
    end

    function repo.listBills(propertyId, status)
        if status then
            return MySQL.query.await('SELECT * FROM housing_bills WHERE property_id = ? AND status = ?', { propertyId, status }) or {}
        end
        return MySQL.query.await('SELECT * FROM housing_bills WHERE property_id = ?', { propertyId }) or {}
    end

    function repo.casBill(id, fromStatus, fields)
        return affected(MySQL.update.await('UPDATE housing_bills SET status = ?, paid_at = ?, paid_by = ? WHERE id = ? AND status = ?', {
            fields.status, fields.paid_at, fields.paid_by, id, fromStatus,
        }))
    end

    function repo.insertFurniture(row)
        local ok = pcall(function()
            MySQL.insert.await('INSERT INTO housing_furniture (id, property_id, catalog_id, model, label, state, offset_json, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
                row.id, row.property_id, row.catalog_id, row.model, row.label, row.state, encode(row.offset_json), row.created_at,
            })
        end)
        return ok
    end

    function repo.getFurniture(id)
        local row = MySQL.single.await('SELECT * FROM housing_furniture WHERE id = ?', { id })
        if row then row.offset_json = decode(row.offset_json) end
        return row
    end

    function repo.listFurniture(propertyId)
        local rows = MySQL.query.await('SELECT * FROM housing_furniture WHERE property_id = ?', { propertyId }) or {}
        for index = 1, #rows do rows[index].offset_json = decode(rows[index].offset_json) end
        return rows
    end

    function repo.updateFurniture(id, fields)
        return affected(MySQL.update.await('UPDATE housing_furniture SET state = COALESCE(?, state), offset_json = COALESCE(?, offset_json) WHERE id = ?', {
            fields.state, encode(fields.offset_json), id,
        }))
    end

    function repo.countFurniture(propertyId)
        return MySQL.scalar.await('SELECT COUNT(*) FROM housing_furniture WHERE property_id = ?', { propertyId }) or 0
    end

    function repo.insertUpgrade(row)
        local ok = pcall(function()
            MySQL.insert.await('INSERT INTO housing_upgrades (property_id, upgrade_id, purchased_at, purchased_by) VALUES (?, ?, ?, ?)', {
                row.property_id, row.upgrade_id, row.purchased_at, row.purchased_by,
            })
        end)
        return ok
    end

    function repo.listUpgrades(propertyId)
        return MySQL.query.await('SELECT * FROM housing_upgrades WHERE property_id = ?', { propertyId }) or {}
    end

    function repo.insertVehicle(row)
        local ok = pcall(function()
            MySQL.insert.await('INSERT INTO housing_vehicles (id, property_id, framework, character_id, plate, model_hash, state, stored_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
                row.id, row.property_id, row.framework, row.character_id, row.plate, row.model_hash, row.state, row.stored_at,
            })
        end)
        return ok
    end

    function repo.listVehicles(propertyId)
        return MySQL.query.await('SELECT * FROM housing_vehicles WHERE property_id = ?', { propertyId }) or {}
    end

    function repo.getVehicleByPlate(propertyId, plate)
        return MySQL.single.await("SELECT * FROM housing_vehicles WHERE property_id = ? AND plate = ? AND state = 'stored'", { propertyId, plate })
    end

    function repo.updateVehicle(id, fields)
        return affected(MySQL.update.await('UPDATE housing_vehicles SET state = COALESCE(?, state) WHERE id = ?', { fields.state, id }))
    end

    function repo.countStoredVehicles(propertyId)
        return MySQL.scalar.await("SELECT COUNT(*) FROM housing_vehicles WHERE property_id = ? AND state = 'stored'", { propertyId }) or 0
    end

    local function warrant(row)
        if row then row.scope_json = decode(row.scope_json) end
        return row
    end

    function repo.insertWarrant(row)
        local ok = pcall(function()
            MySQL.insert.await([[
                INSERT INTO housing_warrants
                (id, property_id, requester_framework, requester_character_id, requester_name, approver_character_id, approver_name,
                 reason_text, case_reference, scope_json, allow_seizure, status, emergency, issued_at, expires_at, decided_at, revoked_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ]], { row.id, row.property_id, row.requester_framework, row.requester_character_id, row.requester_name, row.approver_character_id, row.approver_name, row.reason_text, row.case_reference, encode(row.scope_json), row.allow_seizure, row.status, row.emergency, row.issued_at, row.expires_at, row.decided_at, row.revoked_at })
        end)
        return ok
    end

    function repo.getWarrant(id)
        return warrant(MySQL.single.await('SELECT * FROM housing_warrants WHERE id = ?', { id }))
    end

    function repo.casWarrant(id, fromStatus, fields)
        return affected(MySQL.update.await([[
            UPDATE housing_warrants SET status = COALESCE(?, status), approver_character_id = COALESCE(?, approver_character_id),
            approver_name = COALESCE(?, approver_name), decided_at = COALESCE(?, decided_at), revoked_at = COALESCE(?, revoked_at)
            WHERE id = ? AND status = ?
        ]], { fields.status, fields.approver_character_id, fields.approver_name, fields.decided_at, fields.revoked_at, id, fromStatus }))
    end

    function repo.listWarrants(propertyId)
        local rows
        if propertyId then
            rows = MySQL.query.await('SELECT * FROM housing_warrants WHERE property_id = ? ORDER BY issued_at DESC', { propertyId }) or {}
        else
            rows = MySQL.query.await('SELECT * FROM housing_warrants ORDER BY issued_at DESC LIMIT 100', {}) or {}
        end
        for index = 1, #rows do warrant(rows[index]) end
        return rows
    end

    local function raid(row)
        if row then
            row.officers_json = decode(row.officers_json)
            row.scope_json = decode(row.scope_json)
        end
        return row
    end

    function repo.insertRaid(row)
        local ok = pcall(function()
            MySQL.insert.await([[
                INSERT INTO housing_raids
                (id, property_id, warrant_id, lead_framework, lead_character_id, lead_name, officers_json, state, emergency, allow_seizure, scope_json, started_at, ended_at, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ]], { row.id, row.property_id, row.warrant_id, row.lead_framework, row.lead_character_id, row.lead_name, encode(row.officers_json), row.state, row.emergency, row.allow_seizure, encode(row.scope_json), row.started_at, row.ended_at, row.created_at })
        end)
        return ok
    end

    function repo.getRaid(id)
        return raid(MySQL.single.await('SELECT * FROM housing_raids WHERE id = ?', { id }))
    end

    function repo.casRaid(id, fromState, fields)
        if fields.state and not Housing.CanTransitionRaid(fromState, fields.state) then
            return false
        end
        return affected(MySQL.update.await('UPDATE housing_raids SET state = COALESCE(?, state), started_at = COALESCE(?, started_at), ended_at = COALESCE(?, ended_at) WHERE id = ? AND state = ?', {
            fields.state, fields.started_at, fields.ended_at, id, fromState,
        }))
    end

    function repo.findOpenRaid(propertyId)
        return raid(MySQL.single.await("SELECT * FROM housing_raids WHERE property_id = ? AND state IN ('requested', 'authorised', 'active') LIMIT 1", { propertyId }))
    end

    function repo.listRaids(propertyId)
        local rows
        if propertyId then
            rows = MySQL.query.await('SELECT * FROM housing_raids WHERE property_id = ? ORDER BY created_at DESC', { propertyId }) or {}
        else
            rows = MySQL.query.await('SELECT * FROM housing_raids ORDER BY created_at DESC LIMIT 100', {}) or {}
        end
        for index = 1, #rows do raid(rows[index]) end
        return rows
    end

    function repo.insertEvidence(row)
        local ok = pcall(function()
            MySQL.insert.await([[
                INSERT INTO housing_evidence
                (id, property_id, stash_key, raid_id, warrant_id, officer_framework, officer_character_id, officer_name, item_name, quantity, metadata_json, case_reference, status, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ]], { row.id, row.property_id, row.stash_key, row.raid_id, row.warrant_id, row.officer_framework, row.officer_character_id, row.officer_name, row.item_name, row.quantity, encode(row.metadata_json), row.case_reference, row.status, row.created_at, row.updated_at })
        end)
        return ok
    end

    function repo.getEvidence(id)
        local row = MySQL.single.await('SELECT * FROM housing_evidence WHERE id = ?', { id })
        if row then row.metadata_json = decode(row.metadata_json) end
        return row
    end

    function repo.casEvidence(id, fromStatus, fields)
        return affected(MySQL.update.await('UPDATE housing_evidence SET status = COALESCE(?, status), updated_at = ? WHERE id = ? AND status = ?', {
            fields.status, fields.updated_at or os.time(), id, fromStatus,
        }))
    end

    function repo.listEvidence(propertyId)
        local rows
        if propertyId then
            rows = MySQL.query.await('SELECT * FROM housing_evidence WHERE property_id = ? ORDER BY created_at DESC', { propertyId }) or {}
        else
            rows = MySQL.query.await('SELECT * FROM housing_evidence ORDER BY created_at DESC LIMIT 100', {}) or {}
        end
        for index = 1, #rows do rows[index].metadata_json = decode(rows[index].metadata_json) end
        return rows
    end

    function repo.insertTransfer(row)
        local ok = pcall(function()
            MySQL.insert.await('INSERT INTO housing_evidence_transfers (id, evidence_id, from_status, to_status, actor_character_id, note_text, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)', {
                row.id, row.evidence_id, row.from_status, row.to_status, row.actor_character_id, row.note_text, row.created_at,
            })
        end)
        return ok
    end

    function repo.insertAudit(row)
        return MySQL.insert.await([[
            INSERT INTO housing_audit (category, action_name, framework, actor_character_id, property_id, target_id, detail_json, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ]], { row.category, row.action_name, row.framework, row.actor_character_id, row.property_id, row.target_id, encode(row.detail_json), row.created_at })
    end

    function repo.listAudit(propertyId, limit)
        limit = tonumber(limit) or 40
        if limit < 1 or limit > 200 then limit = 40 end
        local rows
        if propertyId then
            rows = MySQL.query.await('SELECT * FROM housing_audit WHERE property_id = ? ORDER BY id DESC LIMIT ' .. limit, { propertyId }) or {}
        else
            rows = MySQL.query.await('SELECT * FROM housing_audit ORDER BY id DESC LIMIT ' .. limit, {}) or {}
        end
        for index = 1, #rows do rows[index].detail_json = decode(rows[index].detail_json) end
        return rows
    end

    function repo.getSchemaVersion(version)
        local value = MySQL.scalar.await('SELECT version FROM housing_schema_migrations WHERE version = ?', { version })
        return value ~= nil
    end

    function repo.setSchemaVersion(version)
        MySQL.insert.await('INSERT IGNORE INTO housing_schema_migrations (version) VALUES (?)', { version })
        return true
    end

    return repo
end
