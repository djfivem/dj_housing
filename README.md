# advanced_housing

FiveM housing resource for property ownership, rentals, physical keys, inventory stashes, shell and MLO entry, warrants, raids, and an optional evidence ledger.

The resource folder must be named `advanced_housing`. The only required dependency is `oxmysql`. Frameworks and inventories are selected in config and are not all required at once.

```cfg
ensure oxmysql
ensure advanced_housing
```

Open the UI with `/housing`. Administration uses `/housingadmin` and the `housing.admin` ACE.

Installation, configuration, and the verification record are in [docs/INSTALLATION.md](docs/INSTALLATION.md) and [docs/TESTING.md](docs/TESTING.md).

The NUI in `web/dist` is the build that FiveM serves. Rebuild it with `cd web && npm install && npm run build` after changing `web/src`. The dev server shows sample data only while Vite is running. The production bundle does not include that sample data.
