# API

NUI callbacks are forwarded by `client/nui.lua` to the server allow-list. Send JSON. The response is `{ ok = true, data = ... }` or `{ ok = false, error = 'code' }`.

| Callback | Main fields |
| --- | --- |
| `dashboard` | `propertyId` optional |
| `purchase`, `rent`, `renew` | `propertyId`, `idempotencyKey`, `mode` (`purchase`, `rent`, or `renew`), optional `expectedPrice`, optional `shellModel` from the allow-list |
| `sell` | same shape as purchase, `mode` must be `purchase`, `expectedPrice` must equal the configured sale return |
| `list` | `propertyId`, `price` |
| `unlist` | `propertyId` |
| `enter`, `exit` | `propertyId` on enter |
| `payBill` | `billId` |
| `setPropertyImage` | `propertyId`, `imageUrl` (`https` on an allowed FiveManage host) |
| `prepareImageUpload` | `propertyId`. Returns a presigned URL for the owner or an admin. The API key is not included. |
| `captureImage` | Client only. Uses `screenshot-basic` after `prepareImageUpload`, then calls `setPropertyImage`. |
| `payAll` | `propertyId` |
| `buyFurniture` | `propertyId`, `catalogId`, `idempotencyKey` |
| `placeFurniture` | `furnitureId`, placement coordinates |
| `buyUpgrade` | `propertyId`, `upgradeId`, `idempotencyKey` |
| `storeVehicle`, `takeVehicle`, `restoreVehicle` | `propertyId`, `vehicleId` |
| `openStash` | `propertyId`, `stashKey` |
| `grantAccess` | `propertyId`, `idempotencyKey`, `role`, `targetCharacterId`, `targetFramework`, `displayName` |
| `revokeAccess` | `propertyId`, `targetFramework`, `targetCharacterId` |
| `issueKey` | `propertyId`, `idempotencyKey`, `accessLevel`, optional `targetSource` |
| `revokeKey`, `recoverKey` | `keyId` |
| `transferKey` | `keyId`, `targetSource` |
| `revokePropertyKeys` | `propertyId` |
| `requestWarrant` | `propertyId`, `idempotencyKey`, `reason`, `caseReference`, `durationHours`, `scope`, `allowSeizure` |
| `decideWarrant` | `warrantId`, `decision` (`authorise` or `revoke`) |
| `openRaid` | `propertyId`, `warrantId` or `emergency`, `idempotencyKey`, `officerSources` |
| `setRaidState` | `raidId`, `state` |
| `inspectStash` | `propertyId`, `stashKey` |
| `seize` | `propertyId`, `stashKey`, `raidId`, `itemName`, `quantity`, `idempotencyKey`, optional `slot` |
| `transferEvidence` | `evidenceId`, `status` (`transferred` or `released`), optional `note` |
| `adminEnable` | `propertyId`, `enabled` |
| `adminArchive` | `propertyId`, `force` |
| `adminTransfer` | `propertyId`, `targetSource` |
| `adminRepair` | `propertyId` |
| `collectPayouts` | none |

Server exports: `HasGarageAccess(source, propertyId)` and `GetPropertyGarages()`. Other resources should not call inventory or framework exports through housing. To add a framework or inventory, implement the adapter table and register it in the detector.

## Custom inventory contract

See `docs/INVENTORIES.md`. Export names are strings in `Housing.Config.CustomInventory.exports`. The housing server calls `exports[resource][exportName](...)` only when that resource's state is `started`.

## Custom notification

Set `Housing.Config.Notification = 'custom'` and `Housing.Config.CustomNotifyEvent` to a client event that accepts `(message)`.

## Door, garage, dispatch, evidence

`config/housing.lua` `integrations` selects a preset name, `auto`, or `none`. Unknown names are reported and not called. A custom door or evidence hook is a function assigned on the server context in `server/adapters/integrations.lua`. Keep that code out of the purchase and raid services. Banking records a player statement after the framework has already moved the money. Garage registration uses the published house APIs named in `docs/HOUSING.md`.
