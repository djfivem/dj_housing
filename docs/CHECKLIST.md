# Implementation checklist

## Done

- Shared constants, validation, enums, and config for framework, inventory, police, shells, properties, and performance.
- SQL schema and `database/migrations/001_init.sql`.
- Domain services for purchase, rental, keys, stashes, warrants, raids, seizure, bills, furniture, garage records, and admin repair. Covered by `lua5.4 tests/run.lua`: 58 passed, 0 failed.
- Framework adapters for ESX, QBCore, Qbox, and standalone, with ambiguity refusal.
- Inventory adapters for ox_inventory, qb-inventory, qs-inventory, lj-inventory, ps-inventory, and a custom export map. `liveVerified` is false on every adapter.
- Client entry, shell spawn, MLO/IPL path, markers, NUI focus, and resource-stop cleanup.
- NUI management window in the orange (`#ff7a18`) palette: grouped sidebar, property page, marketplace, bills, keys, permissions, upgrades, furniture, garage, and storage. Warrant and admin desks stay bound to the real callback names. `npm run build` succeeded. Headless Chrome exercised purchase failure, a single rental, one bill payment, furniture order, vehicle spawn, marketplace filters, Escape, the police desk, and the admin desk against the Vite dev mock. Preview images are in `preview/`.
- Docs listed in the resource request.

## Not done, because this workspace has no FiveM server

- Live oxmysql migration run.
- Live framework money calls.
- Live inventory item and stash calls.
- In-game shell, MLO, and IPL coordinate confirmation.
- ox_target, qb-target, ox_doorlock, and ps-dispatch calls.

## Lua syntax

`luac5.4 -p` on every `*.lua` file outside `web/` exited 0.
