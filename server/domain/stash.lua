Housing = Housing or {}
Housing.Services = Housing.Services or {}

local Services = Housing.Services
local Validation = Housing.Validation
local Util = Housing.Util
local Auth = Housing.Auth

local function weightFor(ctx, propertyId, stash)
    local weight = stash.max_weight
    local upgrades = ctx.repo.listUpgrades(propertyId)
    for index = 1, #upgrades do
        for catalogIndex = 1, #ctx.config.upgrades do
            local def = ctx.config.upgrades[catalogIndex]
            if def.id == upgrades[index].upgrade_id and def.effect and def.effect.stashWeightBonus and stash.stash_type == 'shared' then
                weight = weight + def.effect.stashWeightBonus
            end
        end
    end
    return weight
end

local function identifierFor(stash, propertyId, player)
    if stash.stash_type == 'personal' then
        return Util.stashIdentifier(propertyId, stash.stash_key, player.characterId)
    end
    return Util.stashIdentifier(propertyId, stash.stash_key, nil)
end

function Services.describeStash(ctx, propertyId, stash, player)
    return {
        key = stash.stash_key,
        label = stash.label,
        stashType = stash.stash_type,
        accessLevel = stash.access_level,
        slots = stash.slots,
        maxWeight = weightFor(ctx, propertyId, stash),
        identifier = player and identifierFor(stash, propertyId, player) or nil,
    }
end

function Services.openStash(ctx, source, raw)
    local valid, req = Validation.stashRequest(raw or {})
    if not valid then
        return Util.fail('invalid_payload', req)
    end
    if not ctx.rateLimiter.allow(ctx.playerKey(source), 'stash') then
        return Util.fail('rate_limited')
    end
    local player = ctx.framework.getPlayer(source)
    if not player then
        return Util.fail('player_not_found')
    end
    local property = ctx.repo.getProperty(req.propertyId)
    if not property or property.enabled ~= 1 or property.status == 'archived' or property.status == 'disabled' then
        return Util.fail('property_not_found')
    end
    local stash = ctx.repo.getStash(property.id, req.stashKey)
    if not stash or stash.property_id ~= property.id then
        return Util.fail('stash_not_found')
    end
    if not Auth.canOpenStash(ctx, player, property.id, stash) then
        return Util.fail('stash_forbidden')
    end
    if not Auth.near(ctx, source, property, 'stash') then
        return Util.fail('proximity_failed')
    end
    local stashId = identifierFor(stash, property.id, player)
    local registered, registerErr = ctx.inventory.registerStash({
        id = stashId,
        label = property.label .. ' / ' .. stash.label,
        slots = stash.slots,
        maxWeight = weightFor(ctx, property.id, stash),
        owner = stash.stash_type == 'personal' and player.characterId or nil,
    })
    if registered == false then
        return Util.fail('inventory_failed', registerErr)
    end
    local opened, openErr = ctx.inventory.openStash(source, stashId, {
        label = stash.label,
        slots = stash.slots,
        maxWeight = weightFor(ctx, property.id, stash),
    })
    if opened ~= true then
        return Util.fail(openErr or 'inventory_failed')
    end
    return Util.ok({ stashId = stashId, label = stash.label })
end
