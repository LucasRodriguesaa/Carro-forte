fx_version 'cerulean'
game 'gta5'

author      'Custom Script'
description 'Entregador de Carro Forte para vRPEx'
version     '2.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/ui.lua',   -- precisa carregar antes para expor CF_Toast/CF_ShowHUD
    'client/main.lua'
}

server_scripts {
    '@vrp/lib/utils.lua',
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}
