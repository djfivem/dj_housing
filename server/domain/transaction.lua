Housing = Housing or {}
Housing.Services = Housing.Services or {}

local Services = Housing.Services
local Validation = Housing.Validation
local Util = Housing.Util
local Auth = Housing.Auth
local Money = Housing.Money

local function guarded(ctx, player, fn)
    if not ctx.lockCharacter(player.characterId) then
        return Util.fail('busy')
    end
    local ok, result = pcall(fn)
    ctx.unlockCharacter(player.characterId)
    if not ok then
        return Util.fail('internal_error', tostring(result))
    end
    return result
end

local function shellFor(ctx, property, requested)
    if property.property_type ~= 'shell' and property.property_type ~= 'apartment' then
        return property.shell_model
    end
    local options = property.shell_options
    if requested then
        if type(options) ~= 'table' or not Util.contains(options, requested) or not ctx.config.shells[requested] then
            return nil, 'shell_not_allowed'
        end
        return requested
    end
    if not property.shell_model or not ctx.config.shells[property.shell_model] then
        return nil, 'shell_not_configured'
    end
    return property.shell_model
end

local function createBills(ctx, property)
    local rates = ctx.config.housing.billRates or {}
    for billType, rate in pairs(rates) do
        local amount = rate.amount or 0
        if rate.percentOfValueBps then
            amount = math.floor(property.purchase_price * rate.percentOfValueBps / 10000)
        end
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
        end
    end
end

local function grantBuyer(ctx, property, player, token, price, shellModel, acquisition)
    local switched = ctx.repo.casPropertyStatus(property.id, 'reserved', 'owned', {
        reservation_token = Housing.Null,
        listed = 0,
        listing_price = Housing.Null,
    }, { reservation_token = token })
    if not switched then
        return false, 'reservation_lost'
    end
    ctx.repo.setOwnership({
        property_id = property.id,
        framework = player.framework,
        character_id = player.characterId,
        display_name = player.name,
        purchased_at = ctx.now(),
        purchase_price = price,
        acquisition = acquisition,
        shell_model = shellModel,
    })
    ctx.repo.revokeKeysForProperty(property.id, ctx.now(), player.characterId)
    ctx.repo.revokeAllAccess(property.id, ctx.now(), player.characterId)
    ctx.repo.upsertAccess({
        property_id = property.id,
        framework = player.framework,
        character_id = player.characterId,
        display_name = player.name,
        role = 'owner',
        granted_by = player.characterId,
        granted_at = ctx.now(),
        expires_at = nil,
        revoked_at = nil,
        revoked_by = nil,
    })
    return true
end

function Services.purchase(ctx, source, raw)
    local valid, req = Validation.purchaseRequest(raw or {})
    if not valid or req.mode ~= 'purchase' then
        return Util.fail('invalid_payload', valid and 'mode' or req)
    end
    if not ctx.rateLimiter.allow(ctx.playerKey(source), 'purchase') then
        return Util.fail('rate_limited')
    end
    local player = ctx.framework.getPlayer(source)
    if not player then
        return Util.fail('player_not_found')
    end
    local existing = ctx.repo.getTransaction(req.idempotencyKey)
    if existing then
        return Money.replay(ctx, existing, player)
    end
    return guarded(ctx, player, function()
        local property = ctx.repo.getProperty(req.propertyId)
        if not property then
            return Util.fail('property_not_found')
        end
        if property.enabled ~= 1 then
            return Util.fail('property_disabled')
        end
        local listed = property.listed == 1
        local price
        local seller
        if listed then
            price = property.listing_price
            seller = ctx.repo.getOwnership(property.id)
            if property.status ~= 'owned' or not seller or not price then
                return Util.fail('property_unavailable')
            end
            if seller.framework == player.framework and seller.character_id == player.characterId then
                return Util.fail('already_owner')
            end
        else
            if property.status ~= 'available' then
                return Util.fail('property_unavailable')
            end
            price = property.purchase_price
        end
        if type(price) ~= 'number' or price < 0 or price > Housing.Limits.maxPrice then
            return Util.fail('invalid_price')
        end
        if req.expectedPrice ~= nil and req.expectedPrice ~= price then
            return Util.fail('price_mismatch', { price = price })
        end
        if not listed and ctx.config.permissions.maxOwned then
            if ctx.repo.countOwnership(player.framework, player.characterId) >= ctx.config.permissions.maxOwned then
                return Util.fail('ownership_limit')
            end
        end
        local shellModel, shellErr = shellFor(ctx, property, req.shellModel)
        if not shellModel and shellErr then
            return Util.fail(shellErr)
        end
        local token = ctx.ids()
        local opened = Money.open(ctx, player, {
            idempotencyKey = req.idempotencyKey,
            propertyId = property.id,
            txType = listed and 'resale_purchase' or 'purchase',
            amount = price,
            token = token,
        })
        if not opened then
            return Util.fail('duplicate_request')
        end
        local reserved = Money.reserve(ctx, property, token, listed and 'owned' or 'available', listed and { listed = 1 } or nil)
        if not reserved then
            return Money.fail(ctx, req.idempotencyKey, 'property_unavailable')
        end
        if ctx.hooks and ctx.hooks.afterReserve then
            ctx.hooks.afterReserve()
        end
        local taken, state = Money.take(ctx, source, req.idempotencyKey, price, 'housing_purchase:' .. property.id)
        if taken ~= true then
            if state == 'uncertain' then
                return Util.fail('needs_review')
            end
            Money.release(ctx, property.id, token, listed and 'owned' or 'available', listed and { listed = 1 } or { listed = 0 })
            return Util.fail('insufficient_funds')
        end
        if not listed and ctx.config.permissions.maxOwned and ctx.repo.countOwnership(player.framework, player.characterId) >= ctx.config.permissions.maxOwned then
            Money.refund(ctx, source, req.idempotencyKey, price, 'housing_refund:' .. property.id, 'ownership_limit')
            Money.release(ctx, property.id, token, 'available', { listed = 0 })
            return Util.fail('ownership_limit')
        end
        local granted, grantErr = grantBuyer(ctx, property, player, token, price, shellModel, listed and 'transfer' or 'purchase')
        if not granted then
            local refunded = Money.refund(ctx, source, req.idempotencyKey, price, 'housing_refund:' .. property.id, grantErr)
            if refunded then
                Money.release(ctx, property.id, token, listed and 'owned' or 'available', listed and { listed = 1 } or { listed = 0 })
            end
            return Util.fail(refunded and grantErr or 'needs_review')
        end
        ctx.repo.casTransaction(req.idempotencyKey, 'taken', { status = 'completed', grant_state = 'granted' })
        createBills(ctx, property)
        if seller and price > 0 then
            Services._payCharacter(ctx, seller.framework, seller.character_id, price, 'housing_sale:' .. property.id, property.id)
        end
        Auth.audit(ctx, {
            category = 'transaction',
            action_name = 'purchase',
            framework = player.framework,
            actor_character_id = player.characterId,
            property_id = property.id,
            detail_json = { amount = price, seller = seller and seller.character_id or nil },
        })
        local keyResult = Services.issueKey(ctx, source, {
            propertyId = property.id,
            idempotencyKey = ctx.ids(),
            accessLevel = 'owner',
            targetSource = source,
            asPurchase = true,
        })
        return Util.ok({
            propertyId = property.id,
            transactionId = req.idempotencyKey,
            price = price,
            key = keyResult,
        })
    end)
end

function Services._payCharacter(ctx, framework, characterId, amount, reason, propertyId)
    local payoutId = ctx.ids()
    ctx.repo.insertPayout({
        id = payoutId,
        framework = framework,
        character_id = characterId,
        amount = amount,
        account_name = ctx.config.account,
        reason_text = reason,
        status = 'pending',
        property_id = propertyId,
        created_at = ctx.now(),
        paid_at = nil,
    })
    local target = ctx.framework.getSourceByCharacter(framework, characterId)
    if not target then
        return false
    end
    local paid = ctx.framework.addMoney(target, ctx.config.account, amount, reason)
    if paid ~= true then
        Auth.audit(ctx, {
            category = 'transaction',
            action_name = 'payout_failed',
            framework = framework,
            actor_character_id = characterId,
            property_id = propertyId,
            detail_json = { amount = amount, payoutId = payoutId },
        })
        return false
    end
    ctx.repo.casPayout(payoutId, 'pending', { status = 'paid', paid_at = ctx.now() })
    return true
end

function Services.collectPayouts(ctx, source)
    local player = ctx.framework.getPlayer(source)
    if not player then
        return Util.fail('player_not_found')
    end
    local pending = ctx.repo.listPendingPayouts(player.framework, player.characterId)
    local paid = 0
    for index = 1, #pending do
        local row = pending[index]
        local locked = ctx.repo.casPayout(row.id, 'pending', { status = 'paying' })
        if locked then
            local ok = ctx.framework.addMoney(source, row.account_name, row.amount, row.reason_text)
            if ok == true then
                ctx.repo.casPayout(row.id, 'paying', { status = 'paid', paid_at = ctx.now() })
                paid = paid + row.amount
            else
                ctx.repo.casPayout(row.id, 'paying', { status = 'pending' })
            end
        end
    end
    return Util.ok({ amount = paid })
end

function Services.listProperty(ctx, source, raw)
    if type(raw) ~= 'table' then
        return Util.fail('invalid_payload')
    end
    local idOk, propertyId = Validation.identifier(raw.propertyId)
    if not idOk then
        return Util.fail('invalid_payload')
    end
    local priceOk, price = Validation.money(raw.price or -1)
    if not priceOk then
        return Util.fail('invalid_price')
    end
    if price < ctx.config.housing.minListingPrice then
        return Util.fail('invalid_price')
    end
    local player = ctx.framework.getPlayer(source)
    if not player then
        return Util.fail('player_not_found')
    end
    local property = ctx.repo.getProperty(propertyId)
    if not property or property.status ~= 'owned' then
        return Util.fail('property_unavailable')
    end
    local ownership = ctx.repo.getOwnership(propertyId)
    if not ownership or ownership.character_id ~= player.characterId or ownership.framework ~= player.framework then
        return Util.fail('not_authorised')
    end
    local cap = math.floor(property.purchase_price * (ctx.config.housing.maxListingPercent or 300) / 100)
    if property.purchase_price > 0 and price > math.max(cap, ctx.config.housing.minListingPrice) then
        return Util.fail('invalid_price')
    end
    ctx.repo.updateProperty(propertyId, { listed = 1, listing_price = price })
    Auth.audit(ctx, {
        category = 'transaction',
        action_name = 'listed',
        framework = player.framework,
        actor_character_id = player.characterId,
        property_id = propertyId,
        detail_json = { price = price },
    })
    return Util.ok({ propertyId = propertyId, price = price })
end

function Services.unlistProperty(ctx, source, propertyId)
    local idOk, id = Validation.identifier(propertyId)
    if not idOk then
        return Util.fail('invalid_payload')
    end
    local player = ctx.framework.getPlayer(source)
    if not player then
        return Util.fail('player_not_found')
    end
    local ownership = ctx.repo.getOwnership(id)
    if not ownership or ownership.character_id ~= player.characterId or ownership.framework ~= player.framework then
        return Util.fail('not_authorised')
    end
    local property = ctx.repo.getProperty(id)
    if not property or property.status ~= 'owned' then
        return Util.fail('property_unavailable')
    end
    ctx.repo.updateProperty(id, { listed = 0, listing_price = Housing.Null })
    return Util.ok({ propertyId = id })
end

function Services.sellToState(ctx, source, raw)
    local valid, req = Validation.purchaseRequest(raw or {})
    if not valid then
        return Util.fail('invalid_payload', req)
    end
    local player = ctx.framework.getPlayer(source)
    if not player then
        return Util.fail('player_not_found')
    end
    if not ctx.rateLimiter.allow(ctx.playerKey(source), 'purchase') then
        return Util.fail('rate_limited')
    end
    local existing = ctx.repo.getTransaction(req.idempotencyKey)
    if existing then
        return Money.replay(ctx, existing, player)
    end
    return guarded(ctx, player, function()
        local property = ctx.repo.getProperty(req.propertyId)
        local ownership = property and ctx.repo.getOwnership(property.id) or nil
        if not property or not ownership or property.status ~= 'owned' or property.enabled ~= 1 then
            return Util.fail('property_unavailable')
        end
        if ownership.framework ~= player.framework or ownership.character_id ~= player.characterId then
            return Util.fail('not_authorised')
        end
        local percent = ctx.config.housing.saleReturnPercent or 0
        local price = math.floor(property.purchase_price * percent / 100)
        if req.expectedPrice ~= nil and req.expectedPrice ~= price then
            return Util.fail('price_mismatch', { price = price })
        end
        local token = ctx.ids()
        local opened = Money.open(ctx, player, {
            idempotencyKey = req.idempotencyKey,
            propertyId = property.id,
            txType = 'sell_to_state',
            amount = price,
            token = token,
        })
        if not opened then
            return Util.fail('duplicate_request')
        end
        ctx.repo.casTransaction(req.idempotencyKey, 'taking', { money_state = 'taken', grant_state = 'not_granted' })
        local reserved = Money.reserve(ctx, property, token, 'owned', nil)
        if not reserved then
            ctx.repo.casTransaction(req.idempotencyKey, 'taken', { status = 'failed', money_state = 'not_taken', error_code = 'property_unavailable' })
            return Util.fail('property_unavailable')
        end
        local payoutId = ctx.ids()
        ctx.repo.insertPayout({
            id = payoutId,
            framework = player.framework,
            character_id = player.characterId,
            amount = price,
            account_name = ctx.config.account,
            reason_text = 'housing_sale:' .. property.id,
            status = 'pending',
            property_id = property.id,
            created_at = ctx.now(),
        })
        ctx.repo.clearOwnership(property.id)
        ctx.repo.revokeKeysForProperty(property.id, ctx.now(), 'state')
        ctx.repo.revokeAllAccess(property.id, ctx.now(), 'state')
        local released = ctx.repo.casPropertyStatus(property.id, 'reserved', 'available', {
            reservation_token = Housing.Null,
            listed = 0,
            listing_price = Housing.Null,
        }, { reservation_token = token })
        if not released then
            ctx.repo.casTransaction(req.idempotencyKey, 'taken', { status = 'needs_review', error_code = 'release_failed' })
            return Util.fail('needs_review')
        end
        ctx.repo.casTransaction(req.idempotencyKey, 'taken', { status = 'completed', grant_state = 'granted' })
        if price > 0 then
            local paid = ctx.framework.addMoney(source, ctx.config.account, price, 'housing_sale:' .. property.id)
            if paid == true then
                ctx.repo.casPayout(payoutId, 'pending', { status = 'paid', paid_at = ctx.now() })
            end
        else
            ctx.repo.casPayout(payoutId, 'pending', { status = 'paid', paid_at = ctx.now() })
        end
        Auth.audit(ctx, {
            category = 'transaction',
            action_name = 'sell_to_state',
            framework = player.framework,
            actor_character_id = player.characterId,
            property_id = property.id,
            detail_json = { amount = price },
        })
        return Util.ok({ propertyId = property.id, price = price, transactionId = req.idempotencyKey })
    end)
end
