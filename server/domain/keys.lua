Housing = Housing or {}
Housing.Services = Housing.Services or {}

local Services = Housing.Services
local Validation = Housing.Validation
local Util = Housing.Util
local Auth = Housing.Auth

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

local function activeKeyCount(ctx, propertyId)
    local keys = ctx.repo.listKeys(propertyId)
    local count = 0
    for index = 1, #keys do
        if keys[index].state == 'active' or keys[index].state == 'pending' or keys[index].state == 'transferring' then
            count = count + 1
        end
    end
    return count
end

function Services.issueKey(ctx, source, raw)
    local valid, req = Validation.keyAction(raw or {})
    if not valid then
        return Util.fail('invalid_payload', req)
    end
    if req.accessLevel == 'owner' and not raw.asPurchase then
        return Util.fail('not_authorised')
    end
    local player = ctx.framework.getPlayer(source)
    if not player then
        return Util.fail('player_not_found')
    end
    local function body()
        if not ctx.rateLimiter.allow(ctx.playerKey(source), 'key') then
            return Util.fail('rate_limited')
        end
        local existing = ctx.repo.getKey(req.idempotencyKey)
        if existing then
            return Util.ok({ replay = true, keyId = existing.id, state = existing.state })
        end
        local allowed = raw.asPurchase or Auth.canManage(ctx, player, req.propertyId)
        if not allowed then
            return Util.fail('not_authorised')
        end
        if req.accessLevel == 'coowner' and not ctx.config.permissions.allowCoOwner then
            return Util.fail('not_authorised')
        end
        local property = ctx.repo.getProperty(req.propertyId)
        if not property or property.enabled ~= 1 then
            return Util.fail('property_not_found')
        end
        local target = player
        if req.targetSource and req.targetSource ~= source then
            if type(req.targetSource) ~= 'number' then
                return Util.fail('invalid_payload')
            end
            target = ctx.framework.getPlayer(req.targetSource)
            if not target then
                return Util.fail('player_not_found')
            end
        end
        if activeKeyCount(ctx, property.id) >= (ctx.config.permissions.maxKeysPerProperty or 12) then
            return Util.fail('key_limit')
        end
        local keyId = req.idempotencyKey
        ctx.repo.insertKey({
            id = keyId,
            property_id = property.id,
            holder_framework = target.framework,
            holder_character_id = target.characterId,
            issued_by = player.characterId,
            access_level = req.accessLevel,
            state = 'pending',
            issued_at = ctx.now(),
            expires_at = raw.expiresAt,
            revoked_at = nil,
            revoked_by = nil,
            inventory_state = 'pending',
        })
        local added, detail = ctx.inventory.addItem(target.source, ctx.config.keyItem, 1, {
            keyId = keyId,
            propertyId = property.id,
            accessLevel = req.accessLevel,
            label = property.label,
        })
        if added ~= true then
            ctx.repo.casKeyState(keyId, 'pending', { state = 'failed', inventory_state = 'failed' })
            Auth.audit(ctx, {
                category = 'key',
                action_name = 'issue_failed',
                framework = player.framework,
                actor_character_id = player.characterId,
                property_id = property.id,
                target_id = target.characterId,
                detail_json = { detail = detail },
            })
            return Util.fail('inventory_failed', detail)
        end
        ctx.repo.casKeyState(keyId, 'pending', { state = 'active', inventory_state = 'stored' })
        if req.accessLevel ~= 'owner' then
            local current = ctx.repo.getAccess(property.id, target.framework, target.characterId)
            if not current or current.revoked_at or not Housing.RoleAllows(current.role, req.accessLevel) then
                ctx.repo.upsertAccess({
                    property_id = property.id,
                    framework = target.framework,
                    character_id = target.characterId,
                    display_name = target.name,
                    role = req.accessLevel,
                    granted_by = player.characterId,
                    granted_at = ctx.now(),
                    expires_at = raw.expiresAt,
                    revoked_at = nil,
                    revoked_by = nil,
                })
            end
        end
        Auth.audit(ctx, {
            category = 'key',
            action_name = 'issued',
            framework = player.framework,
            actor_character_id = player.characterId,
            property_id = property.id,
            target_id = target.characterId,
            detail_json = { keyId = keyId, accessLevel = req.accessLevel },
        })
        return Util.ok({ keyId = keyId, holder = target.characterId })
    end
    if raw.asPurchase then
        return body()
    end
    return withLock(ctx, player, body)
end

function Services.revokeKey(ctx, source, raw)
    if type(raw) ~= 'table' or type(raw.keyId) ~= 'string' then
        return Util.fail('invalid_payload')
    end
    local player = ctx.framework.getPlayer(source)
    if not player then
        return Util.fail('player_not_found')
    end
    local record = ctx.repo.getKey(raw.keyId)
    if not record then
        return Util.fail('key_invalid')
    end
    local manager = Auth.canManage(ctx, player, record.property_id)
    local admin = ctx.isAdmin and ctx.isAdmin(source)
    if not manager and not admin then
        return Util.fail('not_authorised')
    end
    if record.state == 'revoked' then
        return Util.ok({ replay = true, keyId = record.id })
    end
    local changed = ctx.repo.casKeyState(record.id, record.state, {
        state = 'revoked',
        revoked_at = ctx.now(),
        revoked_by = player.characterId,
        inventory_state = 'revoked',
    })
    if not changed then
        return Util.fail('key_invalid')
    end
    Auth.audit(ctx, {
        category = 'key',
        action_name = 'revoked',
        framework = player.framework,
        actor_character_id = player.characterId,
        property_id = record.property_id,
        target_id = record.holder_character_id,
        detail_json = { keyId = record.id },
    })
    return Util.ok({ keyId = record.id })
end

function Services.revokePropertyKeys(ctx, source, propertyId)
    local idOk, id = Validation.identifier(propertyId)
    if not idOk then
        return Util.fail('invalid_payload')
    end
    local player = ctx.framework.getPlayer(source)
    if not player then
        return Util.fail('player_not_found')
    end
    if not Auth.canManage(ctx, player, id) and not (ctx.isAdmin and ctx.isAdmin(source)) then
        return Util.fail('not_authorised')
    end
    local count = ctx.repo.revokeKeysForProperty(id, ctx.now(), player.characterId)
    Auth.audit(ctx, {
        category = 'key',
        action_name = 'revoked_all',
        framework = player.framework,
        actor_character_id = player.characterId,
        property_id = id,
        detail_json = { count = count },
    })
    return Util.ok({ count = count })
end

function Services.recoverKey(ctx, source, keyId)
    if not ctx.isAdmin or not ctx.isAdmin(source) then
        return Util.fail('not_authorised')
    end
    local record = ctx.repo.getKey(keyId)
    if not record or record.state == 'revoked' or record.state == 'failed' then
        return Util.fail('key_invalid')
    end
    local holderSource = ctx.framework.getSourceByCharacter(record.holder_framework, record.holder_character_id)
    if not holderSource then
        return Util.fail('holder_offline')
    end
    local items = ctx.inventory.search(holderSource, ctx.config.keyItem) or {}
    for index = 1, #items do
        local metadata = items[index].metadata or items[index].info
        if metadata and metadata.keyId == record.id then
            ctx.repo.updateKey(record.id, { state = 'active', inventory_state = 'stored' })
            return Util.ok({ keyId = record.id, alreadyHeld = true })
        end
    end
    local property = ctx.repo.getProperty(record.property_id)
    local added = ctx.inventory.addItem(holderSource, ctx.config.keyItem, 1, {
        keyId = record.id,
        propertyId = record.property_id,
        accessLevel = record.access_level,
        label = property and property.label or record.property_id,
    })
    if added ~= true then
        return Util.fail('inventory_failed')
    end
    ctx.repo.updateKey(record.id, { state = 'active', inventory_state = 'stored' })
    Auth.audit(ctx, {
        category = 'key',
        action_name = 'recovered',
        framework = record.holder_framework,
        actor_character_id = record.holder_character_id,
        property_id = record.property_id,
        detail_json = { keyId = record.id },
    })
    return Util.ok({ keyId = record.id })
end

function Services.transferKey(ctx, source, raw)
    if type(raw) ~= 'table' or type(raw.keyId) ~= 'string' or type(raw.targetSource) ~= 'number' then
        return Util.fail('invalid_payload')
    end
    local player = ctx.framework.getPlayer(source)
    local target = ctx.framework.getPlayer(raw.targetSource)
    if not player or not target then
        return Util.fail('player_not_found')
    end
    local record = ctx.repo.getKey(raw.keyId)
    if not record or record.state ~= 'active' then
        return Util.fail('key_invalid')
    end
    if record.holder_character_id ~= player.characterId or record.holder_framework ~= player.framework then
        return Util.fail('not_authorised')
    end
    if not Auth.holdsKey(ctx, player, record.property_id, record.access_level) then
        return Util.fail('key_invalid')
    end
    if not ctx.repo.casKeyState(record.id, 'active', { state = 'transferring' }) then
        return Util.fail('key_invalid')
    end
    local removed = ctx.inventory.removeItem(source, ctx.config.keyItem, 1, { keyId = record.id })
    if removed ~= true then
        ctx.repo.casKeyState(record.id, 'transferring', { state = 'active' })
        return Util.fail('inventory_failed')
    end
    local property = ctx.repo.getProperty(record.property_id)
    local added = ctx.inventory.addItem(target.source, ctx.config.keyItem, 1, {
        keyId = record.id,
        propertyId = record.property_id,
        accessLevel = record.access_level,
        label = property and property.label or record.property_id,
    })
    if added ~= true then
        local restored = ctx.inventory.addItem(source, ctx.config.keyItem, 1, { keyId = record.id, propertyId = record.property_id, accessLevel = record.access_level })
        ctx.repo.casKeyState(record.id, 'transferring', { state = restored == true and 'active' or 'inconsistent', inventory_state = restored == true and 'stored' or 'inconsistent' })
        return Util.fail(restored == true and 'inventory_failed' or 'needs_review')
    end
    ctx.repo.updateKey(record.id, {
        state = 'active',
        inventory_state = 'stored',
        holder_framework = target.framework,
        holder_character_id = target.characterId,
    })
    Auth.audit(ctx, {
        category = 'key',
        action_name = 'transferred',
        framework = player.framework,
        actor_character_id = player.characterId,
        property_id = record.property_id,
        target_id = target.characterId,
        detail_json = { keyId = record.id },
    })
    return Util.ok({ keyId = record.id, holder = target.characterId })
end

function Services.grantAccess(ctx, source, raw)
    local valid, req = Validation.accessGrant(raw or {})
    if not valid then
        return Util.fail('invalid_payload', req)
    end
    local player = ctx.framework.getPlayer(source)
    if not player then
        return Util.fail('player_not_found')
    end
    local manager = Auth.canManage(ctx, player, req.propertyId)
    local role = Auth.resolveRole(ctx, player, req.propertyId)
    local guestInvite = req.role == 'guest' and role == 'resident' and ctx.config.permissions.residentsCanInviteGuests
    if not manager and not guestInvite then
        return Util.fail('not_authorised')
    end
    if req.role == 'coowner' and not ctx.config.permissions.allowCoOwner then
        return Util.fail('not_authorised')
    end
    local accessList = ctx.repo.listAccess(req.propertyId)
    local active = 0
    for index = 1, #accessList do
        if Auth.isActiveAccess(accessList[index], ctx.now()) then
            active = active + 1
        end
    end
    if active >= Housing.Limits.maxResidents then
        return Util.fail('resident_limit')
    end
    ctx.repo.upsertAccess({
        property_id = req.propertyId,
        framework = req.targetFramework,
        character_id = req.targetCharacterId,
        display_name = req.displayName or req.targetCharacterId,
        role = req.role,
        granted_by = player.characterId,
        granted_at = ctx.now(),
        expires_at = req.expiresInHours and (ctx.now() + req.expiresInHours * 3600) or nil,
        revoked_at = nil,
        revoked_by = nil,
    })
    Auth.audit(ctx, {
        category = 'access',
        action_name = 'granted',
        framework = player.framework,
        actor_character_id = player.characterId,
        property_id = req.propertyId,
        target_id = req.targetCharacterId,
        detail_json = { role = req.role },
    })
    return Util.ok({ propertyId = req.propertyId, characterId = req.targetCharacterId, role = req.role })
end

function Services.revokeAccess(ctx, source, raw)
    if type(raw) ~= 'table' then
        return Util.fail('invalid_payload')
    end
    local idOk, propertyId = Validation.identifier(raw.propertyId or '')
    if not idOk then
        return Util.fail('invalid_payload')
    end
    local player = ctx.framework.getPlayer(source)
    if not player then
        return Util.fail('player_not_found')
    end
    if not Auth.canManage(ctx, player, propertyId) and not (ctx.isAdmin and ctx.isAdmin(source)) then
        return Util.fail('not_authorised')
    end
    local current = ctx.repo.getAccess(propertyId, raw.targetFramework, raw.targetCharacterId)
    if not current then
        return Util.fail('not_found')
    end
    if current.role == 'owner' then
        return Util.fail('not_authorised')
    end
    current.revoked_at = ctx.now()
    current.revoked_by = player.characterId
    ctx.repo.upsertAccess(current)
    if Housing.Garages and Housing.Garages.notify then
        Housing.Garages.notify(propertyId)
    end
    return Util.ok({ propertyId = propertyId })
end
