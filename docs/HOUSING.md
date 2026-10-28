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

The built-in garage stores a plate and model hash on the property. It is not qb-garages. Spawn and store are server callbacks. Vehicle mods are not persisted.

Furniture purchases create a row. Placement is a separate callback (`placeFurniture`) validated against the property interior. The NUI buy button purchases the catalogue item. Placement is performed from the client interior flow.

Bills are generated from `config/housing.lua` rates. Pay one or pay all from the Bills panel. Payment is server-authoritative.

## NUI

`/housing` opens the dashboard. Escape and the close control release NUI focus. The client also clears focus on resource stop. Purchase and rental buttons send one idempotency key per confirmation dialog, and the UI ignores a second click while a request is in flight.

Property cards use generated gradients rather than photographs, so the resource does not depend on remote images.
