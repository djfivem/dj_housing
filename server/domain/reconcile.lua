Housing = Housing or {}
Housing.Services = Housing.Services or {}

local Services = Housing.Services
local Money = Housing.Money

function Services.reconcile(ctx)
    local rows = ctx.repo.listPendingTransactions()
    local report = { released = 0, reviewed = 0, refunded = 0 }
    local timeout = ctx.config.reservationTimeoutSeconds or 180
    for index = 1, #rows do
        local tx = rows[index]
        if ctx.now() - (tx.updated_at or tx.created_at) < timeout then
            goto continue
        end
        local property = ctx.repo.getProperty(tx.property_id)
        if tx.money_state == 'not_taken' then
            if property and property.status == 'reserved' and property.reservation_token == tx.reservation_token then
                Money.release(ctx, property.id, tx.reservation_token, tx.tx_type == 'rent' and 'available' or 'available', { listed = 0 })
                report.released = report.released + 1
            end
            ctx.repo.casTransaction(tx.id, 'not_taken', { status = 'failed', error_code = 'timed_out' })
        elseif tx.money_state == 'taking' or tx.money_state == 'uncertain' or tx.money_state == 'refunding' then
            ctx.repo.casTransaction(tx.id, tx.money_state, { status = 'needs_review', error_code = 'timed_out' })
            report.reviewed = report.reviewed + 1
        elseif tx.money_state == 'taken' and tx.grant_state ~= 'granted' then
            if property and property.status == 'reserved' and property.reservation_token == tx.reservation_token then
                local source = ctx.framework.getSourceByCharacter(tx.framework, tx.actor_character_id)
                if source then
                    local refunded = Money.refund(ctx, source, tx.id, tx.amount, 'housing_reconcile:' .. tx.property_id, 'timed_out')
                    if refunded then
                        Money.release(ctx, property.id, tx.reservation_token, 'available', { listed = 0 })
                        report.refunded = report.refunded + 1
                    else
                        report.reviewed = report.reviewed + 1
                    end
                else
                    ctx.repo.casTransaction(tx.id, 'taken', { status = 'needs_review', error_code = 'actor_offline' })
                    report.reviewed = report.reviewed + 1
                end
            else
                ctx.repo.casTransaction(tx.id, 'taken', { status = 'needs_review', error_code = 'reservation_missing' })
                report.reviewed = report.reviewed + 1
            end
        end
        ::continue::
    end
    local raids = ctx.repo.listRaids()
    for index = 1, #raids do
        local raid = raids[index]
        if Housing.OpenRaidStates[raid.state] then
            local warrant = raid.warrant_id and ctx.repo.getWarrant(raid.warrant_id) or nil
            if warrant and warrant.expires_at <= ctx.now() and raid.state ~= 'active' then
                ctx.repo.casRaid(raid.id, raid.state, { state = 'expired', ended_at = ctx.now() })
                ctx.repo.casWarrant(warrant.id, warrant.status, { status = 'expired' })
            end
        end
    end
    return report
end

function Services.diagnostics(ctx)
    local properties = ctx.repo.listProperties()
    local pending = ctx.repo.listPendingTransactions()
    return {
        propertyCount = #properties,
        pendingTransactions = #pending,
        framework = ctx.framework.name,
        inventory = ctx.inventory and ctx.inventory.name or 'none',
    }
end
