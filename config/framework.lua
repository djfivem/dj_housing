Housing = Housing or {}
Housing.Config = Housing.Config or {}

Housing.Config.Frameworks = {
    esx = {
        resource = 'es_extended',
        -- ESX Legacy group names treated as housing admins, in addition to the housing.admin ACE.
        adminGroups = { admin = true, superadmin = true },
        cashAccount = 'money',
        bankAccount = 'bank',
    },
    qbcore = {
        resource = 'qb-core',
        adminPermissions = { 'admin', 'god' },
        cashAccount = 'cash',
        bankAccount = 'bank',
    },
    qbox = {
        resource = 'qbx_core',
        -- Qbox permissions are ACE-backed. HasPermission is deprecated upstream.
        adminAces = { 'admin', 'god', 'housing.admin' },
        cashAccount = 'cash',
        bankAccount = 'bank',
    },
    standalone = {
        -- license identifiers explicitly allowed to administer housing. Empty by default.
        admins = {},
        -- license identifiers treated as police for standalone servers. Empty by default.
        police = {},
        startingBank = 0,
        startingCash = 0,
        cashAccount = 'cash',
        bankAccount = 'bank',
    },
}
