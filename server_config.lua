-- ═══════════════════════════════════════════════════════════════
-- S82 TÀI XỈU — CẤU HÌNH WEBHOOK ADMIN (CHỈ SERVER)
-- File này chỉ nạp ở server_scripts → URL webhook KHÔNG bị gửi xuống client.
-- Để trống URL ('') = tắt loại log đó.
-- ═══════════════════════════════════════════════════════════════

ServerConfig = {}

ServerConfig.Webhook = {
    enabled  = true,

    username = 'S82 DEV • Tài Xỉu',
    avatar   = '',   -- link ảnh avatar bot (tuỳ chọn)
    footer   = 'S82 DEV • S82 Tài Xỉu',

    -- Có thể dùng chung 1 URL cho tất cả, hoặc tách từng kênh
    urls = {
        bets    = '',   -- Mỗi lượt đặt cược
        results = '',   -- Tổng kết mỗi vòng (xúc xắc, danh sách thắng/thua, lãi nhà cái)
        bigwin  = '',   -- Thắng lớn (>= BigWinAmount)
        admin   = '',   -- Admin dùng lệnh /taixiustats, /taixiureset, /taixiuclean
        alert   = '',   -- Cảnh báo: gửi cược khi không đủ tiền / sai dữ liệu (nghi hack)
    },

    BigWinAmount   = 2000000,   -- Tiền lời >= mức này → gửi log thắng lớn
    LogEmptyRounds = false,     -- false = không gửi log vòng không có ai cược
    MaxPlayersInResult = 25,    -- Tối đa số người liệt kê trong log tổng kết vòng

    -- Hiển thị identifier của người chơi trong log
    ShowIdentifiers = { license = true, discord = true, steam = false, fivem = false },

    -- Màu embed (decimal)
    colors = {
        bet    = 3447003,   -- xanh dương
        tai    = 15548997,  -- đỏ
        xiu    = 3447003,   -- xanh
        hoa    = 16705372,  -- vàng
        bigwin = 5763719,   -- xanh lá
        admin  = 10181046,  -- tím
        alert  = 15158332,  -- đỏ đậm
    },
}
