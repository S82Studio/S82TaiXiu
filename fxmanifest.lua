fx_version 'cerulean'
game 'gta5'

author 'S82 Studio'
description 'S82 Tài Xỉu - Premium Edition (Đa Core: ESX / QBCore / QBX)'
version '2.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/framework.lua',
    'server.lua'
}

client_scripts {
    'client.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/fonts/Roboto-Medium.ttf',
    'html/fonts/Roboto-Bold.ttf',
    'html/fonts/Roboto-Black.ttf'
}

lua54 'yes'

-- Không khai báo cứng dependency framework (esx/qb-core/qbx_core) vì
-- script tự nhận diện lúc runtime (xem bridge/framework.lua + Config.Framework).
-- oxmysql và ox_lib vẫn là bắt buộc cho mọi core.
dependencies {
    'oxmysql',
    'ox_lib'
}
