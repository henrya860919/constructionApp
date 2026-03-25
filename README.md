# Construction App（iOS）

與 **Construction Dashboard** 共用後端的現場作業 App（SwiftUI）。透過 REST API 存取與 Web 相同之 **`/api/v1`** 資源（報修、缺失改善、自主查驗等）。

---

## 需求

- Xcode（建議最新穩定版）
- Apple Developer 帳號（實機、TestFlight、App Store）
- 可連線的 **後端**（本機或正式 HTTPS）

---

## API 網址怎麼設（與後端連線）

App 內所有請求使用 **`AppConfiguration.apiRootURL`**，其值來自：

1. **環境變數 `API_BASE_URL`（優先）** — 完整 API 根路徑，**必須含 `/api/v1`**  
   - 例：`https://your-api.up.railway.app/api/v1`  
   - 例（本機）：`http://127.0.0.1:3003/api/v1`
2. 若未設定，則依編譯設定：
   - **Debug**：預設 `http://127.0.0.1:3003/api/v1`
   - **Release**：預設為程式中的 placeholder（`https://api.example.com/api/v1`），**正式上架前務必改為真實網址或一律用 Scheme 注入 `API_BASE_URL`**

實作位置：`constructionApp/Core/Configuration/AppConfiguration.swift`。

### 與前端的差異（請不要搞混）

| 客戶端 | 設定方式 | 內容 |
|--------|----------|------|
| **Web 前端** | `VITE_API_URL` | 僅 **origin**（例 `https://api.example.com`），路徑由程式拼 `/api/v1/...` |
| **iOS App** | `API_BASE_URL` | **完整 API root**，結尾為 **`/api/v1`** |

兩者指向的 **主機應相同**，只是字串格式不同。

### 在 Xcode 設定 `API_BASE_URL`（建議）

1. 選專案 → **Product → Scheme → Edit Scheme…**
2. **Run**（左側）→ **Arguments** 標籤
3. **Environment Variables** 新增：  
   - Name: `API_BASE_URL`  
   - Value: 你的後端，例如 `http://192.168.0.10:3003/api/v1`（實機連同區網後端）或正式 `https://.../api/v1`

**Archive / Release** 請在對應 Scheme 的 **Archive** 或 **Release Run** 同樣加入變數，或修改 `AppConfiguration.swift` 中 `#else` 的預設 URL 為正式網址（不建議把秘密寫進 Git，網址本身通常可接受）。

### App Transport Security（ATS）

- **正式環境**後端應使用 **HTTPS**。
- 僅開發時若必須連 **HTTP** 本機，可能需在 **Info.plist** 設定 ATS 例外（僅限開發／內部分發；上架 App Store 請用 HTTPS）。

### CORS

CORS 僅影響瀏覽器。**原生 App** 不受 CORS 限制；只要 URL 正確、TLS／網路允許即可呼叫後端。

---

## 本機開發流程

1. **啟動後端**（construction-dashboard-backend）  
   - 預設 `http://localhost:3003`  
   - 完成 PostgreSQL 與 `prisma migrate`、必要時 `db:seed`
2. **Simulator**  
   - 可用預設 `http://127.0.0.1:3003/api/v1`（與 Debug 預設一致），或設 `API_BASE_URL`。
3. **實機**  
   - 電腦與手機需同一區網  
   - 後端需監聽 `0.0.0.0`（本專案預設 `HOST` 可為 `0.0.0.0`）  
   - `API_BASE_URL` 使用 **電腦區網 IP**，例如 `http://192.168.1.50:3003/api/v1`  
   - HTTP 時注意 ATS 例外

在 Xcode 開啟 **`constructionApp.xcodeproj`**（或 workspace，依 repo 實際結構），選目標裝置後 **Run**。

---

## 正式環境（TestFlight / App Store）

1. **後端**已部署於公開 HTTPS（例 Railway），且 `npx prisma migrate deploy` 已執行。
2. 在 **Release** 建置使用的 Scheme 設定 **`API_BASE_URL=https://你的後端/api/v1`**，或將 `AppConfiguration` 的 Release 預設改為該網址。
3. **後端不必**為 App 單獨開 CORS，但需：
   - 憑證有效、鏈完整  
   - 防火牆／平台允許來自客戶端的連線
4. Archive → Upload → TestFlight／審核。

---

## 專案結構（簡述）

| 路徑 | 說明 |
|------|------|
| `constructionApp/Core/Network/APIService.swift` | API 呼叫 |
| `constructionApp/Core/Configuration/AppConfiguration.swift` | `apiRootURL`、檔案絕對 URL 組裝 |
| `constructionApp/Features/*` | 各功能模組 UI |

---

## 與 Web 前後端 repo 的對應

| Repo | 角色 |
|------|------|
| `construction-dashboard-backend` | API、`/api/v1`、PostgreSQL、JWT |
| `construction-dashboard-frontend` | 瀏覽器儀表板與 PWA |
| `constructionApp`（本 repo） | iOS 原生客戶端 |

三者在正式環境應指向**同一後端網域**（僅客戶端設定格式的差異如上表）。
