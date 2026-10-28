# Inventories

Only `server/adapters/inventory.lua` calls inventory exports. Every adapter sets `liveVerified = false` because this repository was not run against a live inventory.

If `Housing.Config.Inventory` is `auto` and more than one of `ox_inventory`, `qs-inventory`, `ps-inventory`, `lj-inventory`, and `qb-inventory` is started, startup fails with `ambiguous_inventory`.

Stash ids are `ah:{propertyId}:{stashKey}` for shared and restricted stashes, and `ah:{propertyId}:{stashKey}:{characterId}` for personal stashes. The client cannot choose that id.

## ox_inventory

Dependency: `ox_inventory` started.

Register the key item in `ox_inventory/data/items.lua`:

```lua
['housing_key'] = {
    label = 'House Key',
    weight = 10,
    stack = false,
    close = true,
    consume = 0,
    description = 'Property key. The server checks the key record before granting access.',
}
```

Calls used: `AddItem`, `RemoveItem`, `Search`, `CanCarryItem`, `GetInventory`, `RegisterStash`, `forceOpenInventory`, `GetInventoryItems`, `RemoveItem` on the stash inventory. Metadata stores `keyId`, `propertyId`, and `accessLevel`. Access is still decided from the `housing_keys` row (holder, state, expiry, level), not from the metadata alone.

Stashes are registered on the server and persist in ox_inventory. Seizure uses `RemoveItem` on the stash id. Inspection in `ledger` mode uses `GetInventoryItems`.

Setup checklist: item registered, `stack = false`, resource started before housing, `Inventory = 'ox_inventory'` or unambiguous auto. Test plan: give a key, revoke the database row, confirm the item no longer opens the door; restart the server and confirm stash contents remain in ox_inventory. Limitation: not executed against a live ox_inventory in this workspace.

## qb-inventory

Written for the 2024-11 rewrite that exports `CreateInventory`, `GetInventory`, `OpenInventory`, `AddItem`, `RemoveItem`, and `GetItemsByName`. Older forks that only open stashes from a client event are not this adapter.

Register a unique item named `housing_key` in the shared items file (`unique = true`). Metadata uses the `info` table with `keyId` and `propertyId`.

Stashes are created with `CreateInventory` and opened with `OpenInventory`. Seizure uses `RemoveItem` on the stash id. This path was not run against an installed qb-inventory.

## qs-inventory

Calls `AddItem`, `RemoveItem`, `RegisterStash(source, stashId, slots, maxWeight, label)`, `GetStashItems('Stash_' .. stashId)`, and `RemoveItemIntoStash`. The `Stash_` prefix is how qs-inventory names stored stashes. Confirm that prefix on your version before relying on inspection or seizure. Not live-verified.

## lj-inventory and ps-inventory

`AddItem`, `RemoveItem`, and `GetItemsByName` are called on the server. Opening a stash in these inventories is a client-triggered event and is not server-authoritative. `Housing.Config.LegacyStashOpen` defaults to `false`, so stash open, stash read, and seizure return unsupported. Do not point housing at their SQL tables. Enable the legacy switch only if you accept that a client can be told to open a stash the server did not authorise through the inventory's own API.

## Custom

Set `Housing.Config.Inventory = 'custom'` and fill `Housing.Config.CustomInventory`:

```lua
Housing.Config.CustomInventory = {
    resource = 'my_inventory',
    exports = {
        addItem = 'AddItem',          -- (source, item, count, metadata) -> boolean
        removeItem = 'RemoveItem',    -- (source, item, count, metadata) -> boolean
        canCarry = 'CanCarryItem',    -- optional
        getItemsByName = 'GetItemsByName',
        registerStash = 'RegisterStash', -- (id, label, slots, maxWeight)
        openStash = 'OpenStash',      -- (source, id, opts)
        getStashItems = 'GetStashItems',
        removeStashItem = 'RemoveStashItem', -- (id, item, count, slot)
    },
}
```

Missing exports fail that operation. They are not replaced with a fake item list.

## Keys

`Housing.Config.KeyItem` defaults to `housing_key`. Issuing a key inserts a `housing_keys` row and then asks the inventory to add the item. If the item add fails, the key row is marked failed and the player is told to ask an admin to recover it. Recovery is `/housingadmin` or the `recoverKey` callback, which re-checks the row and tries the item add again.

A copied metadata payload cannot grant access after revocation, because the server loads the key by id and checks `state`, holder, property, and expiry.
