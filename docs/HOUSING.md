# Housing

## Property types

- `shell`: the client creates a local, non-networked object from an allow-listed model at an isolated origin. The player is moved into a routing bucket derived from the property id (range 1–60000). Another player in the same property shares that bucket. Different properties do not share an origin.
- `mlo`: no shell is spawned and no extra routing bucket is assigned. Entry checks access, then moves the player to the configured interior coordinates. An MLO is not isolated from the rest of the map.
- `ipl`: the client requests the configured IPL and uses the absolute interior coordinates. The resource does not call `RemoveIpl`.

Example properties in `config/properties.lua`:

- `vinewood_hills_mansion` — shell, $2,500,000
- `del_perro_apartment` — IPL `apa_v_mp_h_01_a`
- `sandy_shores_trailer` — shell `shell_trailer`
- `mirror_park_house` — MLO, no shell

Confirm coordinates in-game. Shell door offsets in `config/shells.lua` are starting points for common streamed packs. This resource does not ship the models. If the model is not streamed, entry is cancelled and the player is returned outside.

## Transactions

Purchases, rentals, renewals, and sales are server-side. The flow is:

1. Insert an idempotency row.
2. Compare-and-swap the property from `available` (or `owned` and listed) to `reserved`.
3. Remove money.
4. Write ownership or tenancy and issue the owner key.
5. On a failed grant, refund the money and release the reservation.

Framework money and SQL are not one atomic transaction. If the money call errors inside `pcall` (`uncertain`), the transaction is marked `needs_review` and is not automatically refunded a second time. A sweeper releases reservations older than `reservationTimeoutSeconds` (180). Concurrent buyers of the same property: one reservation wins, the other is rejected.

Selling to the state pays `saleReturnPercent` (default 60) of the stored purchase price, revokes keys and access, and sets the property back to `available`. The client must send that computed price as `expectedPrice` or the sale is rejected. The sell callback still uses mode `purchase` because the shared request schema only allows `purchase`, `rent`, and `renew`.

Rentals expire on the tenancy sweep. Expired tenants lose access and keys issued for that tenancy.

## Access

Roles, from lowest to highest: guest, resident, co-owner, owner. Co-owners exist only when `permissions.allowCoOwner` is true. Guests need a key when `guestsRequireKey` is true. Owners can enter without a physical key when `ownerBypassKey` is true. `requirePhysicalKey` forces a key item check for everyone, including the owner.

Stash access checks the player, the property, the stash row, the role, proximity to the server-known position when configured, and the rate limit. Police inspection uses the raid path in `docs/POLICE_RAIDS.md` and does not grant resident access.

## Garages, furniture, bills

The built-in garage stores a plate and model hash on the property. Spawn and store are server callbacks. Vehicle mods are not persisted.

When `integrations.garage.system` is `auto`, the server registers locations with the first started resource that publishes a house-garage API. `jg-advancedgarages` v3 is first. Each property with garage coordinates is registered with `registerGarage`: id `housing_{propertyId}`, entrance and spawn at the configured garage point, `vehicleType` `car`, and `manageInteractions` true so jg draws the open and store prompts. The access callback is `(source, garageId)` and returns true only when housing access allows entry. The id returned by jg is kept. A later sync calls `updateGarage`. A removed or disabled garage calls `unregisterGarage`. Purchase, sale, rental, keys, and permissions call `refreshGarageAccess` so the prompts follow the new access. If `jg-advancedgarages` starts after housing, the garages are registered again with the same ids. Stored vehicles stay linked to that id.

`qb-garages` is next (`qb-garages:client:addHouseGarage`, location only). `qs-advancedgarages` `CreateGarage` is used only when that system is selected explicitly, because the published example has no housing access callback. `cd_garage` and `okokGarage` are vehicle-key systems and are not called. The client asks the server to register again after join, because `playerJoining` is too early. `HasGarageAccess` and `GetPropertyGarages` are server exports. None of these calls were executed against a live garage resource.

Furniture purchases create a row. Placement is a separate callback (`placeFurniture`) validated against the property interior. The NUI buy button purchases the catalogue item. Placement is performed from the client interior flow.

Property tax still uses `billRates`. Water, power, and garbage are city-wide weekly rates in `utilities`. The server rolls one amount per type per week, stores it in `housing_utility_rates`, and bills every occupied property that week. The same week is not billed twice. Paying a bill removes money through the framework. If Renewed-Banking, qb-banking, or okokBanking is started, housing then asks that resource to write a statement. It does not call their society money exports. A statement failure does not refund the bill.

## NUI

`/housing` opens a centered management window. The sidebar groups My House, furniture, bills, keys, permissions, upgrades, garage, storage, and the marketplace. Accent color is orange (`#ff7a18`) on a near-black panel. Escape closes a dialog first, then the window, and both Escape and the close control release NUI focus. The client also clears focus on resource stop. Purchase and rental buttons send one idempotency key per confirmation dialog, and the UI ignores a second click while a request is in flight.

Property photos start as the bundled images. An owner can paste an `https` URL on `r2.fivemanage.com`, `fivemanage.com`, or `fmapi.net`, or capture one when `screenshot-basic` is started. The capture path asks the server for a FiveManage presigned URL. The API key never goes to the client. A definition sync does not clear a saved `image_url`.

## Property lines

`PolyZone` is required. Each property can set `zone.points` (at least three), `minZ`, and `maxZ`. The example polygons in `config/properties.lua` are starting rectangles around the entrances. They are not surveyed lot lines. A property with no polygon gets a square of `Zones.defaultSize` (24) around the entrance. Entering the polygon notifies the player once. Those zones were not drawn in a live game.
