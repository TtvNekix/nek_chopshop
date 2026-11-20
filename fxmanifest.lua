fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Nekix'
description 'Scrapyard System By Nekix'
version '2.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'shared/framework.lua',
    'shared/inventory.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'editable/server.lua',
    'server/bridge.lua',
    'server/inventory.lua',
    'server/functions.lua',
    'server/checker.lua',
    'server/dispatch.lua',
    'server/keys.lua',
    'server/reputation.lua',
    'server/main.lua',
    'server/admin.lua'
}

client_scripts {
    'editable/client.lua',
    'client/bridge.lua',
    'client/nui.lua',
    'client/functions.lua',
    'client/dispatch.lua',
    'client/interact.lua',
    'client/main.lua'
}

ui_page 'web/index.html'

files {
    'locales/*.json',
    'web/index.html',
    'web/app.js',
    'web/core/*.js',
    'web/components/*.js',
    'web/styles/*.css'
}

dependencies {
    'ox_lib',
    'ox_target',
    'oxmysql'
}
