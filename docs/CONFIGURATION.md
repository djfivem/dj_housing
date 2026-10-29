# Configuration

All server-specific settings live under `config/`.

| File | What it controls |
| --- | --- |
| `shared.lua` | Framework, inventory, interaction, notification, locale, debug, commands, money account |
| `framework.lua` | Per-framework admin groups, account names, standalone identity lists |
| `inventory.lua` | Key item name, legacy stash switch, custom inventory export map |
| `permissions.lua` | Co-owners, ownership cap, key cap, physical-key requirement, ACE names |
| `performance.lua` | Marker distance, sweep intervals, rate limits |
| `evidence.lua` | Seizure on/off, item denylist, metadata retention |
| `police.lua` | Jobs, grades, emergency entry, raid size, inspection mode |
| `shells.lua` | Allow-listed shell models and door offsets |
| `housing.lua` | Sale return percent, property tax, weekly water/power/garbage ranges, FiveManage hosts, PolyZone defaults, furniture, upgrades, optional integrations |
| `properties.lua` | Example properties. With sync enabled, these fields refresh matching database rows on boot |

`Housing.Config.Framework` is `auto`, `esx`, `qbcore`, `qbox`, or `standalone`.

`Housing.Config.Inventory` is `auto`, `ox_inventory`, `qb_inventory`, `lj_inventory`, `ps_inventory`, `qs_inventory`, `origen_inventory`, `codem_inventory`, `custom`, or `none`.

`Housing.Config.Interaction` is `target`, `key`, or `both`. Targeting uses `ox_target` when that resource is started, otherwise `qb-target` when that resource is started. With `key` or `both`, the client also draws a marker near entrances and listens for the interact key. The marker loop sleeps 1000 ms outside `markerDistance` and uses `Wait(0)` only while a marker is actually drawn.

`Housing.Config.Notification` is `framework`, `ox_lib`, or `custom`. A custom notify uses `Housing.Config.CustomNotifyEvent`.

Set `Housing.Config.Debug` to true only while diagnosing. It increases log volume. It does not weaken permission checks.

## Adding a property

Add a table to `Housing.Config.Properties` or insert a row through the database. Required fields are a unique `id` (`^[a-z0-9_]+$`, 3–64 characters), `label`, `propertyType` (`shell`, `mlo`, or `ipl`), non-negative prices, and an `entrance` with numeric `x`, `y`, `z`. Shell properties need a `shellModel` that exists in `config/shells.lua`. IPL properties need the IPL name. Invalid rows are reported at startup and are not loaded.

`Housing.Config.Housing.syncDefinitions` defaults to true. On boot, new Lua properties are inserted. Existing ids are updated from the Lua definition (label, prices, coordinates, shell, IPL, and features). Ownership, tenancy, and status are not overwritten by that update. Set `syncDefinitions` to false to leave existing rows alone and only insert ids that are not in the database yet. Stash rows are inserted when missing and are not deleted.

## Money

`Housing.Config.Account` is passed to the framework adapter. ESX maps `bank` to the bank account and anything else to `money` unless `cashAccount` is set. QBCore and Qbox map `bank` and `cash`. Standalone uses the `housing_balances` ledger.

Purchases compare an optional `expectedPrice` with the stored price and reject a mismatch. The client cannot set the price.
