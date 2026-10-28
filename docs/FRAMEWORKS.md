# Frameworks

Adapters live in `server/adapters/framework.lua`. Domain code calls `ctx.framework` and does not call ESX, QBCore, or Qbox exports directly.

## Detection

Automatic mode checks `GetResourceState` for `es_extended`, `qb-core`, and `qbx_core`.

- One of those resources is started: that adapter is used.
- More than one is started: startup fails with `ambiguous_framework`. Set `Housing.Config.Framework` explicitly.
- None is started: standalone is used.

Restarting the framework resource rebinds the adapter. It does not leave the previous object in place.

## Interface

Each adapter implements player lookup, a stable character id, job and grade, admin and ACE checks, get/add/remove money, notifications, and source lookup by character id. Identity is resolved on the server from the framework player object.

## ESX

Character id is the ESX identifier. Money uses `getAccount` / `addAccountMoney` / `removeAccountMoney`. `removeAccountMoney` does not reliably return success, so the adapter reads the balance before and after. Admin groups are `admin` and `superadmin`, plus the `housing.admin` ACE.

## QBCore

Character id is `citizenid`. Money uses `Functions.AddMoney` and `Functions.RemoveMoney`. A `pcall` failure is returned as `uncertain` and is not treated as a successful charge or refund. Admin permissions are `admin` and `god`, plus the housing ACE.

## Qbox

Character id is `citizenid`. Money uses `GetMoney`, `AddMoney`, and `RemoveMoney`. `HasPermission` is not used; admin checks use ACE (`admin`, `god`, `housing.admin`), matching current Qbox guidance.

## Standalone

Character id is the player's license identifier. Money is a row in `housing_balances`. New characters start at `startingBank` / `startingCash`, both `0` by default. There is no overdraft. `admins` and `police` lists are empty by default. A player is an admin only when their license is listed or they have the `housing.admin` ACE.

## Not verified on a live server

These adapters follow the published exports of each framework. This repository's tests call them with an in-memory environment. They have not been executed inside a running FiveM server. `liveVerified` is not set on the framework adapters.
