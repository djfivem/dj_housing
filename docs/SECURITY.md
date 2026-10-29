# Security

Client events and NUI callbacks are untrusted. `server/callbacks.lua` allow-lists callback names. A client cannot choose an arbitrary export or event name.

Checks that are always server-side:

- Player identity and job come from the framework adapter, not from the payload.
- Prices come from the property row. `expectedPrice` is a confirmation, and a mismatch is rejected.
- Key access loads `housing_keys` by id and checks holder, state, expiry, and property. Metadata is a pointer, not a permission.
- Stash ids are built on the server from the property and stash rows.
- Warrant and raid transitions use compare-and-swap updates.
- Admin callbacks call `ctx.isAdmin`.
- Payloads are size-limited. Identifiers are length-checked and matched against `^[a-z0-9_]+$`.
- Purchase, key, raid, and UI actions are rate-limited per character.
- Idempotency keys are 8–64 characters. Replays return the stored result instead of charging again.

Proximity uses the server's last known player position and the routing bucket policy. Client coordinates are not accepted as proof the player is at the door.

House image URLs are accepted only when the host is on the FiveManage allow-list. The API key is read from the `housing_fivemanage_key` convar on the server and is not sent to the NUI. A presigned upload URL is returned only to an owner or an admin.

Money and SQL cannot commit together. The compensation path is: reservation, charge, grant, or refund and release. An uncertain money result is `needs_review`. The reconciler does not invent a second refund.

Property archive does not delete inventory stash contents or evidence rows. Forcing an archive clears housing ownership, keys, and access records only.

Errors returned to the client are short codes (`not_authorised`, `insufficient_funds`, `warrant_invalid`). They do not include other players' inventories or server configuration.

What this resource does not claim:

- Distributed atomicity between the framework money API and MySQL.
- That lj-inventory or ps-inventory can securely open a stash. That path stays off unless `LegacyStashOpen` is enabled.
- That an MLO can be instanced.
- That the evidence ledger is a complete chain of custody once an item leaves this resource.
- That adapters have been verified on a live FiveM server. See `docs/TESTING.md`.
