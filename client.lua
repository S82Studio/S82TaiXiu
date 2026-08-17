-- ═══════════════════════════════════════════════════════════════
-- S82 TÀI XỈU - CLIENT SIDE v2.0
-- Framework: ESX / QBCore / QBX (client không gọi framework trực tiếp)
-- Notify: ox_lib
-- ═══════════════════════════════════════════════════════════════

local isUIOpen = false

-- ═══════════════════════════════════════════════════════════════
-- UI CONTROL
-- ═══════════════════════════════════════════════════════════════

local function OpenUI()
    if isUIOpen then return end
    isUIOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open' })

    -- Lấy dữ liệu mới nhất từ server khi mở
    TriggerServerEvent('s82taixiu:server:getUIData')

    -- Disable game controls khi UI mở
    CreateThread(function()
        while isUIOpen do
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 106, true)
            DisableControlAction(0, 200, true)
            Wait(0)
        end
    end)
end

local function CloseUI()
    if not isUIOpen then return end
    isUIOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

-- ═══════════════════════════════════════════════════════════════
-- COMMANDS & KEY MAPPING
-- ═══════════════════════════════════════════════════════════════

RegisterCommand('s82taixiu', function()
    if isUIOpen then CloseUI() else OpenUI() end
end, false)

RegisterKeyMapping('s82taixiu', 'Mở/Đóng S82 Tài Xỉu', 'keyboard', '')

-- ═══════════════════════════════════════════════════════════════
-- NUI CALLBACKS
-- ═══════════════════════════════════════════════════════════════

RegisterNUICallback('close', function(data, cb)
    CloseUI()
    cb('ok')
end)

RegisterNUICallback('bet', function(data, cb)
    local amount = tonumber(data.amount)
    local choice = data.choice

    if not amount or amount <= 0 then
        lib.notify({ title = 'S82 Tài Xỉu', description = 'Số tiền không hợp lệ!', type = 'error', duration = 3000 })
        cb('ok')
        return
    end

    if choice ~= 'tai' and choice ~= 'xiu' then
        cb('ok')
        return
    end

    TriggerServerEvent('s82taixiu:server:bet', choice, amount)
    cb('ok')
end)

RegisterNUICallback('getStats', function(data, cb)
    TriggerServerEvent('s82taixiu:server:getPlayerStats')
    cb('ok')
end)

-- ═══════════════════════════════════════════════════════════════
-- NOTIFICATIONS (ox_lib)
-- ═══════════════════════════════════════════════════════════════

RegisterNetEvent('s82taixiu:client:notify', function(data)
    lib.notify({
        title       = data.title       or 'S82 Tài Xỉu',
        description = data.description or '',
        type        = data.type        or 'inform',
        duration    = data.duration    or 5000,
    })
end)

-- ═══════════════════════════════════════════════════════════════
-- GAME EVENTS
-- ═══════════════════════════════════════════════════════════════

-- Nhận update đồng hồ + trạng thái
RegisterNetEvent('s82taixiu:client:update', function(data)
    if not isUIOpen then return end
    SendNUIMessage({ action = 'update', data = data })
end)

-- Khóa cược
RegisterNetEvent('s82taixiu:client:locked', function()
    if isUIOpen then
        SendNUIMessage({ action = 'locked' })
    end
    lib.notify({
        title       = '🔒 Khóa Cược',
        description = 'Đã khóa đặt cược! Xúc xắc sắp được lắc...',
        type        = 'warning',
        duration    = 3000,
    })
end)

-- Kết quả xúc xắc
RegisterNetEvent('s82taixiu:client:result', function(data)
    if isUIOpen then
        SendNUIMessage({ action = 'result', data = data })
    end
end)

-- Vòng mới
RegisterNetEvent('s82taixiu:client:newRound', function(data)
    if isUIOpen then
        SendNUIMessage({ action = 'newRound', data = data })
    end
end)

-- Lịch sử
RegisterNetEvent('s82taixiu:client:history', function(history)
    if isUIOpen then
        SendNUIMessage({ action = 'history', history = history })
    end
end)

-- Cập nhật pool cược real-time
RegisterNetEvent('s82taixiu:client:poolUpdate', function(pool)
    if isUIOpen then
        SendNUIMessage({ action = 'poolUpdate', pool = pool })
    end
end)

-- Xác nhận đặt cược
RegisterNetEvent('s82taixiu:client:betPlaced', function(data)
    if isUIOpen then
        SendNUIMessage({ action = 'betPlaced', data = data })
    end
    -- Cập nhật số dư ngay sau khi tiền bị trừ
    if data.newBalance ~= nil then
        SendNUIMessage({ action = 'updateBalance', balance = data.newBalance })
    end
end)

-- Cập nhật số dư sau khi có kết quả thắng/thua/hòa
RegisterNetEvent('s82taixiu:client:updateBalance', function(newBalance)
    if isUIOpen then
        SendNUIMessage({ action = 'updateBalance', balance = newBalance })
    end
end)

-- Nhận data UI đầy đủ (khi mở)
RegisterNetEvent('s82taixiu:client:receiveUIData', function(data)
    SendNUIMessage({ action = 'receiveUIData', data = data })
end)

-- Nhận stats cá nhân
RegisterNetEvent('s82taixiu:client:receiveStats', function(stats)
    if isUIOpen then
        SendNUIMessage({ action = 'receiveStats', stats = stats })
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- RESOURCE EVENTS
-- ═══════════════════════════════════════════════════════════════

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        print('^2[S82-TAIXIU] Client v1.0 đã khởi động!^7')
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if isUIOpen then CloseUI() end
    end
end)