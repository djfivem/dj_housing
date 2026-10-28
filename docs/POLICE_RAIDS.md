# Police, warrants, raids, and evidence

Police access is a separate path from resident access. A raid does not create an ownership or resident row.

## Who can act

`config/police.lua` lists job names and the minimum grade for that job. Defaults: `police` grade 1, `sheriff` grade 1, `state` grade 2. Request grade is 1. Approval grade is 3. Self-approval is rejected unless `allowSelfApproval` is true.

Standalone servers have no job. Add license identifiers to `Housing.Config.Frameworks.standalone.police`, or grant `housing.police`.

The housing UI shows Warrants only when the dashboard says the player is police, and Administration only when they are an admin. Those flags are computed on the server. Hiding a button is not the authorisation check. Every callback checks job, grade, and records again.

## Warrants

With no MDT configured, warrants are rows in `housing_warrants`.

A request stores the officer, property, reason, case reference, scope (`{ all = true }` or `{ stashes = { 'shared' } }`), seizure flag, and expiry. Seizure is stored only when both the request and `config/evidence.lua` `seizureEnabled` are true.

Another officer at the approval grade authorises or revokes. Expired and revoked warrants cannot be authorised. Opening a raid requires an authorised, unexpired warrant for that property, or an emergency entry.

Emergency entry is optional (`emergency.enabled`), requires `emergency.minGrade` (default 4), lasts `maxDurationMinutes`, and does not allow seizure unless `emergency.allowSeizure` is true.

## Raids

States: `requested` → `authorised` → `active` → `completed`, `cancelled`, or `expired`. The transition table rejects anything else, including `requested` → `active`.

`openRaid` records the lead officer and any extra officer server ids that currently have a police job. `setRaidState` to `active` requires `raid.minOfficers` (default 2) of those officers to be online. One property has one open raid.

Search and seizure require the raid to be `active`, the officer to be listed, the warrant to still be usable, and the stash key to be inside the raid scope. Proximity uses the server position when `raid.requireProximity` is true.

## Inspection and seizure

`inspectionMode = 'ledger'` asks the inventory adapter for stash contents and returns a reduced item list. It does not move items. `inventory_ui` calls the inventory's open-stash export and is not read-only. Leave it unset unless you want officers inside the live stash.

Seizure is a second callback. It re-checks the raid, warrant seizure flag, officer, stash, item, and quantity. The evidence id is the idempotency key. A retry of a completed seizure returns the existing row and does not remove the item again. `housing_key` is on the denylist. An uncertain inventory result leaves the evidence row `pending` for review instead of marking it seized.

`transferEvidence` moves a `seized` row to `transferred` or `released` and writes `housing_evidence_transfers`. That ledger is the chain this resource can prove. It is not a forensic chain of custody beyond those rows and the inventory's own logs.

## Optional integrations

`config/housing.lua` integrations default to none.

- Door lock preset `ox_doorlock` calls `setDoorState` when a raid becomes active and restores it when the raid ends. Other door resources need a custom function in the integrations adapter.
- Dispatch preset `ps-dispatch` triggers a client event because `CustomAlert` is a client export. No server export is called for it.
- An external evidence resource can be attached as `ctx.evidenceExternal`. Housing still writes its own ledger.
- Do not set an MDT warrant source unless that resource is installed. There is no second warrant authority in the default config.
