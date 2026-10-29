Housing = Housing or {}
Housing.Services = Housing.Services or {}

local Services = Housing.Services
local Validation = Housing.Validation
local Util = Housing.Util
local Auth = Housing.Auth

local function policeJob(ctx, player)
    if not player or not player.job then
        return nil
    end
    local minimum = ctx.config.police.jobs[player.job.name]
    if minimum == nil then
        if ctx.hasPoliceAce and ctx.hasPoliceAce(player.source) then
            return 0
        end
        return nil
    end
    if (player.job.grade or 0) < minimum then
        return nil
    end
    return player.job.grade or 0
end

local function scopeAllows(scope, stashKey)
    if type(scope) ~= 'table' then
        return false
    end
    if scope.all == true then
        return true
    end
    return Util.contains(scope.stashes or {}, stashKey)
end

local function warrantUsable(ctx, warrant)
    if not warrant then
        return false
    end
    if warrant.status ~= 'authorised' then
        return false
    end
    if warrant.expires_at <= ctx.now() then
        return false
    end
    return true
end

function Services.requestWarrant(ctx, source, raw)
    local valid, req = Validation.warrantRequest(raw or {})
    if not valid then
        return Util.fail('invalid_payload', req)
    end
    if not ctx.rateLimiter.allow(ctx.playerKey(source), 'raid') then
        return Util.fail('rate_limited')
    end
    local player = ctx.framework.getPlayer(source)
    local grade = player and policeJob(ctx, player) or nil
    if not grade or grade < ctx.config.police.requestGrade then
        return Util.fail('not_authorised')
    end
    local property = ctx.repo.getProperty(req.propertyId)
    if not property or property.enabled ~= 1 then
        return Util.fail('property_not_found')
    end
    if req.scope.stashes then
        for index = 1, #req.scope.stashes do
            if not ctx.repo.getStash(property.id, req.scope.stashes[index]) then
                return Util.fail('stash_not_found')
            end
        end
    elseif req.scope.all ~= true then
        return Util.fail('invalid_payload', 'scope')
    end
    if ctx.repo.getWarrant(req.idempotencyKey) then
        return Util.fail('duplicate_request')
    end
    local seizure = req.allowSeizure == true and ctx.config.evidence.seizureEnabled == true
    ctx.repo.insertWarrant({
        id = req.idempotencyKey,
        property_id = property.id,
        requester_framework = player.framework,
        requester_character_id = player.characterId,
        requester_name = player.name,
        approver_character_id = nil,
        approver_name = nil,
        reason_text = req.reason,
        case_reference = req.caseReference,
        scope_json = req.scope,
        allow_seizure = seizure and 1 or 0,
        status = 'requested',
        emergency = 0,
        issued_at = ctx.now(),
        expires_at = ctx.now() + (req.durationHours * 3600),
        decided_at = nil,
        revoked_at = nil,
    })
    Auth.audit(ctx, {
        category = 'warrant',
        action_name = 'requested',
        framework = player.framework,
        actor_character_id = player.characterId,
        property_id = property.id,
        target_id = req.idempotencyKey,
        detail_json = { allowSeizure = seizure },
    })
    return Util.ok({ warrantId = req.idempotencyKey, status = 'requested' })
end

function Services.decideWarrant(ctx, source, raw)
    if type(raw) ~= 'table' or (raw.decision ~= 'authorise' and raw.decision ~= 'revoke') then
        return Util.fail('invalid_payload')
    end
    local player = ctx.framework.getPlayer(source)
    local grade = player and policeJob(ctx, player) or nil
    if not grade or grade < ctx.config.police.approveGrade then
        return Util.fail('not_authorised')
    end
    local warrant = ctx.repo.getWarrant(raw.warrantId)
    if not warrant then
        return Util.fail('not_found')
    end
    if warrant.status == 'revoked' or warrant.status == 'expired' or warrant.status == 'executed' then
        return Util.fail('warrant_state')
    end
    if raw.decision == 'authorise' then
        if not ctx.config.police.allowSelfApproval and warrant.requester_character_id == player.characterId and warrant.requester_framework == player.framework then
            return Util.fail('self_approval')
        end
        if warrant.expires_at <= ctx.now() then
            ctx.repo.casWarrant(warrant.id, warrant.status, { status = 'expired' })
            return Util.fail('warrant_expired')
        end
        local changed = ctx.repo.casWarrant(warrant.id, 'requested', {
            status = 'authorised',
            approver_character_id = player.characterId,
            approver_name = player.name,
            decided_at = ctx.now(),
        })
        if not changed then
            return Util.fail('warrant_state')
        end
        return Util.ok({ warrantId = warrant.id, status = 'authorised' })
    end
    local changed = ctx.repo.casWarrant(warrant.id, warrant.status, {
        status = 'revoked',
        revoked_at = ctx.now(),
        approver_character_id = player.characterId,
    })
    if not changed then
        return Util.fail('warrant_state')
    end
    Auth.audit(ctx, {
        category = 'warrant',
        action_name = 'revoked',
        framework = player.framework,
        actor_character_id = player.characterId,
        property_id = warrant.property_id,
        target_id = warrant.id,
    })
    return Util.ok({ warrantId = warrant.id, status = 'revoked' })
end

local function officerRecords(ctx, player, rawOfficers)
    local records = {
        {
            framework = player.framework,
            characterId = player.characterId,
            name = player.name,
            source = player.source,
        },
    }
    local seen = { [player.characterId] = true }
    for index = 1, #(rawOfficers or {}) do
        local officerSource = rawOfficers[index]
        if type(officerSource) ~= 'number' then
            return nil
        end
        local officer = ctx.framework.getPlayer(officerSource)
        if officer and policeJob(ctx, officer) and not seen[officer.characterId] then
            seen[officer.characterId] = true
            records[#records + 1] = {
                framework = officer.framework,
                characterId = officer.characterId,
                name = officer.name,
                source = officer.source,
            }
        end
    end
    return records
end

function Services.openRaid(ctx, source, raw)
    if type(raw) ~= 'table' then
        return Util.fail('invalid_payload')
    end
    local idOk, propertyId = Validation.identifier(raw.propertyId or '')
    local keyOk, raidId = Validation.idempotencyKey(raw.idempotencyKey or '')
    if not idOk or not keyOk then
        return Util.fail('invalid_payload')
    end
    local player = ctx.framework.getPlayer(source)
    local grade = player and policeJob(ctx, player) or nil
    if not grade then
        return Util.fail('not_authorised')
    end
    if ctx.repo.getRaid(raidId) then
        return Util.fail('duplicate_request')
    end
    if ctx.repo.findOpenRaid(propertyId) then
        return Util.fail('raid_in_progress')
    end
    local property = ctx.repo.getProperty(propertyId)
    if not property or property.enabled ~= 1 then
        return Util.fail('property_not_found')
    end
    local officers = officerRecords(ctx, player, raw.officerSources)
    if not officers then
        return Util.fail('invalid_payload')
    end
    local warrant
    local emergency = raw.emergency == true
    local allowSeizure = false
    local scope = { all = true }
    if emergency then
        if not ctx.config.police.emergency.enabled or grade < ctx.config.police.emergency.minGrade then
            return Util.fail('not_authorised')
        end
        allowSeizure = ctx.config.police.emergency.allowSeizure == true and ctx.config.evidence.seizureEnabled == true
        warrant = {
            id = ctx.ids(),
            property_id = property.id,
            requester_framework = player.framework,
            requester_character_id = player.characterId,
            requester_name = player.name,
            approver_character_id = player.characterId,
            approver_name = player.name,
            reason_text = 'Emergency entry',
            case_reference = raw.caseReference,
            scope_json = scope,
            allow_seizure = allowSeizure and 1 or 0,
            status = 'authorised',
            emergency = 1,
            issued_at = ctx.now(),
            expires_at = ctx.now() + ((ctx.config.police.emergency.maxDurationMinutes or 45) * 60),
            decided_at = ctx.now(),
        }
        ctx.repo.insertWarrant(warrant)
    else
        warrant = ctx.repo.getWarrant(raw.warrantId)
        if not warrantUsable(ctx, warrant) or warrant.property_id ~= property.id then
            return Util.fail(warrant and warrant.status == 'revoked' and 'warrant_revoked' or 'warrant_invalid')
        end
        scope = warrant.scope_json or { all = false }
        allowSeizure = warrant.allow_seizure == 1
    end
    ctx.repo.insertRaid({
        id = raidId,
        property_id = property.id,
        warrant_id = warrant.id,
        lead_framework = player.framework,
        lead_character_id = player.characterId,
        lead_name = player.name,
        officers_json = officers,
        state = emergency and 'authorised' or 'requested',
        emergency = emergency and 1 or 0,
        allow_seizure = allowSeizure and 1 or 0,
        scope_json = scope,
        started_at = nil,
        ended_at = nil,
        created_at = ctx.now(),
    })
    Auth.audit(ctx, {
        category = 'raid',
        action_name = emergency and 'emergency_authorised' or 'requested',
        framework = player.framework,
        actor_character_id = player.characterId,
        property_id = property.id,
        target_id = raidId,
        detail_json = { warrantId = warrant.id },
    })
    return Util.ok({ raidId = raidId, state = emergency and 'authorised' or 'requested', warrantId = warrant.id })
end

local function onlineOfficers(ctx, raid)
    local count = 0
    for index = 1, #(raid.officers_json or {}) do
        local officer = raid.officers_json[index]
        local officerSource = ctx.framework.getSourceByCharacter(officer.framework, officer.characterId)
        if officerSource then
            local player = ctx.framework.getPlayer(officerSource)
            if player and policeJob(ctx, player) then
                count = count + 1
            end
        end
    end
    return count
end

function Services.setRaidState(ctx, source, raw)
    if type(raw) ~= 'table' or type(raw.state) ~= 'string' then
        return Util.fail('invalid_payload')
    end
    local player = ctx.framework.getPlayer(source)
    if not player or not policeJob(ctx, player) then
        return Util.fail('not_authorised')
    end
    local raid = ctx.repo.getRaid(raw.raidId)
    if not raid then
        return Util.fail('not_found')
    end
    if not Housing.CanTransitionRaid(raid.state, raw.state) then
        return Util.fail('raid_state')
    end
    if raw.state == 'authorised' or raw.state == 'active' then
        local warrant = ctx.repo.getWarrant(raid.warrant_id)
        if not warrantUsable(ctx, warrant) then
            ctx.repo.casRaid(raid.id, raid.state, { state = 'expired', ended_at = ctx.now() })
            return Util.fail('warrant_invalid')
        end
    end
    if raw.state == 'active' then
        if onlineOfficers(ctx, raid) < (ctx.config.police.raid.minOfficers or 1) then
            return Util.fail('insufficient_officers')
        end
        if raid.lead_character_id == player.characterId or ctx.isAdmin and ctx.isAdmin(source) then
            -- lead officer starts the raid
        else
            local listed = false
            for index = 1, #(raid.officers_json or {}) do
                if raid.officers_json[index].characterId == player.characterId then
                    listed = true
                end
            end
            if not listed then
                return Util.fail('not_authorised')
            end
        end
    end
    local changed = ctx.repo.casRaid(raid.id, raid.state, {
        state = raw.state,
        started_at = raw.state == 'active' and ctx.now() or raid.started_at,
        ended_at = (raw.state == 'completed' or raw.state == 'cancelled' or raw.state == 'expired') and ctx.now() or nil,
    })
    if not changed then
        return Util.fail('raid_state')
    end
    if raw.state == 'active' then
        local property = ctx.repo.getProperty(raid.property_id)
        if ctx.doorlock and property then
            ctx.doorlock(property, false)
        end
        if ctx.dispatch and property then
            local alarm = false
            local upgrades = ctx.repo.listUpgrades(property.id)
            for index = 1, #upgrades do
                for catalogIndex = 1, #(ctx.config.upgrades or {}) do
                    local def = ctx.config.upgrades[catalogIndex]
                    if def.id == upgrades[index].upgrade_id and def.effect and def.effect.alarm then
                        alarm = true
                    end
                end
            end
            ctx.dispatch({
                propertyId = property.id,
                coords = property.entrance,
                message = alarm and 'Property alarm' or 'Housing raid',
                code = alarm and '10-31' or '10-90',
                codeName = alarm and 'housingalarm' or 'housingraid',
            })
        end
    elseif ctx.doorlock and (raw.state == 'completed' or raw.state == 'cancelled' or raw.state == 'expired') then
        local property = ctx.repo.getProperty(raid.property_id)
        if property then
            ctx.doorlock(property, true)
        end
    end
    Auth.audit(ctx, {
        category = 'raid',
        action_name = raw.state,
        framework = player.framework,
        actor_character_id = player.characterId,
        property_id = raid.property_id,
        target_id = raid.id,
    })
    return Util.ok({ raidId = raid.id, state = raw.state })
end

local function activeSearch(ctx, source, propertyId, stashKey)
    local player = ctx.framework.getPlayer(source)
    if not player or not policeJob(ctx, player) then
        return nil, Util.fail('not_authorised')
    end
    local raid = ctx.repo.findOpenRaid(propertyId)
    if not raid or raid.state ~= 'active' then
        return nil, Util.fail('raid_state')
    end
    local listed = raid.lead_character_id == player.characterId
    for index = 1, #(raid.officers_json or {}) do
        if raid.officers_json[index].characterId == player.characterId then
            listed = true
        end
    end
    if not listed then
        return nil, Util.fail('not_authorised')
    end
    local warrant = ctx.repo.getWarrant(raid.warrant_id)
    if not warrantUsable(ctx, warrant) then
        return nil, Util.fail('warrant_invalid')
    end
    local property = ctx.repo.getProperty(propertyId)
    local stash = property and ctx.repo.getStash(propertyId, stashKey) or nil
    if not property or not stash then
        return nil, Util.fail('stash_not_found')
    end
    if not scopeAllows(raid.scope_json, stashKey) then
        return nil, Util.fail('outside_scope')
    end
    if ctx.config.police.raid.requireProximity and not Auth.near(ctx, source, property, 'stash') then
        return nil, Util.fail('proximity_failed')
    end
    return {
        player = player,
        raid = raid,
        warrant = warrant,
        property = property,
        stash = stash,
    }
end

function Services.inspectStash(ctx, source, raw)
    local valid, req = Validation.stashRequest(raw or {})
    if not valid then
        return Util.fail('invalid_payload', req)
    end
    local search, reason = activeSearch(ctx, source, req.propertyId, req.stashKey)
    if not search then
        return reason
    end
    local stashId = Util.stashIdentifier(search.property.id, search.stash.stash_key, nil)
    if search.stash.stash_type == 'personal' then
        local owner = ctx.repo.getOwnership(search.property.id)
        local tenancy = ctx.repo.getActiveTenancy(search.property.id)
        local characterId = owner and owner.character_id or (tenancy and tenancy.character_id or nil)
        if not characterId then
            return Util.fail('stash_not_found')
        end
        stashId = Util.stashIdentifier(search.property.id, search.stash.stash_key, characterId)
    end
    if ctx.config.police.inspectionMode == 'inventory_ui' then
        local opened, err = ctx.inventory.openStash(source, stashId, {
            label = search.stash.label,
            slots = search.stash.slots,
            maxWeight = search.stash.max_weight,
        })
        if opened ~= true then
            return Util.fail(err or 'inspection_unsupported')
        end
        Auth.audit(ctx, {
            category = 'raid',
            action_name = 'inventory_open',
            framework = search.player.framework,
            actor_character_id = search.player.characterId,
            property_id = search.property.id,
            target_id = stashId,
        })
        return Util.ok({ mode = 'inventory_ui', stashId = stashId })
    end
    local items, supported = ctx.inventory.getStashContents(stashId)
    if supported ~= true then
        return Util.fail('inspection_unsupported')
    end
    local safe = {}
    for index = 1, #(items or {}) do
        local item = items[index]
        safe[#safe + 1] = {
            name = item.name,
            label = item.label,
            count = item.count or item.amount,
            slot = item.slot,
            metadata = ctx.config.evidence.retainMetadata and Util.sanitizeMetadata(item.metadata or item.info) or nil,
        }
    end
    Auth.audit(ctx, {
        category = 'raid',
        action_name = 'inspected',
        framework = search.player.framework,
        actor_character_id = search.player.characterId,
        property_id = search.property.id,
        target_id = stashId,
        detail_json = { raidId = search.raid.id, count = #safe },
    })
    return Util.ok({ mode = 'ledger', stashId = stashId, items = safe })
end

function Services.seizeItem(ctx, source, raw)
    if ctx.config.evidence.seizureEnabled ~= true then
        return Util.fail('seizure_disabled')
    end
    local valid, req = Validation.seizeRequest(raw or {})
    if not valid then
        return Util.fail('invalid_payload', req)
    end
    local existing = ctx.repo.getEvidence(req.idempotencyKey)
    if existing then
        if existing.status == 'seized' then
            return Util.ok({ replay = true, evidenceId = existing.id, status = existing.status })
        end
        return Util.fail(existing.status == 'pending' and 'in_progress' or 'duplicate_request')
    end
    local search, reason = activeSearch(ctx, source, req.propertyId, req.stashKey)
    if not search then
        return reason
    end
    if search.raid.allow_seizure ~= 1 or search.warrant.allow_seizure ~= 1 then
        return Util.fail('seizure_not_authorised')
    end
    if ctx.config.evidence.denylist[req.itemName] then
        return Util.fail('seizure_not_authorised')
    end
    if next(ctx.config.evidence.allowlist) and not ctx.config.evidence.allowlist[req.itemName] then
        return Util.fail('seizure_not_authorised')
    end
    local stashId = Util.stashIdentifier(search.property.id, search.stash.stash_key, nil)
    if search.stash.stash_type == 'personal' then
        local owner = ctx.repo.getOwnership(search.property.id)
        local tenancy = ctx.repo.getActiveTenancy(search.property.id)
        local characterId = owner and owner.character_id or (tenancy and tenancy.character_id or nil)
        if not characterId then
            return Util.fail('stash_not_found')
        end
        stashId = Util.stashIdentifier(search.property.id, search.stash.stash_key, characterId)
    end
    ctx.repo.insertEvidence({
        id = req.idempotencyKey,
        property_id = search.property.id,
        stash_key = search.stash.stash_key,
        raid_id = search.raid.id,
        warrant_id = search.warrant.id,
        officer_framework = search.player.framework,
        officer_character_id = search.player.characterId,
        officer_name = search.player.name,
        item_name = req.itemName,
        quantity = req.quantity,
        metadata_json = nil,
        case_reference = search.warrant.case_reference,
        status = 'pending',
        created_at = ctx.now(),
        updated_at = ctx.now(),
    })
    local removed, removeState = ctx.inventory.removeStashItem(stashId, req.itemName, req.quantity, req.slot)
    if removed ~= true then
        local failed = ctx.repo.casEvidence(req.idempotencyKey, 'pending', {
            status = removeState == 'uncertain' and 'pending' or 'failed',
            updated_at = ctx.now(),
        })
        Auth.audit(ctx, {
            category = 'evidence',
            action_name = removeState == 'uncertain' and 'seizure_uncertain' or 'seizure_failed',
            framework = search.player.framework,
            actor_character_id = search.player.characterId,
            property_id = search.property.id,
            target_id = req.idempotencyKey,
        })
        if not failed and removeState == 'uncertain' then
            return Util.fail('needs_review')
        end
        return Util.fail(removeState == 'uncertain' and 'needs_review' or 'inventory_failed')
    end
    ctx.repo.casEvidence(req.idempotencyKey, 'pending', { status = 'seized', updated_at = ctx.now() })
    ctx.repo.insertTransfer({
        id = ctx.ids(),
        evidence_id = req.idempotencyKey,
        from_status = 'pending',
        to_status = 'seized',
        actor_character_id = search.player.characterId,
        note_text = 'seized from ' .. stashId,
        created_at = ctx.now(),
    })
    if ctx.evidenceExternal then
        ctx.evidenceExternal({
            evidenceId = req.idempotencyKey,
            propertyId = search.property.id,
            itemName = req.itemName,
            quantity = req.quantity,
            officer = search.player.characterId,
        })
    end
    Auth.audit(ctx, {
        category = 'evidence',
        action_name = 'seized',
        framework = search.player.framework,
        actor_character_id = search.player.characterId,
        property_id = search.property.id,
        target_id = req.idempotencyKey,
        detail_json = { item = req.itemName, quantity = req.quantity, stashId = stashId },
    })
    return Util.ok({ evidenceId = req.idempotencyKey, status = 'seized' })
end

function Services.transferEvidence(ctx, source, raw)
    if type(raw) ~= 'table' or (raw.status ~= 'transferred' and raw.status ~= 'released') then
        return Util.fail('invalid_payload')
    end
    local player = ctx.framework.getPlayer(source)
    if not player or not policeJob(ctx, player) then
        return Util.fail('not_authorised')
    end
    local evidence = ctx.repo.getEvidence(raw.evidenceId)
    if not evidence or evidence.status ~= 'seized' then
        return Util.fail('not_found')
    end
    local changed = ctx.repo.casEvidence(evidence.id, 'seized', { status = raw.status, updated_at = ctx.now() })
    if not changed then
        return Util.fail('evidence_state')
    end
    ctx.repo.insertTransfer({
        id = ctx.ids(),
        evidence_id = evidence.id,
        from_status = 'seized',
        to_status = raw.status,
        actor_character_id = player.characterId,
        note_text = raw.note,
        created_at = ctx.now(),
    })
    return Util.ok({ evidenceId = evidence.id, status = raw.status })
end
