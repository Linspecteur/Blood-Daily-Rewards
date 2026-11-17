fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'BloodLeak'
description 'Récompenses journalières (série de 7 jours)'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'locales/*.lua',     -- une langue par fichier (fr.lua, en.lua, ...)
    'shared/locale.lua', -- applique Config.Language
    'bridge/detect.lua'  -- ESX ou QBCore
}

client_scripts {
    'bridge/client.lua',
    'client/main.lua'
}

-- config_server.lua n'est JAMAIS envoyé aux clients (le webhook Discord y est protégé)
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config_server.lua',
    'bridge/server.lua',
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

-- es_extended (ESX) OU qb-core (QBCore) : détecté automatiquement
dependencies {
    'oxmysql',
    'ox_lib'
}
