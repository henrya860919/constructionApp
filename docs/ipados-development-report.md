# constructionApp：從 iOS 到 iPadOS 開發規劃報告

**專案現況摘要**：`constructionApp` 為 **SwiftUI** 原生 App，採 **Tactical Obsidian** 視覺規範（見 `.cursor/rules/tactical-obsidian-design.mdc`）。Xcode 專案已設 **`TARGETED_DEVICE_FAMILY = "1,2"`**（同時勾選 iPhone 與 iPad），`Info.plist` 亦已宣告 **`UISupportedInterfaceOrientations~ipad`**，代表 **App 已可在 iPad 上安裝執行**。

本報告區分兩件事：

1. **「能在 iPad 上跑」** — 多數情況已成立（或為相容模式／置中放大顯示，視 App Store 與 Xcode 設定而定）。
2. **「針對 iPadOS 設計與優化」** — 需要額外的版面、互動與系統能力規劃，才是本文件重點。

---

## 一、可以針對 iPadOS 開發嗎？

**可以。** iPadOS 與 iOS 共用 **同一套 Apple 平台 SDK**（Swift / SwiftUI / UIKit），同一個 Xcode target 通常以 **Universal（iPhone + iPad）** 或 **僅 iPad** 發佈。你不需要換語言或換專案類型；差異主要在 **版面適應、輸入方式（觸控／觸控板／鍵盤／Apple Pencil）、多工與視窗行為**。

---

## 二、目前專案與「真正 iPad 體驗」之間的差距

| 面向 | 現況（依 repo） | iPadOS 優化時常見目標 |
|------|-----------------|------------------------|
| 裝置家族 | 已含 iPhone + iPad（`1,2`） | 維持 Universal 或拆成 iPad 專用 SKU（產品決策） |
| 導航 | `NavigationStack` + 底部 **FloatingTabBar** | iPad 常改為 **側欄（Sidebar）+ 詳情區**，或 `NavigationSplitView` |
| 模組切換 | 底部浮動 Tab，適合單手與窄螢幕 | 大螢幕可改 **左欄圖示＋文字**、詳情固定右側，減少全畫面切換 |
| 多場景 | `UIApplicationSupportsMultipleScenes = false` | 若要在 iPad 上支援 **多視窗／Stage Manager 並排**，需評估改為 `true` 與 Scene 委派 |
| 方向 | iPad 已支援多方向 | 確認表單、相機、圖說檢視在 **橫向** 仍可用；必要時鎖定特定子畫面 |
| 輸入 | 以觸控為主 | 補 **游標懸浮（hover）**、**鍵盤快捷鍵**、**觸控板手勢**（選用） |

---

## 三、要做什麼事情（實作檢查清單）

### 3.1 Xcode 與發佈

- [ ] 在 **Signing & Capabilities** 確認 **Devices** 含 iPad；App Store Connect 上選擇 **iPhone / iPad** 或僅 iPad（依產品策略）。
- [ ] 若希望 App Store 顯示 **「專為 iPad 設計」** 等級，需符合 Apple 對 **自適應版面、原生控制項** 的審核期待（避免長期僅以「放大版 iPhone」呈現）。
- [ ] 使用 **iPad 模擬器** 與 **實機**（含外接鍵盤／觸控板若有）做迴歸測試。

### 3.2 SwiftUI 版面與 API

- [ ] 以 **`horizontalSizeClass` / `verticalSizeClass`**（或 `GeometryReader` + 斷點）區分 **compact**（窄，接近手機）與 **regular**（寬，平板／橫向）。
- [ ] iPad **regular** 寬度：導入 **`NavigationSplitView`** 或 **自訂 HStack：Sidebar + 內容**，讓「模組列表」與「模組內容」並列。
- [ ] 檢視 **全螢幕 sheet、浮動 Tab、安全區（Safe Area）** 在橫向與 **台前調度（Stage Manager）** 可調視窗下的表現。
- [ ] 列表＋詳情型畫面（查驗、缺失、報修、圖說）：採 **主從（Master–Detail）** 模式，避免大螢幕仍只顯示單欄列表。

### 3.3 系統與互動（選用但建議）

- [ ] **鍵盤**：常用動作（儲存、搜尋、下一筆）考慮 `.keyboardShortcut`。
- [ ] **游標 / 觸控板**：按鈕與可點區域在 hover 時微幅 **scale / opacity**（與 Tactical 風格一致即可）。
- [ ] **多視窗**：若業務需要「同時開兩份日誌／兩張圖」，再評估 **Multiple Scenes**；複雜度與離線同步狀態需一併設計。
- [ ] **拖放（Drag & Drop）**：圖說、附件若適合從檔案 App 拖入，可提升 iPad 生產力形象。

### 3.4 相機、照片、圖說

- [ ] 相機 UI 在 iPad 上可能為 **popover 或全螢幕**；需測試 **分割畫面** 下相機權限與旋轉。
- [ ] 大圖／PDF：善用 **較大可視區**；考慮 **雙欄**（縮圖列表 + 預覽）或 **工具列置頂**。

### 3.5 測試矩陣（建議）

| 情境 | iPhone | iPad 直向 | iPad 橫向 | Stage Manager 窄／寬 |
|------|--------|-----------|-----------|------------------------|
| 登入／專案選擇 | ✓ | ✓ | ✓ | ✓ |
| 各模組主流程 | ✓ | ✓ | ✓ | ✓ |
| FloatingTabBar 是否遮擋內容 | ✓ | ✓ | ✓ | ✓ |
| Sheet／表單鍵盤 | ✓ | ✓ | ✓ | ✓ |

---

## 四、介面設計規劃（與 Tactical Obsidian 一致）

以下為 **建議的資訊架構與視覺層級**，實作時仍以既有 token（`surface`、`surface-container-*`、`primary`、**12pt 圓角**、無主分割線等）為準。

### 4.1 設計原則（延續品牌）

- **大螢幕 ≠ 塞更多欄位**：以 **色階深度 + 留白** 區分「導航／列表／詳情／次面板」，維持編輯台感。
- **主色（Safety Orange）** 仍僅用於 **CTA、焦點、關鍵狀態**，避免大面積鋪色。
- **側欄與頂欄** 使用 `surface` / `surface-container-low`；內容區 `surface-container` 階層；卡片維持 **12pt continuous corner**。

### 4.2 Toolbar 與側欄分工（平板仍建議使用 toolbar）

**iPad 並沒有「不建議使用 toolbar」**；導航列上的動作、`.toolbar`（如 `navigationBarTrailing`、`primaryAction`、`bottomBar`）與內容區工具列，都是 **HIG 常見且合適** 的做法。

本報告建議大螢幕改 **側欄** 的是 **「跨模組切換」（查驗／報修／日誌…）**，與 **「當前畫面上的操作」** 應分開思考：

| 職責 | 建議位置 |
|------|-----------|
| **跨模組切換** | iPhone／compact：底部 Tab（如現有 FloatingTabBar）；iPad **regular**：**側欄** 較省垂直空間、路徑清楚，也利於外接鍵盤導覽。 |
| **當前模組內動作**（新增、篩選、完成、分享、更多選單） | **`toolbar`** 或導航列／內容區頂部工具區；與側欄 **並存**，不互斥。 |

實務版型常為：**側欄負責「去哪個模組」** + **內容欄的 navigation／toolbar 負責「在這個模組裡要做什麼」**。若僅為了放模組切換而塞滿 toolbar，反而容易擁擠；反之，若完全不用 toolbar，新增／篩選等動作會難以符合使用者對 iPad「生產力工具」的期待。

### 4.3 Compact（iPhone 與 iPad 窄分欄）— 維持現有心智

```
┌─────────────────────────────┐
│ 導航列：專案名 · 設定        │
├─────────────────────────────┤
│                             │
│      模組內容（全寬）        │
│                             │
├─────────────────────────────┤
│     ◀ FloatingTabBar ▶      │
└─────────────────────────────┘
```

- 與現有 **MainShellView + FloatingTabBar** 對齊；Stage Manager 極窄時也應退回此模式。

### 4.4 Regular（iPad 寬螢幕）— 建議「側欄 + 內容」

```
┌──────────┬──────────────────────────────────────────┐
│ NexA     │  導航列：當前模組標題 · 篩選／同步狀態    │
│ 標誌區   ├──────────────────────────────────────────┤
│ (可選)   │                                          │
├──────────┤   主內容區（列表或主從）                  │
│ 查驗     │   · 左：列表／樹狀／日曆                  │
│ 缺失     │   · 右：詳情／編輯（Master–Detail）       │
│ 報修     │                                          │
│ 圖說     │                                          │
│ 日誌     │                                          │
├──────────┤                                          │
│ 設定入口 │                                          │
└──────────┴──────────────────────────────────────────┘
```

- **左側欄寬度**：固定約 **240–280 pt**（可折疊為 icon-only 約 **72 pt**，選用）。
- **模組切換**：由底部 Tab 改為 **側欄垂直列表**（圖示 + 標題），與系統 **Settings**、**Mail** 類 iPad 版一致，利於鍵盤導覽（方向鍵 + return）。
- **頂部**：保留 **離線橫幅**（`FieldOfflineBanner`）時，建議橫跨 **整個上緣**（側欄 + 內容區之上）或僅內容區 — 需統一視覺，避免斷裂。

### 4.5 主從列表示意（以報修／查驗為例）

```
側欄          │ 列表區（surface-container-low）     │ 詳情（surface-container）
              │ ┌─────────────────────────────┐   │ ┌─────────────────────────┐
              │ │ 搜尋 · 篩選 chip              │   │ │ 標題／狀態 readout       │
              │ ├─────────────────────────────┤   │ ├─────────────────────────┤
              │ │ 列 1（交替背景）              │   │ │ 表單／照片／時間軸        │
              │ │ 列 2                         │   │ │                         │
              │ │ 列 3                         │   │ │ 底部固定：主 CTA 列       │
              │ └─────────────────────────────┘   │ └─────────────────────────┘
```

- **列分割**：遵守設計規範 — **不以 1px 實線為主**；用 **間距與背景色階** 區分行。
- **詳情右欄**：大螢幕下表單可改 **雙欄表單**（左欄位標、右輸入），減少捲動長度。

### 4.6 圖說管理（Drawing）— iPad 加值版面

- **左**：專案／版本／檔案樹或縮圖格線。
- **中**：大預覽（PDF／圖面）。
- **右（可選）**：圖層、標註、下載狀態、離線快取（與現有 offline 流程對齊）。

窄螢幕時 **右欄收合為 sheet 或 inspector 按鈕**。

### 4.7 施工日誌（Daily Log）— 寬螢幕

- **上**：日期切換、專案脈絡（維持既有 paging 邏輯）。
- **下**：**雙欄** — 左「人員／料項／PCCES」摘要列表，右「當日編輯區」，或 **日曆 + 當日內容** 並列。

---

## 五、建議實施順序（里程碑）

1. **M0 — 驗證**：全模組在 iPad 模擬器直／橫向跑一輪，列出 **版面破圖、Tab 遮擋、Sheet 高度** 問題清單。  
2. **M1 — 適應性骨架**：抽出 `RootNavigationShell`：compact → 現有 `MainShellView`；regular → `NavigationSplitView` + 側欄。  
3. **M2 — 高流量模組主從**：優先 **查驗、報修、圖說**（列表＋詳情最明顯）。  
4. **M3 — 輸入加值**：鍵盤快捷鍵、hover（選用）。  
5. **M4 — 多視窗（選用）**：僅在產品明確需要時啟用 Multiple Scenes。

---

## 六、結論

- **技術上**：針對 iPadOS 開發完全可行，且 **專案已具備 iPad target 基礎設定**。  
- **產品上**：若要稱為「iPad 版體驗」，重點是 **regular 寬度下的導航與主從版面**，而非僅放大 iPhone UI。  
- **設計上**：在維持 **Tactical Obsidian** 前提下，以 **側欄 + 雙欄／三欄內容** 發揮大螢幕，並搭配 **toolbar 處理模組內動作**；在 compact 時 **完整退回** 現有底部 Tab 行為，是最穩健的路線。

---

*文件版本：依 2026-04-30 之 repo 狀態整理；Xcode 設定以 `constructionApp.xcodeproj` 與 `Supporting/Info.plist` 為準。*
