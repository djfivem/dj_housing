Housing = Housing or {}
Housing.Services = Housing.Services or {}

local Services = Housing.Services
local Auth = Housing.Auth

local function publicProperty(property, ownership, tenancy)
    return {
        id = property.id,
        label = property.label,
        description = property.description,
        propertyType = property.property_type,
        purchasePrice = property.purchase_price,
        rentalPrice = property.rental_price,
        rentalPeriodHours = property.rental_period_hours,
        image = property.image_url or property.image_key,
        imageUrl = property.image_url,
        zone = property.zone,
        bedrooms = property.bedrooms,
        bathrooms = property.bathrooms,
        garages = property.garages,
        status = property.status,
        listed = property.listed == 1,
        listingPrice = property.listing_price,
        enabled = property.enabled == 1,
        owned = ownership ~= nil,
        ownerName = ownership and ownership.display_name or nil,
        rented = tenancy ~= nil,
        tenantName = tenancy and tenancy.display_name or nil,
        entrance = property.entrance,
    }
end

function Services.dashboard(ctx, source, selectedId)
    local player = ctx.framework.getPlayer(source)
    if not player then
        return { ok = false, error = 'player_not_found' }
    end
    local properties = ctx.repo.listProperties()
    local cards = {}
    local owned = 0
    local rented = 0
    local mine = {}
    for index = 1, #properties do
        local property = properties[index]
        if property.status ~= 'archived' then
            local ownership = ctx.repo.getOwnership(property.id)
            local tenancy = ctx.repo.getActiveTenancy(property.id)
            local card = publicProperty(property, ownership, tenancy)
            local role = Auth.resolveRole(ctx, player, property.id)
            card.role = role
            if role == 'owner' then
                owned = owned + 1
                mine[#mine + 1] = property.id
            elseif role == 'tenant' then
                rented = rented + 1
                mine[#mine + 1] = property.id
            elseif role then
                mine[#mine + 1] = property.id
            end
            cards[#cards + 1] = card
        end
    end
    local selected
    local bills = {}
    local access = {}
    local keys = {}
    local furniture = {}
    local upgrades = {}
    local vehicles = {}
    local stashes = {}
    if selectedId then
        local property = ctx.repo.getProperty(selectedId)
        if property then
            local ownership = ctx.repo.getOwnership(property.id)
            local tenancy = ctx.repo.getActiveTenancy(property.id)
            selected = publicProperty(property, ownership, tenancy)
            selected.role = Auth.resolveRole(ctx, player, property.id)
            selected.shellModel = (ownership and ownership.shell_model) or property.shell_model
            selected.shellOptions = property.shell_options
            selected.interior = property.property_type == 'mlo' or property.property_type == 'ipl'
            local stashRows = ctx.repo.listStashes(property.id)
            for index = 1, #stashRows do
                stashes[#stashes + 1] = Services.describeStash(ctx, property.id, stashRows[index], player)
            end
            if selected.role == 'owner' or selected.role == 'tenant' or selected.role == 'coowner' or (ctx.isAdmin and ctx.isAdmin(source)) then
                bills = ctx.repo.listBills(property.id)
                local accessRows = ctx.repo.listAccess(property.id)
                for index = 1, #accessRows do
                    local row = accessRows[index]
                    access[#access + 1] = {
                        characterId = row.character_id,
                        framework = row.framework,
                        displayName = row.display_name,
                        role = row.role,
                        revoked = row.revoked_at ~= nil,
                        expiresAt = row.expires_at,
                    }
                end
                local keyRows = ctx.repo.listKeys(property.id)
                for index = 1, #keyRows do
                    keys[#keys + 1] = {
                        id = keyRows[index].id,
                        accessLevel = keyRows[index].access_level,
                        state = keyRows[index].state,
                        holderName = keyRows[index].holder_character_id,
                    }
                end
                furniture = ctx.repo.listFurniture(property.id)
                upgrades = ctx.repo.listUpgrades(property.id)
                vehicles = ctx.repo.listVehicles(property.id)
            end
        end
    end
    local pendingBills = 0
    for index = 1, #mine do
        local due = ctx.repo.listBills(mine[index], 'due')
        pendingBills = pendingBills + #due
    end
    local balance = ctx.framework.getMoney(source, ctx.config.account) or 0
    local police = false
    if player.job and ctx.config.police.jobs[player.job.name] and (player.job.grade or 0) >= ctx.config.police.jobs[player.job.name] then
        police = true
    end
    local payload = {
        player = { name = player.name, characterId = player.characterId, framework = player.framework },
        balance = balance,
        counts = { owned = owned, rented = rented, pendingBills = pendingBills },
        properties = cards,
        mine = mine,
        selected = selected,
        bills = bills,
        access = access,
        keys = keys,
        furniture = furniture,
        upgrades = upgrades,
        vehicles = vehicles,
        stashes = stashes,
        catalog = {
            furniture = ctx.config.furniture,
            upgrades = ctx.config.upgrades,
            shells = ctx.config.shells,
        },
        police = police,
        admin = ctx.isAdmin and ctx.isAdmin(source) or false,
        rules = {
            saleReturnPercent = (ctx.config.housing and ctx.config.housing.saleReturnPercent) or 0,
            minListingPrice = (ctx.config.housing and ctx.config.housing.minListingPrice) or 0,
        },
        utilities = Housing.Utilities and Housing.Utilities.snapshot(ctx) or nil,
    }
    if police then
        payload.warrants = ctx.repo.listWarrants(selectedId)
        payload.raids = ctx.repo.listRaids(selectedId)
        payload.evidence = selectedId and ctx.repo.listEvidence(selectedId) or {}
    end
    if payload.admin then
        payload.audit = ctx.repo.listAudit(selectedId, 40)
        payload.pending = ctx.repo.listPendingTransactions()
    end
    return { ok = true, data = payload }
end
