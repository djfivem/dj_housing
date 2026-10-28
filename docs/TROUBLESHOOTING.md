# Troubleshooting

## The resource stops during startup

- `ambiguous_framework` or `ambiguous_inventory`: more than one supported resource is started. Set the config value explicitly.
- `oxmysql` is missing: it is the only hard dependency. Start it first.
- A selected framework or inventory resource is not started: the adapter returns a not-started error and does not switch to standalone or to a fake inventory.
- Property validation errors name the property id and the field (duplicate id, bad coordinates, shell model not in the allow-list).

## A purchase charged money and did not grant the house

Look up the idempotency key in `housing_transactions`. `needs_review` means the money call failed in an uncertain way. Do not click purchase again with a new key until you confirm the balance. `failed` with `money_state = refunded` means compensation ran. The reservation sweeper releases a `reserved` property after the timeout if no transaction still holds it.

## Keys

The player owns the property but has no key item: the inventory `AddItem` failed after the key row was written. Use key recovery from the admin command. Revoking a key updates `housing_keys.state`. An item left in the inventory no longer passes the door check.

## Stashes

`inspection_unsupported` or a failed open on lj-inventory or ps-inventory is expected while `LegacyStashOpen` is false. ox_inventory, qb-inventory, and qs-inventory register stashes through their own exports. If contents disappear, check that inventory's database, not `housing_*` tables.

## Shells and interiors

`shell_failed` means the model did not load before the timeout. Stream the model and check the name against `config/shells.lua`. Players who disconnect inside a shell are moved back by the disconnect handler. Resource stop clears NUI focus and resets routing buckets for players this resource moved.

MLO and IPL entry that puts the player in the wrong room is a coordinate problem in `config/properties.lua`. The resource will not try to spawn a shell for those types.

## Police

`self_approval`, `warrant_invalid`, `warrant_expired`, `raid_state`, `insufficient_officers`, `outside_scope`, and `seizure_not_authorised` are policy failures, not bugs. Authorise with a second officer, keep the raid `active`, and include the stash in the warrant scope.

## UI focus stuck

Restarting the resource runs the client stop handler, which calls `SetNuiFocus(false, false)`. Escape sends the `close` callback. If a production NUI page is blank, rebuild `web/dist` and confirm `ui_page` is `web/dist/index.html`.

## Slow queries

Enable the MySQL slow log. Hot lookups are property id, character id on ownership and access, and stash id. Those columns are indexed in `database/schema.sql`. The client does not query the database per frame. Use `profiler` and `resmon` in a running server before judging CPU. This repository has no live server profile.
