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
   - **Release**：預設為程式中的 placeholder（`https://api.example.com/api/v1`），**正式上架前務必改 `#else` 預設網址，或使用編譯期注入（如 `.xcconfig`）**；僅在 Xcode 設 Run 的環境變數**無法**讓 TestFlight／上架版連正式 API

實作位置：`constructionApp/Core/Configuration/AppConfiguration.swift`。

**說明：** Git **分支**（feature／main）只影響程式版本，**不會**改後端路由；本機與正式只差「App 連到哪一台伺服器」，**路徑仍是** `/api/v1/...`。

### 與前端的差異（請不要搞混）

| 客戶端 | 設定方式 | 內容 |
|--------|----------|------|
| **Web 前端** | `VITE_API_URL` | 僅 **origin**（例 `https://api.example.com`），路徑由程式拼 `/api/v1/...` |
| **iOS App** | `API_BASE_URL` | **完整 API root**，結尾為 **`/api/v1`** |

兩者指向的 **主機應相同**，只是字串格式不同。

### Railway 正式站（範例）

若後端部署在 Railway，控制台 **Public URL** 通常為 `https://<服務名稱>.up.railway.app`（實際以專案內顯示為準）。  
iOS 的 **`API_BASE_URL` 不是只有 hostname**，要填 **完整 API 根**（`https` + 網域 + **`/api/v1`**），例如：

```text
https://construction-dashboard-backend-production.up.railway.app/api/v1
```

請將 `construction-dashboard-backend-production` 換成你 Railway 服務實際網域；若有綁 **自訂網域**，改用該網域，格式仍為 `https://你的網域/api/v1`。  
設定後可用瀏覽器或 `curl` 打任一已知 API 路徑確認連線正常。

### 在 Xcode 設定 `API_BASE_URL`（建議）

1. 開啟 **`constructionApp.xcodeproj`**
2. 上方工具列 **Run 鈕左側** 點 **Scheme 名稱**（如 `constructionApp`）→ **Edit Scheme…**
3. 左側選 **Run** → 上方分頁 **Arguments**
4. 下方 **Environment Variables** 區塊點 **+** 新增一列：  
   - **Name**：`API_BASE_URL`  
   - **Value**：例如本機 `http://127.0.0.1:3003/api/v1`、區網 `http://192.168.0.10:3003/api/v1`、或上節 Railway 完整網址  
5. 勾選該列左側 **☑**（未勾選則不會注入）
6. **Close** 關閉視窗

**本機開發**：通常只設 **Run** 即可（或 Debug 不設變數，沿用程式預設本機 URL）。  
從 Xcode 按 **Run** 時，上述 **Environment Variables** 會注入到 App 行程，**`API_BASE_URL` 會生效**。

**發佈（Archive → TestFlight / App Store）** 請注意：**打包後安裝到實機的 App，一般不會帶 Xcode Scheme 裡的環境變數**（那是給「從 Xcode 啟動」用的）。正式版要能連上 Railway，請擇一：

- **做法 A（最直覺）**：修改 `AppConfiguration.swift` 中 **`#else`（Release）** 的預設 URL 為正式 `https://…/api/v1`。會進 Git，公開 API 網址通常可接受。
- **做法 B**：用 **Build Configuration + `.xcconfig`**（或 Build Settings 的 `OTHER_SWIFT_FLAGS` 等）在 **編譯 Release 時**寫入常數／編譯旗標，避免把網址硬寫在 Swift 原始檔（進階；可再依團隊需要補範例檔）。

若 Release **未**改 `#else`（或其它編譯期注入），App 會仍指向 placeholder，**正式環境無法連線**。

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
2. **確認 `API_BASE_URL`** 指向正式站（見上文「Railway 正式站」與「發佈」兩種做法）：完整字串須為 `https://你的網域/api/v1`。
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
