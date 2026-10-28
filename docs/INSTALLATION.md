# Installation

## Place the resource

Copy this repository to `resources/advanced_housing`. The folder name has to match the resource name in `fxmanifest.lua`.

## Database

Start `oxmysql` before this resource. Apply `database/schema.sql` once, or let the resource run `database/migrations/001_init.sql` on first boot. The migration runner records the version in `housing_schema_migrations` and does not drop tables.

Housing does not store stash item rows. The selected inventory owns those contents.

## server.cfg

```cfg
ensure oxmysql
ensure advanced_housing
```

Start the framework and the chosen inventory before `advanced_housing` when you rely on automatic detection. If more than one framework (`es_extended`, `qb-core`, `qbx_core`) or more than one supported inventory is started, the resource refuses to guess and prints `ambiguous_framework` or `ambiguous_inventory`. Set `Housing.Config.Framework` and `Housing.Config.Inventory` in `config/shared.lua` in that case.

## Permissions

```cfg
add_ace group.admin housing.admin allow
add_ace group.admin housing.police allow
```

`housing.police` is an override. Job and grade checks in `config/police.lua` are the normal police path. Standalone mode does not treat every player as admin or police. Add license identifiers to `Housing.Config.Frameworks.standalone.admins` and `.police` only for the people who should have those roles.

## Frontend

`web/dist` is already built. After editing `web/src`:

```bash
cd web
npm install
npm run build
```

## First boot checks

The server console reports the selected framework, inventory, and any integration that is configured but not started. A missing optional integration is skipped. A missing required adapter (`oxmysql`, or the explicitly selected framework or inventory) stops that part of the resource and is printed. It does not fall back to an open inventory or to unrestricted admin.
