Housing = Housing or {}
Housing.Config = Housing.Config or {}

Housing.Config.Evidence = {
    -- Seizure is off unless a warrant and the active raid both allow it.
    seizureEnabled = true,
    -- Items that can never be seized through housing, regardless of warrant flags.
    denylist = {
        housing_key = true,
    },
    -- When non-empty, only these item names may be seized.
    allowlist = {},
    retainMetadata = true,
    -- native writes the housing evidence ledger. custom also calls the configured export.
    system = 'native',
    custom = {
        resource = nil,
        exportName = nil,
    },
}
