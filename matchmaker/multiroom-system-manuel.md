# 房間對戰系統 — 使用說明

## 架構概覽

```
[HTTP Matchmaker]  ← 管理 Godot 伺服器 (port 分配 / 房間碼)
        │
        │  POST /room  建立房間 → 回傳 {code, port}
        │  POST /join  加入房間 → 回傳 {port}
        │
        ▼
[Godot 伺服器 (headless)]  ← ENet UDP，每個房間一個獨立 process
        │
    ┌───┴───┐
    ▼       ▼
 Player A   Player B
 (Godot Client  + Agent)
```

- **HTTP Matchmaker** 負責開房管理，不參與遊戲邏輯
- **Godot Server** 處理遊戲同步（能量/血量 authoritative）
- **Agent** 在玩家本機執行，不跑在伺服器上

---

## 伺服器架設（管理員）

### 前置需求

- Node.js ≥ 18
- Godot 4.6（`godot` 指令必須在 PATH 中）
- 本專案完整目錄

### 1. 啟動 Matchmaker

```bash
# 複製設定檔並編輯
cp matchmaker/.env.example matchmaker/.env

# 使用 .env 設定啟動（直接執行即可）
node matchmaker/server.js

# 也可以用環境變數覆蓋 .env 設定（cli 優先）
HTTP_PORT=4000 node matchmaker/server.js
```

| 環境變數 | 預設值 | 說明 |
|----------|--------|------|
| `HTTP_PORT` | `3000` | HTTP API 監聽 port |
| `PORT_RANGE_START` | `7777` | ENet port 池起始值 |
| `PORT_RANGE_END` | `7791` | ENet port 池結束值（15 間房間） |
| `GODOT_BIN` | `godot` | Godot 執行檔路徑 |
| `GODOT_PROJECT_PATH` | `.` | 專案目錄路徑 |

### 2. 防火牆設定

需開放的 port：

- **HTTP matchmaker**：`3000`（或自訂的 `HTTP_PORT`）
- **Godot ENet**：`7777 - 7791`（或自訂的 range）

客戶端會透過 LAN IP 直接連到這些 port。

---

## HTTP API（給客戶端 UI 實作者）

Matchmaker 提供兩個端點，所有請求/回應皆為 JSON。

### POST `/room` — 建立房間

建立一個新房間，會自動分配 ENet port、啟動 Godot 伺服器、產生六碼房間碼。

**請求：**

```http
POST http://<server-ip>:3000/room
Content-Type: application/json

{}
```

**成功回應 (200)：**

```json
{
  "code": "A3B9K2",
  "port": 7777
}
```

**失敗回應：**

| 狀態碼 | 回應 | 發生情境 |
|--------|------|----------|
| `503` | `{"error": "no free ports"}` | 房間數已達上限（預設 15 間） |

### POST `/join` — 加入房間

用房間碼加入既有房間，成功後回傳 ENet port。

**請求：**

```http
POST http://<server-ip>:3000/join
Content-Type: application/json

{"code": "A3B9K2"}
```

**成功回應 (200)：**

```json
{
  "port": 7777
}
```

**失敗回應：**

| 狀態碼 | 回應 | 發生情境 |
|--------|------|----------|
| `404` | `{"error": "room not found"}` | 房間碼不存在 |
| `410` | `{"error": "room expired"}` | 房間已過期（已有人加入，或逾時未加入） |

---

## 客戶端流程

客戶端使用 `HTTPRequest` node（Godot 內建）呼叫上面兩個 API，然後建立 ENet 連線。

### 流程圖

```
玩家 A（創建方）
───────────────
1. 點擊「創建房間」
2. POST /room → 拿到 code, port
3. 顯示房間碼 code 給玩家 B
4. 等待玩家 B 加入
5. 雙方都收到 port 後，ENet 連線到 <server-ip>:<port>
6. 選好 agent script，按準備
7. 雙方都準備好 → 遊戲開始
```

```
玩家 B（加入方）
───────────────
1. 點擊「加入房間」
2. 輸入玩家 A 給的六碼房間碼
3. POST /join → 拿到 port
4. ENet 連線到 <server-ip>:<port>
5. 選好 agent script，按準備
6. 雙方都準備好 → 遊戲開始
```

### 客戶端實作要點

**1. 取得 server IP**

比對端連到相同 LAN 網路。Server IP 是目前執行 matchmaker 的主機的區域網路 IP（例如 `192.168.1.100`）。建議在客戶端畫面讓玩家手動輸入。

**2. 建立 ENet 連線**

拿到 port 後，透過 Godot 的現有機制連線：

```
godot --path . --connect <server-ip> --port <port>
```

或在 Godot 內動態設定 `NetworkManager` 連線。

客戶端會自動在本機啟動 ApiServer（port 7749），agent 透過 WebSocket 連到本機 ApiServer 發送陷阱指令。

**3. 超時機制說明**

- **60 秒加入逾時**（伺服器端）：房間建立後，若第二個玩家在 60 秒內未加入，Godot 伺服器會被關閉，房間碼失效
- **90 秒準備逾時**（Godot 端）：第二個玩家加入後，若 90 秒內雙方都沒按準備，Godot 伺服器會自動退出

兩種逾時都不需要客戶端處理，伺服器會自動清理。

**4. 錯誤處理建議**

```
╔══════════════════════════════════════════╗
║  POST /room                              ║
║    ├─ 200 → 顯示房間碼，等待對手加入     ║
║    ├─ 503 → 顯示「伺服器已滿，請稍後再試」║
║    └─ 連線失敗 → 顯示「無法連線到伺服器」 ║
║                                          ║
║  POST /join                              ║
║    ├─ 200 → 開始 ENet 連線               ║
║    ├─ 404 → 顯示「房間碼無效」           ║
║    └─ 410 → 顯示「房間已過期或已滿」     ║
╚══════════════════════════════════════════╝
```

---

## 常見問題

### Q: 伺服器重開後，舊的 port 會被佔用嗎？

Matchmaker 啟動時會自動清除所有殘留的 Godot process（`pkill -f 'godot.*--server'`），確保 port 池是乾淨的。

### Q: 玩家斷線會發生什麼事？

Godot 的 `NetworkManager` 會偵測 peer 斷線並觸發 `server_disconnected` 訊號。遊戲結束後，Godot process 會退出，matchmaker 自動回收 port。

### Q: 可以同時有多少間房間？

由 `PORT_RANGE_START` 到 `PORT_RANGE_END` 決定。預設範圍 `7777-7791` 提供 15 個 port，可同時進行 15 場遊戲。

### Q: 一定要在 LAN 嗎？

目前設計是 LAN 用途。若要支援網際網路，需要在路由器設定 port forwarding（3000 + ENet range），且客戶端需知道 server 的公開 IP。
