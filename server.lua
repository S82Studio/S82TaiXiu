-- ═══════════════════════════════════════════════════════════════
-- S82 TÀI XỈU - SERVER SIDE v2.0
-- Framework: ESX / QBCore / QBX (qua bridge/framework.lua)
-- Database: oxmysql | Notify: ox_lib
-- ═══════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════
-- KHỞI TẠO
-- ═══════════════════════════════════════════════════════════════

local GameState = {
    Round   = 1,
    Time    = Config.RoundTime,
    Betting = true,
    Rolling = false,
    Bets    = {},
    History = {},
    Stats   = { totalBets = 0, totalPayout = 0, totalRevenue = 0, totalBetPool = 0, taiCount = 0, xiuCount = 0, hoaCount = 0 },
}

-- ═══════════════════════════════════════════════════════════════
-- DATABASE
-- ═══════════════════════════════════════════════════════════════

CreateThread(function()
    MySQL.ready(function()
        MySQL.Sync.execute([[
            CREATE TABLE IF NOT EXISTS `s82taixiu_players` (
                `citizenid`        VARCHAR(50)  NOT NULL,
                `name`             VARCHAR(100) DEFAULT NULL,
                `total_bets`       INT          DEFAULT 0,
                `total_wins`       INT          DEFAULT 0,
                `total_loses`      INT          DEFAULT 0,
                `total_draws`      INT          DEFAULT 0,
                `total_bet_amount` BIGINT       DEFAULT 0,
                `total_win_amount` BIGINT       DEFAULT 0,
                `total_lose_amount`BIGINT       DEFAULT 0,
                `biggest_win`      BIGINT       DEFAULT 0,
                `last_played`      TIMESTAMP    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (`citizenid`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]])

        MySQL.Sync.execute([[
            CREATE TABLE IF NOT EXISTS `s82taixiu_rounds` (
                `id`               INT AUTO_INCREMENT PRIMARY KEY,
                `round_number`     INT    NOT NULL,
                `dice1`            TINYINT NOT NULL,
                `dice2`            TINYINT NOT NULL,
                `dice3`            TINYINT NOT NULL,
                `total`            TINYINT NOT NULL,
                `result`           ENUM('tai','xiu','hoa') NOT NULL,
                `total_bets`       INT    DEFAULT 0,
                `total_bet_amount` BIGINT DEFAULT 0,
                `total_payout`     BIGINT DEFAULT 0,
                `house_profit`     BIGINT DEFAULT 0,
                `winners`          INT    DEFAULT 0,
                `losers`           INT    DEFAULT 0,
                `draws`            INT    DEFAULT 0,
                `created_at`       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]])

        MySQL.Sync.execute([[
            CREATE TABLE IF NOT EXISTS `s82taixiu_transactions` (
                `id`           INT AUTO_INCREMENT PRIMARY KEY,
                `round_id`     INT,
                `round_number` INT,
                `citizenid`    VARCHAR(50),
                `name`         VARCHAR(100),
                `bet_type`     ENUM('tai','xiu') NOT NULL,
                `bet_amount`   BIGINT NOT NULL,
                `result`       ENUM('tai','xiu','hoa') NOT NULL,
                `outcome`      ENUM('win','lose','draw') NOT NULL,
                `payout`       BIGINT DEFAULT 0,
                `profit`       BIGINT DEFAULT 0,
                `dice1`        TINYINT,
                `dice2`        TINYINT,
                `dice3`        TINYINT,
                `created_at`   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]])

        -- Load history từ DB
        if Config.EnableDatabase then
            local recent = MySQL.Sync.fetchAll([[
                SELECT result, dice1, dice2, dice3, total
                FROM s82taixiu_rounds ORDER BY created_at DESC LIMIT ?
            ]], { Config.MaxHistory })
            if recent then
                for i = #recent, 1, -1 do
                    table.insert(GameState.History, {
                        result = recent[i].result,
                        total  = recent[i].total,
                        dice   = { recent[i].dice1, recent[i].dice2, recent[i].dice3 }
                    })
                end
            end
        end

        print('^2[S82-TAIXIU] Database đã sẵn sàng!^7')
    end)
end)

-- ═══════════════════════════════════════════════════════════════
-- DB HELPERS
-- ═══════════════════════════════════════════════════════════════

local function DB_CreateRound(roundNum, d1, d2, d3, total, result)
    return MySQL.Sync.insert([[
        INSERT INTO s82taixiu_rounds (round_number, dice1, dice2, dice3, total, result)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], { roundNum, d1, d2, d3, total, result })
end

local function DB_UpdateRound(roundId, totBets, totBetAmt, totPayout, houseProfit, winners, losers, draws)
    MySQL.Async.execute([[
        UPDATE s82taixiu_rounds
        SET total_bets=?, total_bet_amount=?, total_payout=?, house_profit=?, winners=?, losers=?, draws=?
        WHERE id=?
    ]], { totBets, totBetAmt, totPayout, houseProfit, winners, losers, draws, roundId })
end

local function DB_SaveTransaction(roundId, roundNum, citizenid, name, betType, betAmount, result, outcome, payout, profit, d1, d2, d3)
    MySQL.Async.execute([[
        INSERT INTO s82taixiu_transactions
        (round_id, round_number, citizenid, name, bet_type, bet_amount, result, outcome, payout, profit, dice1, dice2, dice3)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)
    ]], { roundId, roundNum, citizenid, name, betType, betAmount, result, outcome, payout, profit, d1, d2, d3 })
end

local function DB_UpsertPlayer(citizenid, name, outcome, betAmount, profit)
    local winAmt  = (outcome == 'win')  and profit or 0
    local loseAmt = (outcome == 'lose') and betAmount or 0

    MySQL.Async.execute([[
        INSERT INTO s82taixiu_players (citizenid, name, total_bets,
            total_wins, total_loses, total_draws,
            total_bet_amount, total_win_amount, total_lose_amount, biggest_win)
        VALUES (?, ?, 1,
            ?, ?, ?,
            ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            name             = ?,
            total_bets       = total_bets + 1,
            total_wins       = total_wins + ?,
            total_loses      = total_loses + ?,
            total_draws      = total_draws + ?,
            total_bet_amount = total_bet_amount + ?,
            total_win_amount = total_win_amount + ?,
            total_lose_amount= total_lose_amount + ?,
            biggest_win      = GREATEST(biggest_win, ?),
            last_played      = NOW()
    ]], {
        citizenid, name,
        outcome == 'win' and 1 or 0,
        outcome == 'lose' and 1 or 0,
        outcome == 'draw' and 1 or 0,
        betAmount, winAmt, loseAmt,
        winAmt,
        -- ON DUPLICATE KEY
        name,
        outcome == 'win' and 1 or 0,
        outcome == 'lose' and 1 or 0,
        outcome == 'draw' and 1 or 0,
        betAmount, winAmt, loseAmt,
        winAmt,
    })
end

local function DB_GetPlayerStats(citizenid)
    local r = MySQL.Sync.fetchAll('SELECT * FROM s82taixiu_players WHERE citizenid = ?', { citizenid })
    return r and r[1] or nil
end

local function DB_Cleanup(days)
    MySQL.Async.execute('DELETE FROM s82taixiu_transactions WHERE created_at < DATE_SUB(NOW(), INTERVAL ? DAY)', { days })
    MySQL.Async.execute('DELETE FROM s82taixiu_rounds WHERE created_at < DATE_SUB(NOW(), INTERVAL ? DAY)', { days })
    print(string.format('^2[S82-TAIXIU] Đã dọn dẹp dữ liệu cũ hơn %d ngày^7', days))
end

-- ═══════════════════════════════════════════════════════════════
-- UTILITY
-- ═══════════════════════════════════════════════════════════════

local function GetPlayer(src)
    return Bridge.GetPlayer(src)
end

local function FormatMoney(amount)
    if amount >= 1000000 then
        return string.format('%.1fM', amount / 1000000)
    elseif amount >= 1000 then
        return string.format('%.0fK', amount / 1000)
    end
    return tostring(amount)
end

local function Notify(src, title, description, notifType, duration)
    TriggerClientEvent('s82taixiu:client:notify', src, {
        title       = title,
        description = description,
        type        = notifType or 'inform',
        duration    = duration or Config.NotifyDuration,
    })
end

local function GetGameResult(total)
    for _, v in ipairs(Config.DrawValues) do
        if total == v then return 'hoa' end
    end
    if total >= Config.TaiMin and total <= Config.TaiMax then return 'tai' end
    if total >= Config.XiuMin and total <= Config.XiuMax then return 'xiu' end
    return 'hoa'
end

-- ═══════════════════════════════════════════════════════════════
-- STRONG SEED — Re-seed mỗi vòng bằng nhiều nguồn entropy
-- Ngăn chặn việc đoán trước kết quả từ seed cố định
-- ═══════════════════════════════════════════════════════════════

local function RefreshSeed()
    if not Config.StrongSeed then return end
    -- Kết hợp: thời gian thực (ms) + game timer + số người chơi + round hiện tại
    local t  = os.time()
    local c  = math.floor(os.clock() * 1000000) % 999983   -- prime modulo
    local g  = GetGameTimer()                               -- ms từ khi server start
    local p  = #GetPlayers()
    local r  = GameState.Round
    -- XOR nhiều nguồn, trộn thêm phép nhân để phá pattern LCG
    local seed = ((t * 2654435761) ~ (c * 40503) ~ (g * 6364136223846793005) ~ (p * 1442695040888963407) ~ r) % 2147483647
    math.randomseed(seed)
    -- Bỏ qua vài số đầu (warmup) để tránh bias đầu chuỗi LCG
    for _ = 1, 8 do math.random() end
end

-- ═══════════════════════════════════════════════════════════════
-- HOUSE EDGE — Chọn kết quả theo xác suất có cấu hình
-- Sau đó sinh xúc xắc khớp với kết quả đó
-- ═══════════════════════════════════════════════════════════════

-- Bảng tất cả tổ hợp 3 xúc xắc theo nhóm kết quả (tính sẵn)
local DICE_COMBOS = { tai = {}, xiu = {}, hoa = {} }
for d1 = 1, 6 do
    for d2 = 1, 6 do
        for d3 = 1, 6 do
            local total = d1 + d2 + d3
            local group = GetGameResult(total)
            table.insert(DICE_COMBOS[group], { d1, d2, d3, total })
        end
    end
end

local function PickOutcome()
    local cfg = Config.HouseEdge
    if not cfg or not cfg.enabled then
        -- Không dùng house edge: random thuần theo xúc xắc
        return nil
    end

    local taiChance = cfg.TaiChance
    local xiuChance = cfg.XiuChance
    local hoaChance = cfg.HoaChance

    -- House edge động: nếu nhà cái đang lỗ vượt ngưỡng → tăng Hòa
    if cfg.DynamicEdge then
        local sessionProfit = GameState.Stats.totalRevenue - (GameState.Stats.totalPayout - GameState.Stats.totalBetPool)
        if sessionProfit < -math.abs(cfg.LossThreshold) then
            local bonus = cfg.DynamicHoaBonus
            hoaChance = hoaChance + bonus
            taiChance = taiChance - bonus / 2
            xiuChance = xiuChance - bonus / 2
        end
    end

    -- Đảm bảo không âm
    taiChance = math.max(0, taiChance)
    xiuChance = math.max(0, xiuChance)
    hoaChance = math.max(0, hoaChance)

    local roll = math.random() * (taiChance + xiuChance + hoaChance)

    if roll < taiChance then
        return 'tai'
    elseif roll < taiChance + xiuChance then
        return 'xiu'
    else
        return 'hoa'
    end
end

local function RollDiceWithOutcome(forcedOutcome)
    -- Chọn ngẫu nhiên 1 tổ hợp xúc xắc từ nhóm kết quả đã định
    local pool  = DICE_COMBOS[forcedOutcome]
    local combo = pool[math.random(1, #pool)]
    return combo[1], combo[2], combo[3], combo[4]
end

local function IsAdmin(src)
    for _, group in ipairs(Config.AdminGroups) do
        if IsPlayerAceAllowed(src, 'group.' .. group) then return true end
    end
    return src == 0
end

local function GetBetPool()
    local taiTotal, xiuTotal, taiCount, xiuCount = 0, 0, 0, 0
    for _, bet in pairs(GameState.Bets) do
        if bet.choice == 'tai' then
            taiTotal = taiTotal + bet.amount
            taiCount = taiCount + 1
        else
            xiuTotal = xiuTotal + bet.amount
            xiuCount = xiuCount + 1
        end
    end
    return { taiTotal = taiTotal, xiuTotal = xiuTotal, taiCount = taiCount, xiuCount = xiuCount }
end

local function BroadcastUpdate()
    TriggerClientEvent('s82taixiu:client:update', -1, {
        round   = GameState.Round,
        time    = GameState.Time,
        betting = GameState.Betting,
        rolling = GameState.Rolling,
        lockAt  = Config.LockTime,
        pool    = GetBetPool(),
    })
end

-- ═══════════════════════════════════════════════════════════════
-- LOGIC CHÍNH: LẮC XÚC XẮC & XỬ LÝ CƯỢC
-- ═══════════════════════════════════════════════════════════════

local function RollDice()
    GameState.Rolling = true
    BroadcastUpdate()
    Wait(1500)

    -- 1. Re-seed mạnh trước mỗi vòng
    RefreshSeed()

    -- 2. Chọn kết quả theo house edge (hoặc random thuần nếu tắt)
    local outcome = PickOutcome()

    -- 3. Sinh xúc xắc khớp với kết quả
    local d1, d2, d3, total
    if outcome then
        d1, d2, d3, total = RollDiceWithOutcome(outcome)
    else
        -- Fallback: random thuần
        d1    = math.random(1, 6)
        d2    = math.random(1, 6)
        d3    = math.random(1, 6)
        total = d1 + d2 + d3
    end
    local result = GetGameResult(total)

    -- Cập nhật thống kê
    if result == 'tai'  then GameState.Stats.taiCount  = GameState.Stats.taiCount  + 1
    elseif result == 'xiu'  then GameState.Stats.xiuCount  = GameState.Stats.xiuCount  + 1
    elseif result == 'hoa'  then GameState.Stats.hoaCount  = GameState.Stats.hoaCount  + 1
    end

    -- Lưu lịch sử
    table.insert(GameState.History, 1, { result = result, total = total, dice = {d1, d2, d3} })
    while #GameState.History > Config.MaxHistory do table.remove(GameState.History) end

    -- DB: tạo round record
    local roundId = nil
    if Config.EnableDatabase then
        roundId = DB_CreateRound(GameState.Round, d1, d2, d3, total, result)
    end

    -- Broadcast kết quả xúc xắc (trước khi xử lý tiền)
    TriggerClientEvent('s82taixiu:client:result', -1, {
        dice    = {d1, d2, d3},
        total   = total,
        result  = result,
        history = GameState.History,
    })

    Wait(1000) -- cho animation xúc xắc

    -- Xử lý tiền cược
    local totBetAmt, totPayout, totRevenue = 0, 0, 0
    local winners, losers, draws = 0, 0, 0

    for src, bet in pairs(GameState.Bets) do
        local Player = GetPlayer(src)
        if Player then
            local citizenid = Bridge.GetIdentifier(Player)
            local name      = Bridge.GetName(Player)
            totBetAmt = totBetAmt + bet.amount

            if result == 'hoa' then
                -- Hòa: nhà cái thắng tất cả
                draws       = draws + 1
                totRevenue  = totRevenue + bet.amount

                if Config.EnableDatabase and roundId then
                    DB_SaveTransaction(roundId, GameState.Round, citizenid, name, bet.choice, bet.amount, result, 'draw', 0, -bet.amount, d1, d2, d3)
                    DB_UpsertPlayer(citizenid, name, 'draw', bet.amount, 0)
                end

                TriggerClientEvent('s82taixiu:client:updateBalance', src, Bridge.GetMoney(Player, Config.Currency))
                Notify(src,
                    '🌸 Hòa Bài! (Tổng: ' .. total .. ')',
                    'Ván hòa — nhà cái thắng tất cả. Mất ' .. FormatMoney(bet.amount),
                    'warning'
                )

            elseif bet.choice == result then
                -- Thắng
                local winAmount   = math.floor(bet.amount * (Config.PayoutRate - 1))
                local totalReceive = bet.amount + winAmount
                Bridge.AddMoney(Player, Config.Currency, totalReceive)

                totPayout = totPayout + totalReceive
                winners   = winners + 1

                if Config.EnableDatabase and roundId then
                    DB_SaveTransaction(roundId, GameState.Round, citizenid, name, bet.choice, bet.amount, result, 'win', totalReceive, winAmount, d1, d2, d3)
                    DB_UpsertPlayer(citizenid, name, 'win', bet.amount, winAmount)
                end

                TriggerClientEvent('s82taixiu:client:updateBalance', src, Bridge.GetMoney(Player, Config.Currency))

                local rewardMsg = ''
                -- Phần thưởng vật phẩm tuỳ chọn (Config.ItemReward)
                if Config.ItemReward and Config.ItemReward.enabled and winAmount >= (Config.ItemReward.minWinAmount or 0) then
                    local given = Bridge.AddItem(src, Config.ItemReward.item, Config.ItemReward.amount)
                    if given then
                        rewardMsg = ' | +' .. Config.ItemReward.amount .. 'x ' .. Config.ItemReward.item
                    end
                end

                Notify(src,
                    '🎉 Thắng! — ' .. string.upper(result) .. ' (' .. total .. ')',
                    'Thắng ' .. FormatMoney(winAmount) .. ' | Nhận về ' .. FormatMoney(totalReceive) .. rewardMsg,
                    'success'
                )

            else
                -- Thua
                losers     = losers + 1
                totRevenue = totRevenue + bet.amount

                if Config.EnableDatabase and roundId then
                    DB_SaveTransaction(roundId, GameState.Round, citizenid, name, bet.choice, bet.amount, result, 'lose', 0, -bet.amount, d1, d2, d3)
                    DB_UpsertPlayer(citizenid, name, 'lose', bet.amount, 0)
                end

                TriggerClientEvent('s82taixiu:client:updateBalance', src, Bridge.GetMoney(Player, Config.Currency))
                Notify(src,
                    '💔 Thua — ' .. string.upper(result) .. ' (' .. total .. ')',
                    'Mất ' .. FormatMoney(bet.amount) .. '. Chúc may mắn lần sau!',
                    'error'
                )
            end
        end
    end

    -- Cập nhật round trong DB
    if Config.EnableDatabase and roundId then
        local houseProfit = totRevenue - math.max(0, totPayout - totBetAmt)
        DB_UpdateRound(roundId, winners + losers + draws, totBetAmt, totPayout, houseProfit, winners, losers, draws)
    end

    GameState.Stats.totalBets     = GameState.Stats.totalBets + winners + losers + draws
    GameState.Stats.totalPayout   = GameState.Stats.totalPayout + totPayout
    GameState.Stats.totalRevenue  = GameState.Stats.totalRevenue + totRevenue
    GameState.Stats.totalBetPool  = GameState.Stats.totalBetPool + totBetAmt

    -- Chờ hiển thị kết quả
    Wait(Config.ResultDelay * 1000)

    -- Reset vòng mới
    GameState.Bets    = {}
    GameState.Round   = GameState.Round + 1
    GameState.Time    = Config.RoundTime
    GameState.Betting = true
    GameState.Rolling = false

    TriggerClientEvent('s82taixiu:client:newRound', -1, { round = GameState.Round })
    BroadcastUpdate()
end

-- ═══════════════════════════════════════════════════════════════
-- THREAD CHÍNH: Đồng hồ đếm ngược
-- ═══════════════════════════════════════════════════════════════

CreateThread(function()
    Wait(3000) -- chờ DB load
    BroadcastUpdate()
    TriggerClientEvent('s82taixiu:client:history', -1, GameState.History)
    print('^2[S82-TAIXIU] Game đã khởi động! Vòng #1 bắt đầu.^7')

    while true do
        Wait(1000)

        if GameState.Rolling then
            -- Đang xử lý, không làm gì
        else
            GameState.Time = GameState.Time - 1

            -- Kiểm tra khóa cược
            if GameState.Time == Config.LockTime and GameState.Betting then
                GameState.Betting = false
                TriggerClientEvent('s82taixiu:client:locked', -1)
            end

            BroadcastUpdate()

            if GameState.Time <= 0 then
                RollDice()
            end
        end
    end
end)

-- Auto cleanup thread
if Config.EnableDatabase and Config.AutoCleanup then
    CreateThread(function()
        while true do
            Wait(86400000) -- 24 giờ
            DB_Cleanup(Config.CleanupDays)
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════
-- EVENTS: Đặt cược
-- ═══════════════════════════════════════════════════════════════

RegisterNetEvent('s82taixiu:server:bet', function(choice, amount)
    local src    = source
    local Player = GetPlayer(src)
    if not Player then return end

    -- Validate trạng thái
    if not GameState.Betting then
        Notify(src, '🔒 Đã Khóa Cược', 'Không thể đặt cược lúc này!', 'error')
        return
    end

    -- Validate lựa chọn
    if choice ~= 'tai' and choice ~= 'xiu' then return end

    -- Validate số tiền
    if type(amount) ~= 'number' then return end
    amount = math.floor(amount)

    if amount < Config.MinBet then
        Notify(src, '❌ Cược Thấp', 'Cược tối thiểu ' .. FormatMoney(Config.MinBet), 'error')
        return
    end

    if amount > Config.MaxBet then
        Notify(src, '❌ Cược Cao', 'Cược tối đa ' .. FormatMoney(Config.MaxBet), 'error')
        return
    end

    -- Kiểm tra đã cược vòng này chưa
    if GameState.Bets[src] then
        Notify(src, '⚠️ Đã Cược', 'Bạn đã đặt cược vòng này rồi!', 'warning')
        return
    end

    -- Anti-cheat: kiểm tra số dư
    if Config.EnableAnticheat then
        local cash = Bridge.GetMoney(Player, Config.Currency)
        if cash < amount then
            Notify(src, '💸 Không Đủ Tiền', 'Bạn không có đủ tiền mặt!', 'error')
            return
        end
    end

    -- Trừ tiền
    if not Bridge.RemoveMoney(Player, Config.Currency, amount) then
        Notify(src, '💸 Lỗi', 'Không thể trừ tiền!', 'error')
        return
    end

    GameState.Bets[src] = { choice = choice, amount = amount }

    -- Cập nhật player trong DB
    if Config.EnableDatabase then
        local citizenid = Bridge.GetIdentifier(Player)
        local name      = Bridge.GetName(Player)
        MySQL.Async.execute([[
            INSERT INTO s82taixiu_players (citizenid, name) VALUES (?, ?)
            ON DUPLICATE KEY UPDATE name = ?, last_played = NOW()
        ]], { citizenid, name, name })
    end

    -- Thông báo đặt cược thành công + gửi số dư mới
    local newBalance = Bridge.GetMoney(Player, Config.Currency)
    TriggerClientEvent('s82taixiu:client:betPlaced', src, { choice = choice, amount = amount, newBalance = newBalance })
    -- Broadcast pool mới cho tất cả người chơi đang mở UI
    TriggerClientEvent('s82taixiu:client:poolUpdate', -1, GetBetPool())
    Notify(src,
        '✅ Đặt Cược Thành Công',
        string.upper(choice) .. ' — ' .. FormatMoney(amount),
        'success',
        3000
    )
end)

-- ═══════════════════════════════════════════════════════════════
-- EVENTS: Lấy dữ liệu UI
-- ═══════════════════════════════════════════════════════════════

RegisterNetEvent('s82taixiu:server:getUIData', function()
    local src    = source
    local Player = GetPlayer(src)
    if not Player then return end

    local playerBet = GameState.Bets[src] or nil
    local balance   = Bridge.GetMoney(Player, Config.Currency)
    local stats     = nil

    if Config.EnableDatabase then
        stats = DB_GetPlayerStats(Bridge.GetIdentifier(Player))
    end

    TriggerClientEvent('s82taixiu:client:receiveUIData', src, {
        round      = GameState.Round,
        time       = GameState.Time,
        betting    = GameState.Betting,
        rolling    = GameState.Rolling,
        lockAt     = Config.LockTime,
        history    = GameState.History,
        playerBet  = playerBet,
        balance    = balance,
        stats      = stats,
        minBet     = Config.MinBet,
        maxBet     = Config.MaxBet,
        payoutRate = Config.PayoutRate,
        pool       = GetBetPool(),
    })
end)

RegisterNetEvent('s82taixiu:server:getPlayerStats', function()
    local src    = source
    local Player = GetPlayer(src)
    if not Player or not Config.EnableDatabase then
        TriggerClientEvent('s82taixiu:client:receiveStats', src, nil)
        return
    end
    local stats = DB_GetPlayerStats(Bridge.GetIdentifier(Player))
    TriggerClientEvent('s82taixiu:client:receiveStats', src, stats)
end)

-- ═══════════════════════════════════════════════════════════════
-- RE-SYNC khi resource restart
-- ═══════════════════════════════════════════════════════════════

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SetTimeout(4000, function()
        for _, src in ipairs(GetPlayers()) do
            local s = tonumber(src)
            TriggerClientEvent('s82taixiu:client:update', s, {
                round   = GameState.Round,
                time    = GameState.Time,
                betting = GameState.Betting,
                rolling = GameState.Rolling,
                lockAt  = Config.LockTime,
            })
            TriggerClientEvent('s82taixiu:client:history', s, GameState.History)
        end
    end)
end)

-- ═══════════════════════════════════════════════════════════════
-- ADMIN COMMANDS
-- ═══════════════════════════════════════════════════════════════

RegisterCommand('taixiustats', function(src, args)
    if not IsAdmin(src) then
        if src ~= 0 then Notify(src, 'Lỗi', 'Không có quyền!', 'error') end
        return
    end
    local sessionProfit = GameState.Stats.totalRevenue - math.max(0, GameState.Stats.totalPayout - GameState.Stats.totalBetPool)
    local dynamicActive = Config.HouseEdge.enabled and Config.HouseEdge.DynamicEdge
        and (sessionProfit < -math.abs(Config.HouseEdge.LossThreshold))
    print('^3════════════════════════════^7')
    print('^2  S82 TÀI XỈU — THỐNG KÊ  ^7')
    print('^3════════════════════════════^7')
    print(string.format('Vòng hiện tại  : ^2#%d^7', GameState.Round))
    print(string.format('Thời gian còn  : ^2%ds^7', GameState.Time))
    print(string.format('Đặt cược       : ^2%s^7', GameState.Betting and 'MỞ' or 'KHÓA'))
    print(string.format('Tài / Xỉu / Hòa: ^2%d / %d / %d^7', GameState.Stats.taiCount, GameState.Stats.xiuCount, GameState.Stats.hoaCount))
    print(string.format('Profit session : ^2%s^7', FormatMoney(sessionProfit)))
    print(string.format('House Edge     : ^2%s^7', Config.HouseEdge.enabled and 'BẬT' or 'TẮT'))
    print(string.format('Dynamic Edge   : ^2%s^7', dynamicActive and 'ĐANG KÍCH HOẠT' or 'Chờ'))
    print('^3════════════════════════════^7')
end, false)

RegisterCommand('taixiureset', function(src, args)
    if not IsAdmin(src) then
        if src ~= 0 then Notify(src, 'Lỗi', 'Không có quyền!', 'error') end
        return
    end
    GameState.Bets    = {}
    GameState.Round   = 1
    GameState.Time    = Config.RoundTime
    GameState.Betting = true
    GameState.Rolling = false
    BroadcastUpdate()
    TriggerClientEvent('s82taixiu:client:history', -1, {})
    print('^2[S82-TAIXIU] Admin đã reset game!^7')
    if src ~= 0 then Notify(src, '✅ Đã Reset', 'Game đã được reset!', 'success') end
end, false)

RegisterCommand('taixiuclean', function(src, args)
    if not IsAdmin(src) or not Config.EnableDatabase then return end
    local days = tonumber(args[1]) or Config.CleanupDays
    DB_Cleanup(days)
    if src ~= 0 then Notify(src, '🧹 Đã Dọn Dẹp', 'Xóa data cũ hơn ' .. days .. ' ngày', 'success') end
end, false)