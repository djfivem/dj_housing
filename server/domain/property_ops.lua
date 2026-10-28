Housing = Housing or {}
Housing.Services = Housing.Services or {}

local Services = Housing.Services
local Validation = Housing.Validation
local Util = Housing.Util
local Auth = Housing.Auth
local Money = Housing.Money

local function furnitureDef(ctx, catalogId)
    for index = 1, #(ctx.config.furniture or {}) do
        if ctx.config.furniture[index].id == catalogId then
            return ctx.config.furniture[index]
        end
    end
    return nil
end

local function upgradeDef(ctx, upgradeId)
    for index = 1, #(ctx.config.upgrades or {}) do
        if ctx.config.upgrades[index].id == upgradeId then
            return ctx.config.upgrades[index]
        end
    end
    return nil
end

local function garageSlots(ctx, property)
    local slots = property.garages or 0
    local owned = ctx.repo.listUpgrades(property.id)
    for index = 1, #owned do
        local def = upgradeDef(ctx, owned[index].upgrade_id)
        if def and def.effect and def.effect.garageSlots then
            slots = slots + def.effect.garageSlots
        end
    end
    return slots
end

function Services.syncDefinitions(ctx, definitions)
    local report = { inserted = 0, updated = 0, errors = {} }
    local seen = {}
    for index = 1, #(definitions or {}) do
        local definition = definitions[index]
        local ok, normalized = Validation.propertyDefinition(definition, ctx.config.shells)
        if not ok then
            report.errors[#report.errors + 1] = { id = type(definition) == 'table' and definition.id or '?', error = normalized }
        elseif seen[normalized.id] then
            report.errors[#report.errors + 1] = { id = normalized.id, error = 'duplicate_id' }
        else
            seen[normalized.id] = true
            local row = {
                id = normalized.id,
                label = normalized.label,
                description = normalized.description,
                property_type = normalized.propertyType,
                purchase_price = normalized.purchasePrice,
                rental_price = normalized.rentalPrice,
                rental_period_hours = normalized.rentalPeriodHours,
                entrance = normalized.entrance,
                interior = normalized.interior,
                shell_model = normalized.shellModel,
                shell_options = normalized.shellOptions,
                ipls = normalized.ipls,
                image_key = normalized.image,
                bedrooms = normalized.bedrooms,
                bathrooms = normalized.bathrooms,
                garages = normalized.garages,
                garage = normalized.garage,
                doors = definition.doors or {},
                features = normalized.features,
                status = 'available',
                reservation_token = nil,
                listed = 0,
                listing_price = nil,
                enabled = 1,
                created_at = ctx.now(),
                updated_at = ctx.now(),
            }
            local existing = ctx.repo.getProperty(normalized.id)
            if not existing then
                ctx.repo.insertProperty(row)
                report.inserted = report.inserted + 1
            elseif ctx.config.housing.syncDefinitions then
                ctx.repo.updateProperty(normalized.id, {
                    label = row.label,
                    description = row.description,
                    property_type = row.property_type,
                    purchase_price = row.purchase_price,
                    rental_price = row.rental_price,
                    rental_period_hours = row.rental_period_hours,
                    entrance = row.entrance,
                    interior = row.interior,
                    shell_model = row.shell_model,
                    shell_options = row.shell_options,
                    ipls = row.ipls,
                    image_key = row.image_key,
                    bedrooms = row.bedrooms,
                    bathrooms = row.bathrooms,
                    garages = row.garages,
                    garage = row.garage,
                    doors = row.doors,
                    features = row.features,
                })
                report.updated = report.updated + 1
            end
            for stashIndex = 1, #normalized.stashes do
                local stash = normalized.stashes[stashIndex]
                if not ctx.repo.getStash(normalized.id, stash.key) then
                    ctx.repo.insertStash({
                        property_id = normalized.id,
                        stash_key = stash.key,
                        label = stash.label,
                        stash_type = stash.stashType,
                        access_level = stash.accessLevel,
                        slots = stash.slots or ctx.config.housing.defaultStashSlots,
                        max_weight = stash.maxWeight or ctx.config.housing.defaultStashWeight,
                    })
                end
            end
        end
    end
    return report
end

function Services.enterProperty(ctx, source, propertyId)
    local idOk, id = Validation.identifier(propertyId or '')
    if not idOk then
        return Util.fail('invalid_payload')
    end
    local player = ctx.framework.getPlayer(source)
    if not player then
        return Util.fail('player_not_found')
    end
    local property = ctx.repo.getProperty(id)
    if not property or property.enabled ~= 1 then
        return Util.fail('property_not_found')
    end
    local raid = ctx.repo.findOpenRaid(property.id)
    local policeEntry = false
    if raid and raid.state == 'active' then
        for index = 1, #(raid.officers_json or {}) do
            if raid.officers_json[index].characterId == player.characterId then
                policeEntry = true
            end
        end
        if raid.lead_character_id == player.characterId then
            policeEntry = true
        end
    end
    if not policeEntry and not Auth.canEnter(ctx, player, property.id) then
        return Util.fail('not_authorised')
    end
    if not policeEntry and not Auth.near(ctx, source, property, 'entrance') and ctx.instance(source) ~= property.id then
        return Util.fail('proximity_failed')
    end
    local bucket = 0
    local shell
    if property.property_type == 'shell' or property.property_type == 'apartment' then
        local ownership = ctx.repo.getOwnership(property.id)
        local model = (ownership and ownership.shell_model) or property.shell_model
        local definition = model and ctx.config.shells[model] or nil
        if not definition then
            return Util.fail('shell_not_configured')
        end
        bucket = Util.bucketFor(property.id)
        shell = {
            model = definition.model,
            origin = Util.shellOrigin(property.id),
            doorOffset = definition.doorOffset,
        }
    end
    return Util.ok({
        propertyId = property.id,
        propertyType = property.property_type,
        label = property.label,
        ipls = property.ipls or {},
        interior = property.interior,
        entrance = property.entrance,
        shell = shell,
        bucket = bucket,
        police = policeEntry,
    })
end

function Services.payBill(ctx, source, raw)
    if type(raw) ~= 'table' or type(raw.billId) ~= 'string' then
        return Util.fail('invalid_payload')
    end
    local player = ctx.framework.getPlayer(source)
    if not player then
        return Util.fail('player_not_found')
    end
    if not ctx.lockCharacter(player.characterId) then
        return Util.fail('busy')
    end
    local function finish(result)
        ctx.unlockCharacter(player.characterId)
        return result
    end
    local bill = ctx.repo.getBill(raw.billId)
    if not bill or bill.status ~= 'due' then
        return finish(Util.fail('not_found'))
    end
    local role = Auth.resolveRole(ctx, player, bill.property_id)
    if role ~= 'owner' and role ~= 'tenant' and role ~= 'coowner' then
        return finish(Util.fail('not_authorised'))
    end
    local taken, state = ctx.framework.removeMoney(source, ctx.config.account, bill.amount, 'housing_bill:' .. bill.id)
    if taken ~= true then
        return finish(Util.fail(state == 'uncertain' and 'needs_review' or 'insufficient_funds'))
    end
    local paid = ctx.repo.casBill(bill.id, 'due', { status = 'paid', paid_at = ctx.now(), paid_by = player.characterId })
    if not paid then
        ctx.framework.addMoney(source, ctx.config.account, bill.amount, 'housing_bill_refund:' .. bill.id)
        return finish(Util.fail('not_found'))
    end
    Auth.audit(ctx, {
        category = 'bill',
        action_name = 'paid',
        framework = player.framework,
        actor_character_id = player.characterId,
        property_id = bill.property_id,
        target_id = bill.id,
        detail_json = { amount = bill.amount },
    })
    return finish(Util.ok({ billId = bill.id, amount = bill.amount }))
end

function Services.payAllBills(ctx, source, propertyId)
    local idOk, id = Validation.identifier(propertyId or '')
    if not idOk then
        return Util.fail('invalid_payload')
    end
    local bills = ctx.repo.listBills(id, 'due')
    local paid = 0
    local failed
    for index = 1, #bills do
        local result = Services.payBill(ctx, source, { billId = bills[index].id })
        if result.ok then
            paid = paid + result.data.amount
        else
            failed = result.error
            break
        end
    end
    return Util.ok({ paid = paid, error = failed })
end

function Services.buyFurniture(ctx, source, raw)
    if type(raw) ~= 'table' then
        return Util.fail('invalid_payload')
    end
    local idOk, propertyId = Validation.identifier(raw.propertyId or '')
    local keyOk, idempotencyKey = Validation.idempotencyKey(raw.idempotencyKey or '')
    if not idOk or not keyOk then
        return Util.fail('invalid_payload')
    end
    local def = furnitureDef(ctx, raw.catalogId)
    if not def then
        return Util.fail('not_found')
    end
    local player = ctx.framework.getPlayer(source)
    if not player then
        return Util.fail('player_not_found')
    end
    if not Auth.canManage(ctx, player, propertyId) then
        return Util.fail('not_authorised')
    end
    if ctx.repo.getFurniture(idempotencyKey) then
        return Util.ok({ replay = true, furnitureId = idempotencyKey })
    end
    if ctx.repo.countFurniture(propertyId) >= Housing.Limits.maxFurniturePerProperty then
        return Util.fail('furniture_limit')
    end
    if not ctx.lockCharacter(player.characterId) then
        return Util.fail('busy')
    end
    local taken, state = ctx.framework.removeMoney(source, ctx.config.account, def.price, 'housing_furniture:' .. def.id)
    if taken ~= true then
        ctx.unlockCharacter(player.characterId)
        return Util.fail(state == 'uncertain' and 'needs_review' or 'insufficient_funds')
    end
    local inserted = ctx.repo.insertFurniture({
        id = idempotencyKey,
        property_id = propertyId,
        catalog_id = def.id,
        model = def.model,
        label = def.label,
        state = 'stored',
        offset_json = nil,
        created_at = ctx.now(),
    })
    ctx.unlockCharacter(player.characterId)
    if not inserted then
        ctx.framework.addMoney(source, ctx.config.account, def.price, 'housing_furniture_refund:' .. def.id)
        return Util.fail('duplicate_request')
    end
    return Util.ok({ furnitureId = idempotencyKey, label = def.label })
end

function Services.placeFurniture(ctx, source, raw)
    local valid, req = Validation.furniturePlace(raw or {})
    if not valid then
        return Util.fail('invalid_payload', req)
    end
    local player = ctx.framework.getPlayer(source)
    if not player then
        return Util.fail('player_not_found')
    end
    if ctx.instance(source) ~= req.propertyId then
        return Util.fail('proximity_failed')
    end
    if not Auth.canManage(ctx, player, req.propertyId) then
        return Util.fail('not_authorised')
    end
    local row = ctx.repo.getFurniture(req.furnitureId)
    if not row or row.property_id ~= req.propertyId or row.state == 'removed' then
        return Util.fail('not_found')
    end
    local def = furnitureDef(ctx, row.catalog_id)
    if not def or def.model ~= row.model then
        return Util.fail('not_found')
    end
    ctx.repo.updateFurniture(row.id, { state = 'placed', offset_json = req.offset })
    return Util.ok({ furnitureId = row.id, model = row.model, offset = req.offset })
end

function Services.buyUpgrade(ctx, source, raw)
    if type(raw) ~= 'table' then
        return Util.fail('invalid_payload')
    end
    local idOk, propertyId = Validation.identifier(raw.propertyId or '')
    if not idOk then
        return Util.fail('invalid_payload')
    end
    local def = upgradeDef(ctx, raw.upgradeId)
    if not def then
        return Util.fail('not_found')
    end
    local player = ctx.framework.getPlayer(source)
    if not player then
        return Util.fail('player_not_found')
    end
    local role = Auth.resolveRole(ctx, player, propertyId)
    if role ~= 'owner' and role ~= 'tenant' then
        return Util.fail('not_authorised')
    end
    local owned = ctx.repo.listUpgrades(propertyId)
    for index = 1, #owned do
        if owned[index].upgrade_id == def.id then
            return Util.fail('already_owned')
        end
    end
    if not ctx.lockCharacter(player.characterId) then
        return Util.fail('busy')
    end
    local taken, state = ctx.framework.removeMoney(source, ctx.config.account, def.price, 'housing_upgrade:' .. def.id)
    if taken ~= true then
        ctx.unlockCharacter(player.characterId)
        return Util.fail(state == 'uncertain' and 'needs_review' or 'insufficient_funds')
    end
    local inserted = ctx.repo.insertUpgrade({
        property_id = propertyId,
        upgrade_id = def.id,
        purchased_at = ctx.now(),
        purchased_by = player.characterId,
    })
    ctx.unlockCharacter(player.characterId)
    if not inserted then
        ctx.framework.addMoney(source, ctx.config.account, def.price, 'housing_upgrade_refund:' .. def.id)
        return Util.fail('already_owned')
    end
    return Util.ok({ upgradeId = def.id })
end

function Services.storeVehicle(ctx, source, propertyId)
    local idOk, id = Validation.identifier(propertyId or '')
    if not idOk then
        return Util.fail('invalid_payload')
    end
    local player = ctx.framework.getPlayer(source)
    if not player then
        return Util.fail('player_not_found')
    end
    local property = ctx.repo.getProperty(id)
    if not property then
        return Util.fail('property_not_found')
    end
    local role = Auth.resolveRole(ctx, player, id)
    if role ~= 'owner' and role ~= 'tenant' and role ~= 'coowner' and role ~= 'resident' then
        return Util.fail('not_authorised')
    end
    if not Auth.near(ctx, source, property, 'garage') then
        return Util.fail('proximity_failed')
    end
    local slots = garageSlots(ctx, property)
    if slots < 1 then
        return Util.fail('garage_unavailable')
    end
    if ctx.repo.countStoredVehicles(id) >= slots then
        return Util.fail('garage_full')
    end
    local vehicle = ctx.vehicle and ctx.vehicle(source) or nil
    if not vehicle or type(vehicle.plate) ~= 'string' or type(vehicle.modelHash) ~= 'number' then
        return Util.fail('vehicle_missing')
    end
    if ctx.repo.getVehicleByPlate(id, vehicle.plate) then
        return Util.fail('duplicate_request')
    end
    local vehicleId = ctx.ids()
    ctx.repo.insertVehicle({
        id = vehicleId,
        property_id = id,
        framework = player.framework,
        character_id = player.characterId,
        plate = vehicle.plate,
        model_hash = vehicle.modelHash,
        state = 'stored',
        stored_at = ctx.now(),
    })
    return Util.ok({ vehicleId = vehicleId, plate = vehicle.plate, modelHash = vehicle.modelHash })
end

function Services.takeVehicle(ctx, source, raw)
    if type(raw) ~= 'table' then
        return Util.fail('invalid_payload')
    end
    local idOk, propertyId = Validation.identifier(raw.propertyId or '')
    if not idOk or type(raw.vehicleId) ~= 'string' then
        return Util.fail('invalid_payload')
    end
    local player = ctx.framework.getPlayer(source)
    if not player then
        return Util.fail('player_not_found')
    end
    local property = ctx.repo.getProperty(propertyId)
    if not property or not Auth.near(ctx, source, property, 'garage') then
        return Util.fail('proximity_failed')
    end
    local role = Auth.resolveRole(ctx, player, propertyId)
    if role ~= 'owner' and role ~= 'tenant' and role ~= 'coowner' and role ~= 'resident' then
        return Util.fail('not_authorised')
    end
    local vehicles = ctx.repo.listVehicles(propertyId)
    local match
    for index = 1, #vehicles do
        if vehicles[index].id == raw.vehicleId then
            match = vehicles[index]
        end
    end
    if not match or match.state ~= 'stored' then
        return Util.fail('not_found')
    end
    ctx.repo.updateVehicle(match.id, { state = 'out' })
    return Util.ok({ vehicleId = match.id, plate = match.plate, modelHash = match.model_hash, garage = property.garage })
end

function Services.restoreVehicle(ctx, source, raw)
    if type(raw) ~= 'table' or type(raw.vehicleId) ~= 'string' then
        return Util.fail('invalid_payload')
    end
    local player = ctx.framework.getPlayer(source)
    if not player then
        return Util.fail('player_not_found')
    end
    local vehicles = ctx.repo.listVehicles(raw.propertyId)
    for index = 1, #vehicles do
        local row = vehicles[index]
        if row.id == raw.vehicleId and row.state == 'out' and row.character_id == player.characterId then
            ctx.repo.updateVehicle(row.id, { state = 'stored' })
            return Util.ok({ vehicleId = row.id })
        end
    end
    return Util.fail('not_found')
end

function Services.setPropertyEnabled(ctx, source, propertyId, enabled)
    if not ctx.isAdmin or not ctx.isAdmin(source) then
        return Util.fail('not_authorised')
    end
    local idOk, id = Validation.identifier(propertyId or '')
    if not idOk then
        return Util.fail('invalid_payload')
    end
    local property = ctx.repo.getProperty(id)
    if not property then
        return Util.fail('property_not_found')
    end
    local fields = { enabled = enabled and 1 or 0 }
    if not enabled and (property.status == 'available' or property.status == 'disabled') then
        fields.status = 'disabled'
    end
    if enabled and property.status == 'disabled' then
        fields.status = 'available'
    end
    ctx.repo.updateProperty(id, fields)
    return Util.ok({ propertyId = id, enabled = enabled and true or false })
end

function Services.archiveProperty(ctx, source, raw)
    if not ctx.isAdmin or not ctx.isAdmin(source) then
        return Util.fail('not_authorised')
    end
    if type(raw) ~= 'table' then
        return Util.fail('invalid_payload')
    end
    local property = ctx.repo.getProperty(raw.propertyId)
    if not property then
        return Util.fail('property_not_found')
    end
    local ownership = ctx.repo.getOwnership(property.id)
    if ownership and raw.force ~= true then
        return Util.fail('owned')
    end
    if ownership and raw.force == true then
        ctx.repo.clearOwnership(property.id)
        ctx.repo.revokeKeysForProperty(property.id, ctx.now(), 'archive')
        ctx.repo.revokeAllAccess(property.id, ctx.now(), 'archive')
    end
    ctx.repo.updateProperty(property.id, { status = 'archived', enabled = 0, listed = 0 })
    Auth.audit(ctx, {
        category = 'admin',
        action_name = 'archived',
        framework = 'admin',
        actor_character_id = ctx.framework.getPlayer(source).characterId,
        property_id = property.id,
        detail_json = { force = raw.force == true },
    })
    return Util.ok({ propertyId = property.id })
end

function Services.adminTransfer(ctx, source, raw)
    if not ctx.isAdmin or not ctx.isAdmin(source) then
        return Util.fail('not_authorised')
    end
    if type(raw) ~= 'table' or type(raw.targetSource) ~= 'number' then
        return Util.fail('invalid_payload')
    end
    local property = ctx.repo.getProperty(raw.propertyId)
    local target = ctx.framework.getPlayer(raw.targetSource)
    if not property or not target then
        return Util.fail('not_found')
    end
    ctx.repo.revokeKeysForProperty(property.id, ctx.now(), 'admin_transfer')
    ctx.repo.revokeAllAccess(property.id, ctx.now(), 'admin_transfer')
    ctx.repo.setOwnership({
        property_id = property.id,
        framework = target.framework,
        character_id = target.characterId,
        display_name = target.name,
        purchased_at = ctx.now(),
        purchase_price = property.purchase_price,
        acquisition = 'admin',
        shell_model = property.shell_model,
    })
    ctx.repo.upsertAccess({
        property_id = property.id,
        framework = target.framework,
        character_id = target.characterId,
        display_name = target.name,
        role = 'owner',
        granted_by = 'admin',
        granted_at = ctx.now(),
        expires_at = nil,
        revoked_at = nil,
        revoked_by = nil,
    })
    ctx.repo.updateProperty(property.id, { status = 'owned', enabled = 1, listed = 0, listing_price = Housing.Null })
    return Util.ok({ propertyId = property.id, characterId = target.characterId })
end

function Services.createBillCycle(ctx)
    local properties = ctx.repo.listProperties()
    local created = 0
    for index = 1, #properties do
        local property = properties[index]
        if property.status == 'owned' or property.status == 'rented' then
            local bills = ctx.repo.listBills(property.id)
            for billType, rate in pairs(ctx.config.housing.billRates or {}) do
                local latest = 0
                for billIndex = 1, #bills do
                    if bills[billIndex].bill_type == billType and bills[billIndex].due_at > latest then
                        latest = bills[billIndex].due_at
                    end
                end
                if latest <= ctx.now() then
                    local amount = rate.amount or math.floor(property.purchase_price * (rate.percentOfValueBps or 0) / 10000)
                    if amount > 0 then
                        ctx.repo.insertBill({
                            id = ctx.ids(),
                            property_id = property.id,
                            bill_type = billType,
                            label = rate.label or billType,
                            amount = amount,
                            status = 'due',
                            due_at = ctx.now() + ((rate.intervalHours or 168) * 3600),
                            paid_at = nil,
                            paid_by = nil,
                        })
                        created = created + 1
                    end
                end
            end
        end
    end
    return created
end

function Services.repairProperty(ctx, source, propertyId)
    if not ctx.isAdmin or not ctx.isAdmin(source) then
        return Util.fail('not_authorised')
    end
    local idOk, id = Validation.identifier(propertyId or '')
    if not idOk then
        return Util.fail('invalid_payload')
    end
    local property = ctx.repo.getProperty(id)
    if not property then
        return Util.fail('property_not_found')
    end
    local actions = {}
    if property.status == 'reserved' then
        ctx.repo.casPropertyStatus(id, 'reserved', 'available', { reservation_token = Housing.Null, listed = 0 })
        actions[#actions + 1] = 'released_reservation'
    end
    if property.status == 'rented' and not ctx.repo.getActiveTenancy(id) then
        ctx.repo.casPropertyStatus(id, 'rented', 'available', { listed = 0 })
        ctx.repo.revokeKeysForProperty(id, ctx.now(), 'repair')
        ctx.repo.revokeAllAccess(id, ctx.now(), 'repair')
        actions[#actions + 1] = 'cleared_expired_tenancy'
    end
    Auth.audit(ctx, {
        category = 'admin',
        action_name = 'repaired',
        property_id = id,
        detail_json = { actions = actions },
    })
    return Util.ok({ propertyId = id, actions = actions })
end
