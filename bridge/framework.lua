-- ═══════════════════════════════════════════════════════════════
-- S82 TÀI XỈU — BRIDGE ĐA CORE (ESX / QBCore / QBX)
-- Tự động nhận diện core & hệ túi đồ đang chạy trên server.
-- Toàn bộ server.lua chỉ gọi qua bảng "Bridge", không gọi thẳng
-- framework để không phải sửa logic khi đổi core.
-- ═══════════════════════════════════════════════════════════════

Bridge = {}

local function ResourceRunning(name)
    local state = GetResourceState(name)
    return state == 'started' or state == 'starting'
end

-- ────────────────────────────────────────────────────
-- NHẬN DIỆN FRAMEWORK
-- ────────────────────────────────────────────────────

local Framework = Config.Framework
if not Framework or Framework == 'auto' then
    if ResourceRunning('qbx_core') then
        Framework = 'qbx'
    elseif ResourceRunning('qb-core') then
        Framework = 'qbcore'
    elseif ResourceRunning('es_extended') then
        Framework = 'esx'
    else
        Framework = nil
    end
end
Bridge.Framework = Framework

local ESX, QBCore = nil, nil

CreateThread(function()
    if Framework == 'esx' then
        ESX = exports['es_extended']:getSharedObject()
    elseif Framework == 'qbcore' then
        QBCore = exports['qb-core']:GetCoreObject()
    end

    if Framework then
        print(('^2[S82-TAIXIU] Đã nhận diện framework: ^3%s^7'):format(Framework))
    else
        print('^1[S82-TAIXIU] KHÔNG tìm thấy framework (ESX/QBCore/QBX)! Script sẽ không hoạt động đúng.^7')
    end
end)

-- ────────────────────────────────────────────────────
-- NHẬN DIỆN HỆ TÚI ĐỒ (cho phần thưởng vật phẩm, tuỳ chọn)
-- ────────────────────────────────────────────────────

local Inventory = Config.Inventory
if not Inventory or Inventory == 'auto' then
    if ResourceRunning('ox_inventory') then
        Inventory = 'ox_inventory'
    elseif ResourceRunning('qb-inventory') then
        Inventory = 'qb-inventory'
    elseif ResourceRunning('ps-inventory') then
        Inventory = 'ps-inventory'
    elseif ResourceRunning('qs-inventory') then
        Inventory = 'qs-inventory'
    elseif ResourceRunning('core_inventory') then
        Inventory = 'core_inventory'
    elseif Framework == 'esx' then
        Inventory = 'esx' -- dùng inventory gốc của ESX (addInventoryItem)
    else
        Inventory = nil
    end
end
Bridge.Inventory = Inventory

-- ═══════════════════════════════════════════════════════════════
-- PLAYER — LẤY OBJECT NGƯỜI CHƠI
-- ═══════════════════════════════════════════════════════════════

function Bridge.GetPlayer(src)
    if Framework == 'esx' then
        return ESX and ESX.GetPlayerFromId(src) or nil
    elseif Framework == 'qbcore' then
        return QBCore and QBCore.Functions.GetPlayer(src) or nil
    elseif Framework == 'qbx' then
        return exports.qbx_core:GetPlayer(src)
    end
    return nil
end

-- Định danh duy nhất của người chơi (dùng làm khoá lưu DB)
-- ESX  -> identifier (license:xxxx)
-- QB/QBX -> citizenid
function Bridge.GetIdentifier(Player)
    if not Player then return nil end
    if Framework == 'esx' then
        return Player.identifier
    else
        return Player.PlayerData.citizenid
    end
end

function Bridge.GetName(Player)
    if not Player then return 'Unknown' end
    if Framework == 'esx' then
        local ok, name = pcall(function() return Player.getName() end)
        if ok and name and name ~= '' then return name end
        return ('%s %s'):format(Player.get('firstName') or '', Player.get('lastName') or '')
    else
        local ci = Player.PlayerData.charinfo
        return (ci.firstname or '') .. ' ' .. (ci.lastname or '')
    end
end

-- ═══════════════════════════════════════════════════════════════
-- TIỀN TỆ — GET / ADD / REMOVE
-- account: 'cash' hoặc 'bank' (được map phù hợp cho từng core)
-- ESX     : cash -> Player.getMoney()/addMoney()/removeMoney()
--           bank -> Player.getAccount('bank')/addAccountMoney()/removeAccountMoney()
-- QB/QBX  : Player.Functions.GetMoney(account) / AddMoney / RemoveMoney
-- ═══════════════════════════════════════════════════════════════

function Bridge.GetMoney(Player, account)
    account = account or 'cash'
    if not Player then return 0 end

    if Framework == 'esx' then
        if account == 'cash' then
            return Player.getMoney and Player.getMoney() or 0
        else
            local acc = Player.getAccount and Player.getAccount(account)
            return acc and acc.money or 0
        end
    elseif Framework == 'qbcore' or Framework == 'qbx' then
        return Player.Functions.GetMoney(account) or 0
    end
    return 0
end

function Bridge.AddMoney(Player, account, amount)
    account = account or 'cash'
    if not Player or amount <= 0 then return false end

    if Framework == 'esx' then
        if account == 'cash' then
            Player.addMoney(amount)
        else
            Player.addAccountMoney(account, amount)
        end
        return true
    elseif Framework == 'qbcore' or Framework == 'qbx' then
        return Player.Functions.AddMoney(account, amount, 's82taixiu')
    end
    return false
end

function Bridge.RemoveMoney(Player, account, amount)
    account = account or 'cash'
    if not Player or amount <= 0 then return false end

    if Framework == 'esx' then
        local current = Bridge.GetMoney(Player, account)
        if current < amount then return false end
        if account == 'cash' then
            Player.removeMoney(amount)
        else
            Player.removeAccountMoney(account, amount)
        end
        return true
    elseif Framework == 'qbcore' or Framework == 'qbx' then
        return Player.Functions.RemoveMoney(account, amount, 's82taixiu')
    end
    return false
end

-- ═══════════════════════════════════════════════════════════════
-- TÚI ĐỒ — THÊM VẬT PHẨM (dùng cho phần thưởng vật phẩm tuỳ chọn)
-- Hỗ trợ: ox_inventory, qb-inventory, ps-inventory, qs-inventory,
--         core_inventory, esx (built-in)
-- ═══════════════════════════════════════════════════════════════

function Bridge.AddItem(src, item, count, metadata)
    count = count or 1
    if not item or count <= 0 then return false end

    if Inventory == 'ox_inventory' then
        return exports.ox_inventory:AddItem(src, item, count, metadata)

    elseif Inventory == 'qb-inventory' or Inventory == 'ps-inventory' or Inventory == 'qs-inventory' or Inventory == 'core_inventory' then
        local Player = Bridge.GetPlayer(src)
        if not Player then return false end
        return Player.Functions.AddItem(item, count, false, metadata)

    elseif Inventory == 'esx' then
        local Player = Bridge.GetPlayer(src)
        if not Player then return false end
        Player.addInventoryItem(item, count)
        return true
    end

    return false
end

-- Kiểm tra item có tồn tại trong danh sách vật phẩm của core hiện tại không
-- (dùng ox_lib item registry hoặc bảng shared items của ESX/QB nếu cần mở rộng sau này)
function Bridge.DoesItemExist(item)
    if Inventory == 'ox_inventory' then
        local items = exports.ox_inventory:Items()
        return items and items[item] ~= nil
    end
    return true -- không kiểm tra được thì mặc định cho phép, tránh chặn nhầm
end
