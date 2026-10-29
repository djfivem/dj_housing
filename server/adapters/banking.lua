Housing = Housing or {}
Housing.Banking = Housing.Banking or {}

local order = {
    { id = 'renewed', resource = 'Renewed-Banking' },
    { id = 'qb-banking', resource = 'qb-banking' },
    { id = 'okokBanking', resource = 'okokBanking' },
}

local function idle(report)
    return {
        name = 'none',
        liveVerified = false,
        report = report or 'none',
        record = function()
            return false, 'banking_unavailable'
        end,
    }
end

function Housing.Banking.bind(config, env)
    local setting = (config.Integrations.banking or {}).system or 'none'
    if setting == 'none' then
        return idle('none')
    end
    local chosen
    if setting == 'auto' then
        for index = 1, #order do
            if env.getResourceState(order[index].resource) == 'started' then
                chosen = order[index]
                break
            end
        end
    else
        for index = 1, #order do
            if order[index].id == setting then
                chosen = order[index]
            end
        end
    end
    if not chosen or env.getResourceState(chosen.resource) ~= 'started' then
        return idle(chosen and (chosen.id .. ' is not started') or 'none')
    end
    local account = config.Account or 'bank'
    local call
    if chosen.id == 'renewed' then
        call = function(source, player, bill)
            return env.exports['Renewed-Banking'].handleTransaction(
                player.characterId,
                bill.label or 'Housing bill',
                bill.amount,
                'Housing ' .. (bill.label or bill.bill_type or 'bill'),
                'Housing',
                player.characterId,
                'withdraw'
            )
        end
    elseif chosen.id == 'qb-banking' then
        call = function(source, player, bill)
            return env.exports['qb-banking'].CreateBankStatement(
                source,
                account,
                bill.amount,
                'Housing ' .. (bill.label or bill.bill_type or 'bill'),
                'withdraw',
                'player'
            )
        end
    else
        call = function(source, player, bill)
            return env.exports['okokBanking'].AddTransaction(player.characterId, {
                sender_identifier = player.characterId,
                sender_name = player.name,
                receiver_identifier = 'housing',
                receiver_name = 'Housing',
                value = bill.amount,
                type = 'withdraw',
                reason = 'Housing ' .. (bill.label or bill.bill_type or 'bill'),
            }, source)
        end
    end
    return {
        name = chosen.id,
        liveVerified = false,
        report = chosen.id .. ' statement only (not executed in this environment)',
        record = function(source, player, bill)
            local ok, err = pcall(call, source, player, bill)
            if not ok then
                return false, err
            end
            return true
        end,
    }
end
