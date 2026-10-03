fx_version 'cerulean'
game 'gta5'

dependencies {
    'oxmysql',
    'ox_lib',
    'qbx_core',
    'vanguard_lib'
}

shared_scripts {
    '@ox_lib/init.lua',
    '@vanguard_lib/init.lua',
    'config/config.lua'
}

client_scripts {
    'modules/vip-manager/client/*.lua',
    'script/client-side/modules/*.lua',
    'script/client-side/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'script/server-side/utils/*.lua',
    'modules/vip-manager/server/database.lua',
    'modules/vip-manager/server/controller.lua',
    'modules/vip-manager/server/callbacks.lua',
    'script/server-side/core/*.lua',
    'script/server-side/controllers/*.lua',
    'script/server-side/*.lua'
}

ui_page 'script/web-side/index.html'

files {
    'script/web-side/*',
    'script/web-side/**'
}
