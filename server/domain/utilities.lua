Housing = Housing or {}
Housing.Utilities = Housing.Utilities or {}

local Utilities = Housing.Utilities

function Utilities.weekId(now, intervalHours)
    local seconds = math.floor((intervalHours or 168) * 3600)
    if seconds < 1 then
        seconds = 3600
    end
    return math.floor((now or 0) / seconds)
end

function Utilities.typeNames(types)
    local names = {}
    for name in pairs(types or {}) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

function Utilities.current(ctx)
    local utilities = (ctx.config.housing and ctx.config.housing.utilities) or {}
    local week = Utilities.weekId(ctx.now(), utilities.intervalHours)
    local stored = ctx.repo.listUtilityRates(week) or {}
    local names = Utilities.typeNames(utilities.types)
    local missing = false
    for index = 1, #names do
        if stored[names[index]] == nil then
            missing = true
        end
    end
    if missing then
        local randomInt = ctx.randomInt or math.random
        for index = 1, #names do
            local name = names[index]
            if stored[name] == nil then
                local spec = utilities.types[name]
                local amount = randomInt(spec.min, spec.max)
                ctx.repo.saveUtilityRate(week, name, amount, ctx.now())
            end
        end
        stored = ctx.repo.listUtilityRates(week) or {}
    end
    return stored, week
end

function Utilities.issueProperty(ctx, property, rates, week)
    local utilities = (ctx.config.housing and ctx.config.housing.utilities) or {}
    if not utilities.types then
        return 0
    end
    if not rates or not week then
        rates, week = Utilities.current(ctx)
    end
    local created = 0
    local names = Utilities.typeNames(utilities.types)
    for index = 1, #names do
        local billType = names[index]
        local amount = rates[billType]
        if amount and amount > 0 and not ctx.repo.hasBillForWeek(property.id, billType, week) then
            local spec = utilities.types[billType]
            ctx.repo.insertBill({
                id = ctx.ids(),
                property_id = property.id,
                bill_type = billType,
                label = spec.label or billType,
                amount = amount,
                status = 'due',
                due_at = ctx.now() + ((utilities.intervalHours or 168) * 3600),
                paid_at = nil,
                paid_by = nil,
                week_id = week,
            })
            created = created + 1
        end
    end
    return created
end

function Utilities.issueAll(ctx)
    local rates, week = Utilities.current(ctx)
    local created = 0
    local properties = ctx.repo.listProperties()
    for index = 1, #properties do
        local property = properties[index]
        if property.status == 'owned' or property.status == 'rented' then
            created = created + Utilities.issueProperty(ctx, property, rates, week)
        end
    end
    return created
end

function Utilities.snapshot(ctx)
    local rates, week = Utilities.current(ctx)
    return { weekId = week, rates = rates }
end
