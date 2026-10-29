Housing = Housing or {}
Housing.Config = Housing.Config or {}

Housing.Config.Police = {
    jobs = {
        police = 1,
        sheriff = 1,
        state = 2,
    },
    -- Grade required to request a warrant.
    requestGrade = 1,
    -- Grade required to approve a warrant. Self-approval is rejected unless allowSelfApproval is true.
    approveGrade = 3,
    allowSelfApproval = false,
    emergency = {
        enabled = true,
        minGrade = 4,
        allowSeizure = false,
        maxDurationMinutes = 45,
    },
    raid = {
        minOfficers = 2,
        -- Officers counted toward the minimum must currently have a configured police job.
        countOnlyOnDuty = false,
        requireProximity = true,
        durationMinutes = 60,
    },
    -- ledger uses a read API when the inventory adapter has one.
    -- inventory_ui opens the real stash and is not read-only. It stays off unless you set it here.
    inspectionMode = 'ledger',
    warrantDurationHours = 12,
}
