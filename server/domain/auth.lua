Housing = Housing or {}
Housing.Auth = Housing.Auth or {}

local Auth = Housing.Auth
local Util = Housing.Util

function Auth.isActiveAccess(row, now)
    if not row or row.revoked_at then
        return false
    end
    if row.expires_at and row.expires_at <= now then
        return false
    end
    return true
end

function Auth.resolveRole(ctx, player, propertyId)
    local ownership = ctx.repo.getOwnership(propertyId)
    if ownership and ownership.framework == player.framework and ownership.character_id == player.characterId then
        return 'owner'
    end
    local tenancy = ctx.repo.getActiveTenancy(propertyId)
    if tenancy and tenancy.framework == player.framework and tenancy.character_id == player.characterId and tenancy.expires_at > ctx.now() then
        return 'tenant'
    end
    local access = ctx.repo.getAccess(propertyId, player.framework, player.characterId)
    if Auth.isActiveAccess(access, ctx.now()) then
        return access.role
    end
    return nil
end

function Auth.canManage(ctx, player, propertyId)
    local role = Auth.resolveRole(ctx, player, propertyId)
    if role == 'owner' or role == 'tenant' then
        return true, role
    end
    if role == 'coowner' and ctx.config.permissions.allowCoOwner then
        return true, role
    end
    return false, role
end

function Auth.canEnter(ctx, player, propertyId)
    local role = Auth.resolveRole(ctx, player, propertyId)
    local perms = ctx.config.permissions
    if role == 'owner' or role == 'tenant' or role == 'coowner' or role == 'resident' then
        if perms.requirePhysicalKeyForEntry and not (role == 'owner' and perms.ownerBypassKey) and role ~= 'tenant' then
            return Auth.holdsKey(ctx, player, propertyId, 'guest')
        end
        return true
    end
    if role == 'guest' then
        if perms.guestsRequireKey then
            return Auth.holdsKey(ctx, player, propertyId, 'guest')
        end
        return true
    end
    return Auth.holdsKey(ctx, player, propertyId, 'guest')
end

function Auth.canOpenStash(ctx, player, propertyId, stash)
    local minimum = stash.access_level or 'resident'
    local role = Auth.resolveRole(ctx, player, propertyId)
    local effective = role
    if role == 'tenant' then
        effective = 'owner'
    end
    if effective and Housing.RoleAllows(effective, minimum) then
        if ctx.config.permissions.requirePhysicalKeyForStash and role ~= 'owner' and role ~= 'tenant' then
            return Auth.holdsKey(ctx, player, propertyId, minimum)
        end
        return true
    end
    if Auth.holdsKey(ctx, player, propertyId, minimum) then
        return true
    end
    return false
end

function Auth.holdsKey(ctx, player, propertyId, minimum)
    local items = ctx.inventory.search(player.source, ctx.config.keyItem) or {}
    for index = 1, #items do
        local metadata = items[index].metadata or items[index].info
        local keyId = metadata and metadata.keyId
        if type(keyId) == 'string' then
            local record = ctx.repo.getKey(keyId)
            if record
                and record.property_id == propertyId
                and record.holder_framework == player.framework
                and record.holder_character_id == player.characterId
                and record.state == 'active'
                and (not record.expires_at or record.expires_at > ctx.now())
                and Housing.RoleAllows(record.access_level, minimum)
            then
                return true, record
            end
        end
    end
    return false
end

function Auth.near(ctx, source, property, kind)
    if ctx.isAdmin and ctx.isAdmin(source) then
        return true
    end
    if ctx.instance and ctx.instance(source) == property.id and kind ~= 'garage' then
        return true
    end
    local position = ctx.position and ctx.position(source) or nil
    if not position then
        return false
    end
    local point = property.entrance
    local distance = ctx.config.performance.entranceDistance
    if kind == 'garage' and property.garage then
        point = property.garage
    elseif kind == 'stash' then
        distance = ctx.config.performance.stashDistance
    end
    return Util.distance(position, point) <= distance
end

function Auth.audit(ctx, entry)
    entry.created_at = ctx.now()
    ctx.repo.insertAudit(entry)
end
