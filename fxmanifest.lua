fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'advanced_housing'
author 'advanced_housing'
description 'Property ownership, rentals, keys, stashes, shells, MLOs, warrants and raids'
version '1.0.0'

shared_scripts {
    'shared/init.lua',
    'shared/constants.lua',
    'shared/enums.lua',
    'shared/utilities.lua',
    'shared/validation.lua',
    'shared/locales.lua',
    'config/shared.lua',
    'config/framework.lua',
    'config/inventory.lua',
    'config/permissions.lua',
    'config/performance.lua',
    'config/evidence.lua',
    'config/police.lua',
    'config/shells.lua',
    'config/housing.lua',
    'config/properties.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/repository_mysql.lua',
    'server/repository_memory.lua',
    'server/migrations.lua',
    'server/domain/ratelimit.lua',
    'server/domain/auth.lua',
    'server/domain/money.lua',
    'server/domain/transaction.lua',
    'server/domain/rental.lua',
    'server/domain/keys.lua',
    'server/domain/stash.lua',
    'server/domain/police.lua',
    'server/domain/property_ops.lua',
    'server/domain/reconcile.lua',
    'server/domain/dashboard.lua',
    'server/adapters/framework.lua',
    'server/adapters/inventory.lua',
    'server/adapters/integrations.lua',
    'server/runtime.lua',
    'server/callbacks.lua',
    'server/main.lua',
}

client_scripts {
    'client/callbacks.lua',
    'client/interiors.lua',
    'client/furniture.lua',
    'client/garage.lua',
    'client/nui.lua',
    'client/interactions.lua',
    'client/main.lua',
}

ui_page 'web/dist/index.html'

files {
    'web/dist/index.html',
    'web/dist/assets/*',
    'locales/en.json',
}

dependencies {
    'oxmysql',
}
