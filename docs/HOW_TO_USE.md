# How to use advanced_housing

This is the day-to-day guide. Deeper notes live in `docs/INSTALLATION.md`, `docs/CONFIGURATION.md`, `docs/INVENTORIES.md`, and `docs/POLICE_RAIDS.md`.

The folder on the server must be named `advanced_housing`.

## 1. Put it on the server

Start `oxmysql` and `PolyZone` before this resource. Both are required. Start one framework and one inventory before it as well.

```cfg
ensure oxmysql
ensure PolyZone
ensure es_extended
ensure ox_inventory
ensure jg-advancedgarages
ensure screenshot-basic
ensure advanced_housing

set housing_fivemanage_key "your-fivemanage-key"

add_ace group.admin housing.admin allow
add_ace group.admin housing.police allow
```

Swap `es_extended` for `qb-core` or `qbx_core` if that is your framework. Swap `ox_inventory` for the inventory you actually run. `jg-advancedgarages` and `screenshot-basic` are optional. The FiveManage line is only needed when owners upload house photos. Use `set`, so the key stays on the server.

If more than one of `es_extended`, `qb-core`, and `qbx_core` is started, housing refuses to guess and prints `ambiguous_framework`. The same happens for inventories (`ambiguous_inventory`). Pick one in `config/shared.lua`:

```lua
Housing.Config.Framework = 'qbcore'   -- auto | esx | qbcore | qbox | standalone
Housing.Config.Inventory = 'ox_inventory'
```

Register the key item `housing_key` in your inventory. The ox_inventory example is in `docs/INVENTORIES.md`. Without that item, a purchase can succeed and still fail to give the key.

## 2. Check the first boot

Restart the server and read the housing lines in the server console. You want a named framework, an inventory that says it is ready, and `properties inserted` or `updated` with `errors=0`.

A missing `oxmysql` or `PolyZone` stops the resource. A missing optional script, such as a garage or dispatch resource, is skipped. Housing does not invent a fallback inventory.

The database is created on boot from `database/migrations/001_init.sql`, then the utility-rate columns are added if they are missing. You can also import `database/schema.sql` yourself. Housing does not store stash items. Those stay in the inventory resource.

## 3. What a player does

Open the menu with `/housing`, or walk up to a door. With the default interaction setting, the door has an orange marker and an `ox_target` or `qb-target` option. Press **E** at the marker when targeting is off. Walking into the lot polygon shows the property name once.

Four example homes are included. Their doors and lot boxes are starting points. Walk them in game and replace the coordinates before you treat them as final.

| Property | Type | Price |
| --- | --- | --- |
| Vinewood Hills Mansion | Shell | $2,500,000 |
| Del Perro Apartment | IPL | $330,000 |
| Sandy Shores Trailer | Shell | $180,000 |
| Mirror Park House | MLO | $650,000 |

From the menu:

- **My House** shows the selected property. Purchase, rent, or enter it from there. An owner can paste a FiveManage image URL or press Capture when `screenshot-basic` is running.
- **Marketplace** lists homes you can buy or rent. Confirm the price in the dialog. A second click while the first request is in flight is ignored.
- **Bills** shows property tax plus this week's water, power, and garbage prices. Those three prices are the same for every house and change once a week. Pay one bill or pay all. The money comes out of the bank account.
- **Keys** gives a physical `housing_key` to a player server id. Revoking the key in the menu stops that item from working, even if it is still in the inventory.
- **Permissions** adds a resident or guest. Guests need a key. Owners can enter without one.
- **Furniture** and **Upgrades** charge the bank and save the purchase on the property.
- **Garage** is the plate list stored by this resource. If `jg-advancedgarages` is running, the property garage is also registered there and uses housing access.
- **Storage** opens the inventory stash. lj-inventory, ps-inventory, origen_inventory, and codem-inventory can handle the key item. Their stash open stays off unless you accept the limit in `docs/INVENTORIES.md`.
- **Sell** pays 60% of the purchase price back and clears keys and access.

Escape closes a dialog first, then the window.

Inside a shell, you are in a private routing bucket. Press **E** at the orange exit marker to leave. An MLO or IPL does not use an extra bucket. Shell models are not shipped with this resource. If the model is not streamed, entry is cancelled and you are returned outside.

A player can own up to 3 properties. Selling to the state, or buying from another player, uses the price stored on the server. The menu cannot name its own price.

## 4. Admin

`/housingadmin` opens the admin page for anyone with the `housing.admin` ACE. From there you can enable or archive a property, transfer it to a player server id, and repair a stuck reservation.

Archiving an owned home requires the force option. That clears housing ownership and keys. It does not delete inventory stash contents or evidence rows.

`/housingadmin diag` prints a short status line to the player. From the server console, `housingadmin` prints the boot report.

## 5. Police

A character on the `police` or `sheriff` job at grade 1 or higher can request a warrant from the police page. A different officer at grade 3 or higher authorises it. The same officer cannot approve their own warrant.

A raid needs that authorised warrant and at least 2 officers. Move it to authorised, then active. Inspection lists stash items. Seizure removes one item into the housing evidence list. House keys cannot be seized. Retrying the same seizure does not remove the item twice.

`housing.police` in `server.cfg` is an override for people who should have the desk without the job.

## 6. Test it on your computer

This check does not need FiveM. From the resource folder:

```bash
lua5.4 tests/run.lua
```

A good run ends with `RESULT 81 passed, 0 failed` and the process exits 0. It covers purchase, rent, keys, stashes, warrants, raids, weekly bills, image hosts, and stand-ins for banking and jg-advancedgarages.

If `lua5.4` is missing on Linux:

```bash
sudo apt-get update && sudo apt-get install -y lua5.4
```

Optional syntax check:

```bash
find . -name '*.lua' -not -path './web/*' -print0 | xargs -0 luac5.4 -p
```

That should print nothing and exit 0.

To look at the menu without a game server:

```bash
cd web
npm install
npm run dev -- --host 127.0.0.1 --port 5173
```

Open `http://127.0.0.1:5173/`. The page uses sample data. Diesel's bank is $482,750. Vinewood Hills and the Sandy Shores trailer are already owned, and Del Perro is already rented. Buying Mirror Park at $650,000 shows `insufficient_funds`. Renting Mirror Park lowers the balance by $7,000 once, even if you click Confirm twice. Bills on Vinewood Hills shows Water $150, Power $220, and Garbage $90 for that sample week. Escape closes a dialog, then the window.

`http://127.0.0.1:5173/?desk=police` shows the warrant desk. `?desk=admin` shows the admin desk. This page is not what players see in game. The game uses `web/dist`.

## 7. Test it in game

Use a local or development server, two clients when a step says so, and one framework plus one inventory.

1. Start the server. The console names the framework and inventory and does not say `ambiguous_framework` or `ambiguous_inventory`.
2. Join and run `/housing`. The four example properties appear.
3. Stand at the Sandy Shores door. The marker or target opens the same property.
4. Buy the trailer. The bank drops by $180,000 once. `housing_ownership` has your character id. A `housing_key` is in your inventory.
5. Restart the server. You still own the trailer. Stash items are still in the inventory resource, not in a housing table.
6. From a second client, try to buy the same trailer. It fails.
7. Enter the trailer and leave with **E**. You come back outside. Disconnect while inside and reconnect. You are not stuck in a private bucket.
8. Enter the Del Perro apartment (IPL) and the Mirror Park house (MLO) after you own or rent them. Those entries do not put you in an extra routing bucket.
9. Give a key to the second player, then revoke it. The item left in their inventory no longer opens the door.
10. Open Bills and pay the water bill. The bank drops by that amount once. The row changes to paid.
11. If jg-advancedgarages v3 is started, the trailer garage accepts the owner and rejects a stranger.
12. With two police characters, request a warrant, have the second officer authorise it, start the raid, inspect the stash, and seize one item. Seizing again does not take a second item. A player without the police job cannot open the warrant page.

Write down the console line if a step fails. `docs/TROUBLESHOOTING.md` lists the usual causes.

## 8. What is already known

The computer test in section 6 has been run: 81 passed, 0 failed. The menu checks in that section were done in a browser against the sample page.

Those checks did not run inside FiveM. On a live server you still need to confirm door coordinates, shell models, the lot polygons, the key item, and whichever garage, banking, and dispatch resources you start. The example lot boxes are rectangles around the doors, not surveyed property lines. Replace `zone.points` in `config/properties.lua` with the outline you draw with PolyZone's `/pzcreate`.
