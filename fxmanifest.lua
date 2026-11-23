fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'XS-Garages'
author 'XyraL'
description 'Garages for Qbox and QBCore, built in game: public, job, gang, private and impound lots, with parked cars in their bays, motor pools, transfers and a police impound.'
version '1.0.0'

dependencies {
    'ox_lib',
    'oxmysql',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'locales/en.lua',
    'shared/locale.lua',
    'shared/util.lua',
    'shared/standard.lua',
    'shared/settings.lua',
}

client_scripts {
    'bridge/framework.lua',
    'bridge/target.lua',
    'bridge/keys.lua',
    'bridge/fuel.lua',
    'client/ui.lua',
    'client/settings.lua',
    'client/main.lua',
    'client/vehicle.lua',
    'client/cabinet.lua',
    'client/display.lua',
    'client/impound.lua',
    'client/placement.lua',
    'client/builder.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/framework.lua',
    'bridge/keys.lua',
    'bridge/banking.lua',
    'server/db.lua',
    'server/settings.lua',
    'server/logs.lua',
    'server/garages.lua',
    'server/vehicles.lua',
    'server/spawn.lua',
    'server/private.lua',
    'server/fleet.lua',
    'server/parking.lua',
    'server/impound.lua',
    'server/builder.lua',
    'server/exports.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/*.css',
    'html/js/*.js',
}
