Housing = Housing or {}

Housing.PropertyType = {
    shell = true,
    mlo = true,
    ipl = true,
    apartment = true,
}

Housing.PropertyStatus = {
    available = true,
    reserved = true,
    owned = true,
    rented = true,
    disabled = true,
    archived = true,
}

Housing.AccessRole = {
    guest = 1,
    resident = 2,
    coowner = 3,
    owner = 4,
}

Housing.KeyState = {
    pending = true,
    active = true,
    failed = true,
    revoked = true,
    transferring = true,
    inconsistent = true,
}

Housing.TxStatus = {
    pending = true,
    completed = true,
    failed = true,
    compensated = true,
    needs_review = true,
}

Housing.MoneyState = {
    not_taken = true,
    taking = true,
    taken = true,
    refunding = true,
    refunded = true,
    uncertain = true,
}

Housing.WarrantStatus = {
    requested = true,
    authorised = true,
    revoked = true,
    expired = true,
    executed = true,
}

Housing.RaidState = {
    requested = true,
    authorised = true,
    active = true,
    completed = true,
    cancelled = true,
    expired = true,
}

Housing.RaidTransitions = {
    requested = { authorised = true, cancelled = true, expired = true },
    authorised = { active = true, cancelled = true, expired = true },
    active = { completed = true, cancelled = true, expired = true },
    completed = {},
    cancelled = {},
    expired = {},
}

Housing.EvidenceStatus = {
    pending = true,
    seized = true,
    failed = true,
    transferred = true,
    released = true,
}

Housing.BillStatus = {
    due = true,
    paid = true,
    void = true,
}

Housing.OpenRaidStates = {
    requested = true,
    authorised = true,
    active = true,
}

function Housing.RoleAllows(role, minimum)
    local have = Housing.AccessRole[role] or 0
    local need = Housing.AccessRole[minimum] or 99
    return have >= need
end

function Housing.CanTransitionRaid(fromState, toState)
    local allowed = Housing.RaidTransitions[fromState]
    return allowed ~= nil and allowed[toState] == true
end
