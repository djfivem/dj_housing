# Testing

## Executed in this workspace

Command:

```bash
lua5.4 tests/run.lua
```

Result:

```text
RESULT 58 passed, 0 failed
```

The same run's checks cover property loading, duplicate ids, purchase debit and replay, price mismatch, insufficient funds, a second concurrent buyer losing, shell allow-list rejection, grant compensation, rental expiry, forged key metadata, guest keys isolated per property, revocation, stash authorisation, unknown and cross-property stashes, warrant self-approval, raid authorise-then-active, inspection, unrelated property search, seizure plus an idempotent retry, framework ambiguity, standalone admin denial and no overdraft, inventory ambiguity, rate limiting, and stable routing buckets.

Syntax:

```bash
find . -name '*.lua' -not -path './web/*' -print0 | xargs -0 luac5.4 -p
```

Result: `SYNTAX_OK` (exit 0).

Frontend:

```bash
cd web && npm run build
```

Result: `tsc --noEmit` and Vite build completed, writing `web/dist`.

A headless Chrome pass against the Vite dev server (`http://127.0.0.1:5173`) clicked purchase (insufficient funds on the $650,000 listing with a $482,750 balance), rental (balance changed and the notice said transaction complete), pay all bills, furniture purchase, stash open, guest key issue, and Escape (the UI unmounted). A second page `?desk=police` requested a warrant, observed self-approval, opened a raid, moved it to authorised then active, inspected a stash, and seized the inspected item. `?desk=admin` at 1366×768 archived the unowned Mirror Park listing. The dev page is the only place that sample data exists. The production bundle does not contain the dev fixture strings.

These UI checks drive the dev mock of the callback contract. They do not execute the Lua server.

## Not executed

No FiveM server, oxmysql, ESX, QBCore, Qbox, ox_inventory, qb-inventory, lj-inventory, ps-inventory, qs-inventory, ox_target, qb-target, ox_doorlock, or ps-dispatch is installed here. Adapters are coded against published exports and marked `liveVerified = false`. Passing the unit file does not verify a live inventory or a streamed shell.

Shell door offsets and the example entrance coordinates have not been walked in-game.

## Manual acceptance on a server

1. Start oxmysql and one framework. Confirm the console names that framework and does not say ambiguous.
2. Register `housing_key` using `docs/INVENTORIES.md`. Buy a property. Confirm the bank moved once, `housing_ownership` has the character id, and the key item exists.
3. Restart the server. Confirm ownership and the stash contents (in the inventory resource) are still there.
4. Attempt a second purchase of the same property from another client. It must fail.
5. Revoke the key. The item must stop opening the door.
6. Enter and exit a shell, an IPL, and an MLO. Confirm the shell uses a routing bucket and the MLO does not. Disconnect inside the shell and confirm the player is not left in that bucket.
7. With two police characters, request and authorise a warrant, start a raid, inspect one stash, and confirm a different property's stash is rejected. Seize one item with seizure enabled and retry the same idempotency key. The item count must drop once.
8. As a civilian, call `requestWarrant` from the NUI. It must return `not_authorised`.
9. Archive an owned property without `force`. It must fail. Evidence rows must remain.
