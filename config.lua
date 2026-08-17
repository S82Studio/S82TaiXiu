-- ═══════════════════════════════════════════════════════════════
-- S82 TÀI XỈU — CONFIG
-- Tất cả thông số điều chỉnh tại đây
-- ═══════════════════════════════════════════════════════════════

Config = {}

-- ────────────────────────────────────────────────────
-- FRAMEWORK & TÚI ĐỒ (ĐA CORE)
-- ────────────────────────────────────────────────────
-- Config.Framework: 'auto' (tự nhận diện) | 'esx' | 'qbcore' | 'qbx'
-- 'auto' sẽ tự dò theo thứ tự: qbx_core -> qb-core -> es_extended
Config.Framework = 'auto'

-- Config.Inventory: hệ túi đồ dùng để phát vật phẩm thưởng (mục Config.ItemReward bên dưới)
-- 'auto' (tự nhận diện) | 'ox_inventory' | 'qb-inventory' | 'ps-inventory' | 'qs-inventory' | 'core_inventory' | 'esx'
Config.Inventory = 'auto'

-- Loại tiền dùng để cược / trả thưởng chính
-- 'cash' : QB/QBX = ví tiền mặt | ESX = Player.getMoney() (money)
-- 'bank' : QB/QBX = tài khoản ngân hàng | ESX = tài khoản 'bank'
Config.Currency = 'cash'

-- ────────────────────────────────────────────────────
-- PHẦN THƯỞNG VẬT PHẨM (TUỲ CHỌN)
-- Ngoài tiền thắng cược, có thể tặng thêm vật phẩm khi thắng.
-- Vật phẩm phải tồn tại trong hệ túi đồ (ox_inventory items.lua,
-- qb-core shared items, hoặc esx_items) — script không tự tạo item.
-- ────────────────────────────────────────────────────
Config.ItemReward = {
    enabled = false,        -- true = bật tặng vật phẩm khi thắng
    item    = 'gold_chip',  -- tên item (item name) trong hệ túi đồ
    amount  = 1,            -- số lượng tặng mỗi lần thắng
    minWinAmount = 500000,  -- chỉ tặng item nếu tiền thắng >= mức này (0 = luôn tặng khi thắng)
}

-- ────────────────────────────────────────────────────
-- THỜI GIAN VÒNG CHƠI
-- ────────────────────────────────────────────────────
Config.RoundTime    = 600       -- Tổng thời gian 1 vòng (giây) — mặc định 10 phút
Config.LockTime     = 30        -- Khóa đặt cược trước X giây cuối mỗi vòng
Config.ResultDelay  = 6         -- Giây hiển thị kết quả trước khi bắt đầu vòng mới

-- ────────────────────────────────────────────────────
-- TIỀN CƯỢC
-- ────────────────────────────────────────────────────
Config.MinBet          = 50000      -- Cược tối thiểu
Config.MaxBet          = 5000000    -- Cược tối đa
Config.PayoutRate      = 1.9        -- Tỉ lệ nhận (ví dụ: cược 100K thắng → nhận 190K)
Config.MaxBetsPerRound = 1          -- Số lần cược tối đa mỗi player mỗi vòng

-- ────────────────────────────────────────────────────
-- KẾT QUẢ XÚC XẮC (tổng 3 xúc xắc)
-- ────────────────────────────────────────────────────
Config.TaiMin     = 11          -- Tài: tổng từ
Config.TaiMax     = 17          -- Tài: tổng đến
Config.XiuMin     = 4           -- Xỉu: tổng từ
Config.XiuMax     = 10          -- Xỉu: tổng đến
Config.DrawValues = { 3, 18 }   -- Hòa (nhà cái thắng): các tổng này là hòa

-- ────────────────────────────────────────────────────
-- LỊCH SỬ
-- ────────────────────────────────────────────────────
Config.MaxHistory = 5           -- Số vòng lịch sử lưu & hiển thị trong UI

-- ────────────────────────────────────────────────────
-- DATABASE
-- ────────────────────────────────────────────────────
Config.EnableDatabase = true    -- Bật / tắt lưu thống kê vào database
Config.AutoCleanup    = true    -- Tự động dọn dữ liệu cũ
Config.CleanupDays    = 5      -- Xóa dữ liệu cũ hơn X ngày

-- ────────────────────────────────────────────────────
-- BẢO MẬT
-- ────────────────────────────────────────────────────
Config.EnableAnticheat = true   -- Kiểm tra số dư trước khi trừ tiền

-- ────────────────────────────────────────────────────
-- THÔNG BÁO (ox_lib)
-- ────────────────────────────────────────────────────
Config.NotifyDuration = 5000    -- Thời gian hiển thị thông báo (ms)

-- ────────────────────────────────────────────────────
-- ADMIN
-- ────────────────────────────────────────────────────
Config.AdminGroups = { 'admin', 'superadmin' }  -- Nhóm được dùng lệnh admin

-- ────────────────────────────────────────────────────
-- HỆ THỐNG RANDOM & HOUSE EDGE
-- ────────────────────────────────────────────────────

-- Seed mạnh: re-seed mỗi vòng bằng nhiều nguồn entropy
Config.StrongSeed = true        -- true = seed lại mỗi vòng (khuyến nghị)

-- House Edge: điều chỉnh xác suất có lợi cho nhà cái
-- Tổng TaiChance + XiuChance + HoaChance phải = 100
Config.HouseEdge = {
    enabled    = true,

    -- Xác suất cơ bản (%)
    -- Tài/Xỉu thuần toán học là 50/50, Hòa là ~0.93%
    -- Giảm Tài & Xỉu, tăng Hòa = nhà cái có lợi hơn
    TaiChance  = 45.0,          -- % ra Tài
    XiuChance  = 45.0,          -- % ra Xỉu
    HoaChance  = 10.0,           -- % ra Hòa (nhà cái ăn trắng)

    -- House edge động: tăng HoaChance khi nhà cái đang lỗ
    DynamicEdge       = true,   -- true = kích hoạt house edge động
    LossThreshold     = 20000000, -- Nhà cái lỗ X$ trong session thì kích hoạt
    DynamicHoaBonus   = 4.0,    -- Tăng thêm X% Hòa khi kích hoạt (lấy đều từ Tài & Xỉu)
}