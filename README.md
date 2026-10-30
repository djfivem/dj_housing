# advanced_housing

FiveM housing resource for property ownership, rentals, physical keys, inventory stashes, shell and MLO entry, warrants, raids, and an optional evidence ledger.

The resource folder must be named `advanced_housing`. `oxmysql` and `PolyZone` are required. One framework and one inventory are selected in config.

```cfg
ensure oxmysql
ensure PolyZone
ensure advanced_housing
```

Open the UI with `/housing`. Administration uses `/housingadmin` and the `housing.admin` ACE.

How to play it and how to test it: [docs/HOW_TO_USE.md](docs/HOW_TO_USE.md). Installation detail is in [docs/INSTALLATION.md](docs/INSTALLATION.md). The verification record is in [docs/TESTING.md](docs/TESTING.md).

The NUI in `web/dist` is the build that FiveM serves. Rebuild it with `cd web && npm install && npm run build` after changing `web/src`. The dev server shows sample data only while Vite is running. The production bundle does not include that sample data.
