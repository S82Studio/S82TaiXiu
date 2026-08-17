-- ═══════════════════════════════════════════════════════════════
-- S82 TÀI XỈU — DATABASE SETUP
-- Import file này vào MySQL / MariaDB trước khi chạy resource
-- (Hoặc để tự tạo — server.lua tự tạo bảng khi khởi động)
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS `s82taixiu_players` (
    `citizenid`         VARCHAR(50)  NOT NULL,
    `name`              VARCHAR(100) DEFAULT NULL,
    `total_bets`        INT          DEFAULT 0,
    `total_wins`        INT          DEFAULT 0,
    `total_loses`       INT          DEFAULT 0,
    `total_draws`       INT          DEFAULT 0,
    `total_bet_amount`  BIGINT       DEFAULT 0,
    `total_win_amount`  BIGINT       DEFAULT 0,
    `total_lose_amount` BIGINT       DEFAULT 0,
    `biggest_win`       BIGINT       DEFAULT 0,
    `last_played`       TIMESTAMP    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `s82taixiu_rounds` (
    `id`                INT AUTO_INCREMENT PRIMARY KEY,
    `round_number`      INT     NOT NULL,
    `dice1`             TINYINT NOT NULL,
    `dice2`             TINYINT NOT NULL,
    `dice3`             TINYINT NOT NULL,
    `total`             TINYINT NOT NULL,
    `result`            ENUM('tai','xiu','hoa') NOT NULL,
    `total_bets`        INT     DEFAULT 0,
    `total_bet_amount`  BIGINT  DEFAULT 0,
    `total_payout`      BIGINT  DEFAULT 0,
    `house_profit`      BIGINT  DEFAULT 0,
    `winners`           INT     DEFAULT 0,
    `losers`            INT     DEFAULT 0,
    `draws`             INT     DEFAULT 0,
    `created_at`        TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
    `created_at`   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_citizenid` (`citizenid`),
    INDEX `idx_round_id`  (`round_id`),
    INDEX `idx_created`   (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;