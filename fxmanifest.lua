fx_version 'cerulean'
use_experimental_fxv2_oal 'yes'
lua54 'yes'
game 'gta5'

name 'sleepless_prompts'
author 'Sleepless Development'
version '1.0.0'
description 'Input prompt HUD library'

ui_page 'web/index.html'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
}

client_scripts {
    'init.lua',
    'client/*.lua',
}

server_scripts {
    'server/version.lua',
}

files {
    'locales/*.json',
    'web/**',
    'client/modules/*.lua',
    'client/framework/*.lua',
}

dependency 'ox_lib'
