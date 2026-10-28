Housing = Housing or {}
Housing.Config = Housing.Config or {}

Housing.Config.KeyItem = 'housing_key'

-- lj-inventory and ps-inventory do not expose a server-authoritative stash open.
-- Leave this false unless you accept that limitation. See docs/INVENTORIES.md.
Housing.Config.LegacyStashOpen = false

-- Mapped contract for an inventory that is not built in. Every export is optional.
-- Argument order is documented in docs/INVENTORIES.md and docs/API.md.
Housing.Config.CustomInventory = {
    resource = nil,
    exports = {
        addItem = nil,
        removeItem = nil,
        canCarry = nil,
        getItemsByName = nil,
        registerStash = nil,
        openStash = nil,
        getStashItems = nil,
        removeStashItem = nil,
    },
}
