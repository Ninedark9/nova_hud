fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'NOVA Framework'
description 'Framework-compatible HUD for NOVA, QBCore and ESX with circular minimap and vehicle HUD'
version '1.2.0'

ui_page 'web/index.html'

files {
  'web/index.html',
  'web/style.css',
  'web/app.js'
}

shared_script 'config.lua'
client_scripts { 'client/minimap.lua', 'client/framework.lua', 'client/main.lua' }
