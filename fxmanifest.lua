fx_version 'cerulean'
game 'gta5'

description 'DjonStNix Vehicle Giver - Secure Preview, Customization, and Ownership (Multi-Framework)'
version '1.1.0'
author 'DjonStNix'

dependencies {
    'DjonStNix-Bridge'
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

lua54 'yes'
