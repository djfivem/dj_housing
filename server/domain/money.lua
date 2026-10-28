Housing = Housing or {}
Housing.Money = Housing.Money or {}

local Money = Housing.Money
local Util = Housing.Util

function Money.fail(ctx, txId, code)
    ctx.repo.casTransaction(txId, 'not_taken', {
        status = 'failed',
        error_code = code,
    })
    return Util.fail(code)
end

function Money.reserve(ctx, property, token, fromStatus, where)
    return ctx.repo.casPropertyStatus(property.id, fromStatus, 'reserved', {
        reservation_token = token,
    }, where)
end

function Money.release(ctx, propertyId, token, restoreStatus, fields)
    fields = fields or {}
    fields.reservation_token = Housing.Null
    return ctx.repo.casPropertyStatus(propertyId, 'reserved', restoreStatus, fields, {
        reservation_token = token,
    })
end

function Money.take(ctx, source, txId, amount, reason)
    if amount == 0 then
        local marked = ctx.repo.casTransaction(txId, 'taking', { money_state = 'taken' })
        if not marked then
            return nil, 'uncertain'
        end
        return true
    end
    local moved, state = ctx.framework.removeMoney(source, ctx.config.account, amount, reason)
    if moved ~= true then
        if state == 'uncertain' then
            ctx.repo.casTransaction(txId, 'taking', {
                status = 'needs_review',
                money_state = 'uncertain',
                error_code = 'money_uncertain',
            })
            return nil, 'uncertain'
        end
        ctx.repo.casTransaction(txId, 'taking', {
            status = 'failed',
            money_state = 'not_taken',
            error_code = 'insufficient_funds',
        })
        return false
    end
    local marked = ctx.repo.casTransaction(txId, 'taking', { money_state = 'taken' })
    if not marked then
        return nil, 'uncertain'
    end
    return true
end

function Money.refund(ctx, source, txId, amount, reason, errorCode)
    if amount == 0 then
        ctx.repo.casTransaction(txId, 'taken', {
            status = 'compensated',
            money_state = 'refunded',
            error_code = errorCode,
        })
        return true
    end
    local locking = ctx.repo.casTransaction(txId, 'taken', { money_state = 'refunding', error_code = errorCode })
    if not locking then
        ctx.repo.casTransaction(txId, 'uncertain', {
            status = 'needs_review',
            error_code = errorCode,
        })
        return false
    end
    local refunded, state = ctx.framework.addMoney(source, ctx.config.account, amount, reason)
    if refunded ~= true then
        ctx.repo.casTransaction(txId, 'refunding', {
            status = 'needs_review',
            money_state = state == 'uncertain' and 'uncertain' or 'taken',
            error_code = 'compensation_failed',
        })
        return false
    end
    ctx.repo.casTransaction(txId, 'refunding', {
        status = 'compensated',
        money_state = 'refunded',
        error_code = errorCode,
    })
    return true
end

function Money.open(ctx, player, spec)
    local inserted = ctx.repo.insertTransaction({
        id = spec.idempotencyKey,
        property_id = spec.propertyId,
        framework = player.framework,
        actor_character_id = player.characterId,
        tx_type = spec.txType,
        amount = spec.amount,
        account_name = ctx.config.account,
        status = 'pending',
        money_state = 'not_taken',
        grant_state = 'not_granted',
        reservation_token = spec.token,
        detail_json = spec.detail or {},
        created_at = ctx.now(),
        updated_at = ctx.now(),
    })
    if not inserted then
        return false
    end
    return ctx.repo.casTransaction(spec.idempotencyKey, 'not_taken', { money_state = 'taking' })
end

function Money.replay(ctx, existing, player)
    if existing.framework ~= player.framework or existing.actor_character_id ~= player.characterId then
        return Util.fail('duplicate_request')
    end
    if existing.status == 'completed' then
        return Util.ok({ replay = true, propertyId = existing.property_id, transactionId = existing.id })
    end
    if existing.status == 'pending' or existing.status == 'needs_review' then
        return Util.fail(existing.status == 'needs_review' and 'needs_review' or 'in_progress')
    end
    return Util.fail('duplicate_request')
end
