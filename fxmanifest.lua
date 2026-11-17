fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Nekix'
description 'Scrapyard System By Nekix'
version '1.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'shared/framework.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'editable/server.lua',
    'server/*.lua'
}

client_scripts {
    'editable/client.lua',
    'client/*.lua'
}

dependencies {
    'ox_lib',
    'ox_target',
    'ox_inventory'
}
