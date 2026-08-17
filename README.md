# 🎲 S82 Tài Xỉu — Premium Edition

Script mini-game **Tài Xỉu** (Sicbo) cho máy chủ FiveM roleplay, giao diện đẹp, chống gian lận, hỗ trợ **đa framework** (ESX / QBCore / QBX) và **đa hệ túi đồ** thông dụng.

---

## ✨ Tính năng

- Giao diện NUI đẹp, mượt, có lịch sử kết quả, pool cược real-time, hiệu ứng lắc xúc xắc.
- Cơ chế cược Tài / Xỉu chuẩn (tổng 11–17 = Tài, 4–10 = Xỉu, Bộ Ba/1-1-1, 6-6-6 = Hòa nhà cái thắng).
- **House Edge cấu hình được**, kèm House Edge động (tự tăng tỉ lệ Hòa khi nhà cái đang lỗ vượt ngưỡng).
- Random mạnh: re-seed mỗi vòng bằng nhiều nguồn entropy để chống đoán trước kết quả.
- Lưu lịch sử vòng chơi, giao dịch, thống kê từng người chơi vào MySQL (oxmysql), tự dọn dữ liệu cũ.
- Anti-cheat kiểm tra số dư trước khi trừ tiền, khoá cược trước khi lắc xúc xắc.
- Lệnh admin: xem thống kê, reset game, dọn dữ liệu cũ.
- **Hỗ trợ đa core**: ESX, QBCore, QBX (qbx_core) — tự động nhận diện, không cần chỉnh code.
- **Phần thưởng vật phẩm tuỳ chọn**: ngoài tiền, có thể tặng thêm item khi thắng, tương thích ox_inventory, qb-inventory, ps-inventory, qs-inventory, core_inventory hoặc inventory gốc của ESX.

---

## 🧩 Tương thích

| Loại | Hỗ trợ |
|---|---|
| Framework | `qbx_core`, `qb-core`, `es_extended` (ESX Legacy) |
| Database | `oxmysql` |
| Thông báo | `ox_lib` |
| Túi đồ (phần thưởng vật phẩm) | `ox_inventory`, `qb-inventory`, `ps-inventory`, `qs-inventory`, `core_inventory`, hoặc inventory gốc ESX |

> Script **tự động nhận diện** framework và hệ túi đồ đang chạy trên server — không cần sửa code, chỉ cần chỉnh `Config.Framework` / `Config.Inventory` nếu muốn ép buộc thủ công.

---

## 📦 Cài đặt

1. Giải nén, copy thư mục `s82taixiu` vào `resources/`.
2. Import `sql.sql` vào database (hoặc để script tự tạo bảng khi khởi động lần đầu).
3. Thêm vào `server.cfg`:
   ```cfg
   ensure oxmysql
   ensure ox_lib
   # ensure framework của bạn (qbx_core / qb-core / es_extended) đã start trước
   ensure s82taixiu
   ```
4. Mở `config.lua`, kiểm tra mục **FRAMEWORK & TÚI ĐỒ** — để `auto` là đủ với hầu hết server, hoặc chọn thủ công nếu server chạy nhiều framework song song.
5. Vào game, gõ `/s82taixiu` để mở giao diện.

---

## ⚙️ Cấu hình chính (`config.lua`)

### Framework & túi đồ

```lua
Config.Framework = 'auto'   -- 'auto' | 'esx' | 'qbcore' | 'qbx'
Config.Inventory = 'auto'   -- 'auto' | 'ox_inventory' | 'qb-inventory' | 'ps-inventory' | 'qs-inventory' | 'core_inventory' | 'esx'
Config.Currency  = 'cash'   -- 'cash' hoặc 'bank' — loại tiền dùng để cược/trả thưởng
```

### Phần thưởng vật phẩm (tuỳ chọn)

```lua
Config.ItemReward = {
    enabled      = false,       -- bật/tắt tặng vật phẩm khi thắng
    item         = 'gold_chip', -- item phải đã tồn tại trong hệ túi đồ của bạn
    amount       = 1,
    minWinAmount = 500000,      -- chỉ tặng nếu tiền thắng >= mức này
}
```

### Tiền cược, tỉ lệ, house edge

Tất cả nằm trong `config.lua`, mỗi dòng đều có chú thích tiếng Việt: `Config.MinBet`, `Config.MaxBet`, `Config.PayoutRate`, `Config.HouseEdge`, v.v.

---

## 🕹️ Lệnh

| Lệnh | Quyền | Mô tả |
|---|---|---|
| `/s82taixiu` | Mọi người | Mở/đóng giao diện Tài Xỉu |
| `/taixiustats` | Admin (`Config.AdminGroups`) | Xem thống kê phiên hiện tại (console) |
| `/taixiureset` | Admin | Reset vòng chơi về ban đầu |
| `/taixiuclean [số ngày]` | Admin | Dọn dữ liệu cũ hơn X ngày |

---

## 🗂️ Cấu trúc thư mục

```
s82taixiu/
├── bridge/
│   └── framework.lua      -- Bridge đa core (ESX/QBCore/QBX) + đa túi đồ
├── html/                  -- Giao diện NUI (không phụ thuộc framework)
├── client.lua
├── server.lua
├── config.lua
├── sql.sql
└── fxmanifest.lua
```

`bridge/framework.lua` là lớp trung gian duy nhất chạm vào framework — toàn bộ `server.lua` chỉ gọi qua bảng `Bridge` (`Bridge.GetPlayer`, `Bridge.GetMoney`, `Bridge.AddMoney`, `Bridge.RemoveMoney`, `Bridge.GetIdentifier`, `Bridge.GetName`, `Bridge.AddItem`). Nhờ vậy đổi framework không cần sửa logic game.

---

## 🗄️ Database

3 bảng tự tạo khi resource khởi động (hoặc import `sql.sql` thủ công):

- `s82taixiu_players` — thống kê tổng của từng người chơi (khoá theo định danh: `citizenid` ở QB/QBX, `identifier` ở ESX).
- `s82taixiu_rounds` — lịch sử từng vòng chơi (xúc xắc, tổng cược, lợi nhuận nhà cái...).
- `s82taixiu_transactions` — chi tiết từng lượt cược của từng người chơi.

---

## ⚠️ Lưu ý

- Đây là mini-game dùng **tiền/vật phẩm trong game** cho mục đích roleplay giải trí, không liên quan giao dịch tiền thật.
- Khi chuyển đổi giữa các server dùng framework khác nhau, hãy kiểm tra lại item trong `Config.ItemReward.item` có tồn tại trong hệ túi đồ tương ứng hay không trước khi bật `enabled = true`.
- Nếu server không cài bất kỳ hệ túi đồ nào ở trên và không phải ESX, hãy để `Config.ItemReward.enabled = false` (script vẫn hoạt động bình thường, chỉ không phát được vật phẩm).

---

**S82 Studio**
