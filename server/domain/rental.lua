Housing = Housing or {}
Housing.Services = Housing.Services or {}

local Services = Housing.Services
local Validation = Housing.Validation
local Util = Housing.Util
local Auth = Housing.Auth
local Money = Housing.Money

local function withLock(ctx, player, fn)
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

function Services.rent(ctx, source, raw)
    local valid, req = Validation.purchaseRequest(raw or {})
    if not valid or req.mode ~= 'rent' then
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
    return withLock(ctx, player, function()
        local property = ctx.repo.getProperty(req.propertyId)
        if not property or property.enabled ~= 1 then
            return Util.fail(property and 'property_disabled' or 'property_not_found')
        end
        if property.status ~= 'available' then
            return Util.fail('property_unavailable')
        end
        local price = property.rental_price
        local period = property.rental_period_hours
        if type(price) ~= 'number' or price < 0 or type(period) ~= 'number' or period < 1 then
            return Util.fail('invalid_price')
        end
        if req.expectedPrice ~= nil and req.expectedPrice ~= price then
            return Util.fail('price_mismatch', { price = price })
        end
        local token = ctx.ids()
        if not Money.open(ctx, player, {
            idempotencyKey = req.idempotencyKey,
            propertyId = property.id,
            txType = 'rent',
            amount = price,
            token = token,
        }) then
            return Util.fail('duplicate_request')
        end
        if not Money.reserve(ctx, property, token, 'available', nil) then
            return Money.fail(ctx, req.idempotencyKey, 'property_unavailable')
        end
        local taken, state = Money.take(ctx, source, req.idempotencyKey, price, 'housing_rent:' .. property.id)
        if taken ~= true then
            if state ~= 'uncertain' then
                Money.release(ctx, property.id, token, 'available', { listed = 0 })
                return Util.fail('insufficient_funds')
            end
            return Util.fail('needs_review')
        end
        local tenancyId = ctx.ids()
        local switched = ctx.repo.casPropertyStatus(property.id, 'reserved', 'rented', {
            reservation_token = Housing.Null,
            listed = 0,
        }, { reservation_token = token })
        if not switched then
            local refunded = Money.refund(ctx, source, req.idempotencyKey, price, 'housing_refund:' .. property.id, 'reservation_lost')
            if refunded then
                Money.release(ctx, property.id, token, 'available', { listed = 0 })
            end
            return Util.fail(refunded and 'reservation_lost' or 'needs_review')
        end
        ctx.repo.insertTenancy({
            id = tenancyId,
            property_id = property.id,
            framework = player.framework,
            character_id = player.characterId,
            display_name = player.name,
            started_at = ctx.now(),
            expires_at = ctx.now() + (period * 3600),
            price_paid = price,
            status = 'active',
        })
        ctx.repo.upsertAccess({
            property_id = property.id,
            framework = player.framework,
            character_id = player.characterId,
            display_name = player.name,
            role = 'resident',
            granted_by = player.characterId,
            granted_at = ctx.now(),
            expires_at = ctx.now() + (period * 3600),
            revoked_at = nil,
            revoked_by = nil,
        })
        ctx.repo.insertBill({
            id = ctx.ids(),
            property_id = property.id,
            bill_type = 'rent',
            label = 'Rent',
            amount = price,
            status = 'paid',
            due_at = ctx.now(),
            paid_at = ctx.now(),
            paid_by = player.characterId,
        })
        ctx.repo.casTransaction(req.idempotencyKey, 'taken', { status = 'completed', grant_state = 'granted' })
        Auth.audit(ctx, {
            category = 'rental',
            action_name = 'started',
            framework = player.framework,
            actor_character_id = player.characterId,
            property_id = property.id,
            detail_json = { amount = price, tenancyId = tenancyId, periodHours = period },
        })
        return Util.ok({
            propertyId = property.id,
            tenancyId = tenancyId,
            expiresAt = ctx.now() + (period * 3600),
            price = price,
        })
    end)
end

function Services.renewRent(ctx, source, raw)
    local valid, req = Validation.purchaseRequest(raw or {})
    if not valid or req.mode ~= 'renew' then
        return Util.fail('invalid_payload', valid and 'mode' or req)
    end
    local player = ctx.framework.getPlayer(source)
    if not player then
        return Util.fail('player_not_found')
    end
    local existing = ctx.repo.getTransaction(req.idempotencyKey)
    if existing then
        return Money.replay(ctx, existing, player)
    end
    return withLock(ctx, player, function()
        local property = ctx.repo.getProperty(req.propertyId)
        local tenancy = property and ctx.repo.getActiveTenancy(property.id) or nil
        if not property or property.status ~= 'rented' or not tenancy then
            return Util.fail('property_unavailable')
        end
        if tenancy.framework ~= player.framework or tenancy.character_id ~= player.characterId then
            return Util.fail('not_authorised')
        end
        local price = property.rental_price
        local period = property.rental_period_hours
        if req.expectedPrice ~= nil and req.expectedPrice ~= price then
            return Util.fail('price_mismatch', { price = price })
        end
        local token = ctx.ids()
        if not Money.open(ctx, player, {
            idempotencyKey = req.idempotencyKey,
            propertyId = property.id,
            txType = 'rent_renew',
            amount = price,
            token = token,
        }) then
            return Util.fail('duplicate_request')
        end
        local taken, state = Money.take(ctx, source, req.idempotencyKey, price, 'housing_rent_renew:' .. property.id)
        if taken ~= true then
            return Util.fail(state == 'uncertain' and 'needs_review' or 'insufficient_funds')
        end
        local base = math.max(tenancy.expires_at, ctx.now())
        local updated = ctx.repo.casTenancy(tenancy.id, 'active', { expires_at = base + (period * 3600), price_paid = tenancy.price_paid + price })
        if not updated then
            Money.refund(ctx, source, req.idempotencyKey, price, 'housing_refund:' .. property.id, 'renew_failed')
            return Util.fail('renew_failed')
        end
        ctx.repo.upsertAccess({
            property_id = property.id,
            framework = player.framework,
            character_id = player.characterId,
            display_name = player.name,
            role = 'resident',
            granted_by = player.characterId,
            granted_at = ctx.now(),
            expires_at = base + (period * 3600),
            revoked_at = nil,
            revoked_by = nil,
        })
        ctx.repo.casTransaction(req.idempotencyKey, 'taken', { status = 'completed', grant_state = 'granted' })
        return Util.ok({ propertyId = property.id, expiresAt = base + (period * 3600), price = price })
    end)
end

function Services.expireRentals(ctx)
    local expired = ctx.repo.expireDueTenancies(ctx.now())
    local count = 0
    for index = 1, #expired do
        local tenancy = expired[index]
        local property = ctx.repo.getProperty(tenancy.property_id)
        if property and property.status == 'rented' then
            local cleared = ctx.repo.casPropertyStatus(property.id, 'rented', 'available', { listed = 0 })
            if cleared then
                ctx.repo.revokeKeysForProperty(property.id, ctx.now(), 'rental_expired')
                ctx.repo.revokeAllAccess(property.id, ctx.now(), 'rental_expired')
                Auth.audit(ctx, {
                    category = 'rental',
                    action_name = 'expired',
                    framework = tenancy.framework,
                    actor_character_id = tenancy.character_id,
                    property_id = property.id,
                    detail_json = { tenancyId = tenancy.id },
                })
                count = count + 1
            end
        end
    end
    return count
end
