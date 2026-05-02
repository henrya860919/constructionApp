## constructionApp · iPadOS 設計規格書

**版本**：2026-04-30 · **作者視角**：Apple Application Designer（HIG · iPadOS 18 / 26）
**目的**：在維持 _Tactical Architect_ 視覺品牌、且 iPhone 體驗不受影響的前提下，將 App 升級為「**為 iPad 設計**」等級的生產力工具。靈感主軸：**iPad 備忘錄（Notes）三欄式**＋**iPadOS Liquid Glass Sidebar**＋**Apple Pencil / Magic Keyboard 一級支援**。

---

### 0. 本規格與既有開發報告的關係

`docs/ipados-development-report.md` 已說明「能跑」與「該做什麼」（Xcode 設定、SizeClass、SplitView、Toolbar 分工、實施里程碑）。本文件不重複那些結論；它聚焦在 **設計層級**：

- 為什麼採三欄式、欄位寬度／間距／材質的具體數值。
- 各模組（5 個）在 iPad Regular 寬度下的完整版型。
- Pencil / 觸控板 / 鍵盤的互動細節。
- 視覺 Token 在 iPad 上的調整（材質、模糊、層次、留白）。

> 簡言之：開發報告回答「做什麼」，本文件回答「**長什麼樣、為什麼長那樣**」。

---

### 1. 設計北極星（North Star）

| 原則 | 在 iPad 上的具體表現 |
|------|---------------------|
| **大螢幕 ≠ 塞更多欄位** | 用「**色階深度＋留白**」分層，而非更多分隔線；同畫面最多 3 個資訊密度層級。 |
| **生產力導向** | 鍵盤可達、Pencil 可寫、觸控板可懸浮；任何主要動作在 ≤ 2 步內可達。 |
| **離線優先** | iPad 多在工地外接基地台或無網環境；同步狀態在 **三欄之上的全寬橫幅** 永遠可見。 |
| **品牌延續** | _Tactical Architect_ 的 Safety Blue（`#3B82F6`）只用在 CTA 與當前選取狀態，永遠不大面積鋪色。 |
| **Apple 原生語彙** | 採 `NavigationSplitView`、`.inspector`、`.searchable`、`.toolbar`、`Materials`，**避免重新發明系統元件**。 |

---

### 2. 為什麼以「iPad 備忘錄」為設計母體

備忘錄是 Apple 在 iPad 上對「**列表型生產力 App**」最完整的示範。它與本 App 的同構特徵：

| 特徵 | 備忘錄 | constructionApp |
|------|--------|------------------|
| 多項可導航分類 | 我的、iCloud、共享、最近刪除… | 5 個業務模組 + 專案切換 |
| 一個分類內有大量列表項 | 筆記 | 查驗單、缺失、報修單、圖面、日誌 |
| 列表項打開後是長表單／文件 | 筆記內文 | 查驗表單、PDF 圖說、日誌頁 |
| 需要附件與標註 | 圖片、手繪、掃描 | 工地照片、簽名、Pencil 圖說標註 |
| 需要快速建立 | 浮動「+」 | 各模組「新增」CTA |

差異在於：構築物業有 **離線同步**、**工地照片大量**、**PDF 圖說標註** 三個額外重點。設計時把這三點折進備忘錄三欄骨架即可。

---

### 3. 適應性骨架（Adaptive Shell）

#### 3.1 斷點

| 環境 | 觸發條件 | 版型 |
|------|---------|------|
| **Compact** | `horizontalSizeClass == .compact`<br>iPhone 任意方向、iPad 直向 1/2 分割、Stage Manager 極窄視窗 | **完整退回**現有 `MainShellView` + `FloatingTabBar`（單欄）。 |
| **Regular（雙欄）** | `regular`，視窗寬度 **≥ 768pt** 且 **< 1100pt**<br>iPad 直向、Stage Manager 中等視窗 | **NavigationSplitView (.balanced)**：Sidebar（可折疊）+ 內容欄（可在欄內切換 List ↔ Detail）。 |
| **Regular（三欄）** | `regular`，視窗寬度 **≥ 1100pt**<br>iPad 橫向、Stage Manager 全螢幕、12.9" iPad | **NavigationSplitView (.prominentDetail)**：Sidebar + List + Detail，三欄並列；可選 Inspector。 |

> 切換時走 `NavigationSplitViewVisibility` 動畫；不破壞使用者當前的選取狀態（List 選取記憶 + Detail 同 ID 顯示）。

#### 3.2 欄位幾何

```
┌──────────────┬──────────────────────┬──────────────────────────┐
│ Sidebar       │ Content List          │ Detail                    │
│ 260pt 固定    │ 360pt 起、可拖曳       │ 剩餘 fill                  │
│ 可折疊 → 76pt │ 可隱藏（雙欄縮成單列） │ Inspector 320pt（可選）    │
└──────────────┴──────────────────────┴──────────────────────────┘
```

- **Sidebar**：固定 **260pt**；折疊後 **76pt**（icon-only，與 macOS Sonoma 後一致）。
- **List 欄**：預設 **360pt**，使用者可拖至 **300–480pt**。
- **Detail 欄**：吃剩餘空間，最小 **520pt** 才打開三欄；不足時自動退雙欄。
- **Inspector**：右側固定 **320pt**，僅在圖說／查驗單需要時出現（`.inspector(isPresented:)`）。

#### 3.3 與 Liquid Glass 的關係（iOS / iPadOS 26）

設計母體：**iPad 備忘錄（Notes）三欄收合**（參考截圖 IMG_0337/0338/0339）。

- **欄位之間沒有可見的 1px 分割線**，純靠 `surface`／`surfaceContainerLow`／`surface` 的色階差形成欄位邊界。
- **Toolbar 不是一條長橫**，而是切成 **多個獨立 Liquid Glass capsule 群組**，每組各自 blur + 圓角膠囊 + 微陰影，群組之間以空白分隔（見 §4.5）。
- **Sidebar** 使用 `.glassEffect(.regular)`，疊在 `surface` 上呈現「壓克力刻面」感，與既有 `FloatingTabBar` 同語言。
- **List 欄** 不打玻璃（純 `surfaceContainerLow`），讓視覺重心落在最右側 Detail。
- **離線橫幅** 跨欄置頂，永不被 sidebar 遮蓋；位於 iPadOS status bar 之下、shell 之上。

> 若使用者裝置不支援 Liquid Glass（iPadOS < 26），自動降階為 `.background(.thinMaterial)` 或 `.background(theme.surfaceContainerLow)`；capsule 仍維持結構，視覺仍成立。

#### 3.4 欄位收合（每個欄位都必須可單獨收合／展開）

> 仿備忘錄：使用者可以**任意組合**收合 Sidebar、List、Inspector，得到 4 種主要組合（三欄／隱藏 Sidebar／隱藏 List／僅 Detail）。每個 toggle 都有對應的鍵盤快捷鍵與 toolbar 按鈕。

| 動作 | 觸發位置 | 圖示語意 | 快捷鍵 |
|------|---------|---------|--------|
| 切換 Sidebar | **Sidebar 頂部 capsule 第 1 顆** + **List 頂部 capsule 第 1 顆** | `sidebar.left`（左欄被 highlight 的 SF Symbol） | `⌘\` |
| 切換 List | **List 頂部 capsule 末顆**（chevron 左）+ **Detail 頂部 capsule 第 1 顆** | `sidebar.left` 變體（中欄被 highlight） | `⌘⇧\` |
| 切換 Inspector | **Detail 頂部右側 capsule** + **Inspector 頂部關閉鈕** | `sidebar.right`（右欄被 highlight） | `⌘⌥I` |

設計守則：

1. **「每個欄位的 toolbar 左群第一顆 icon」永遠是『展開／收合左邊那欄』** — 形成一致的 mental model：點左群第一顆 = 對左邊隔壁那欄做事。
2. **「右群末顆 icon」是『開／關 Inspector』**（僅在該模組有 Inspector 時顯示）。
3. **動畫**：欄位寬度用 `cubic-bezier(.2,.8,.2,1)` 320ms 過渡；沒有突然消失。
4. **狀態保留**：收合 Sidebar 時，當前選取的模組與 List 選取項都不能丟失。
5. **Compact 退出**：若視窗寬度 < 768pt，自動退回 `MainShellView` + `FloatingTabBar`，所有欄位 toggle 失效（因為只有單欄）。

---

### 4. Sidebar 設計（取代 FloatingTabBar 的 iPad 形態）

```
┌─────────────────────────────┐
│  [Logo] NexA · 工地日誌     │  ← App 識別區（24pt）
├─────────────────────────────┤
│  [▼] 中山大樓新建工程        │  ← Project Picker（按下換專案）
│      工區 B / 12F            │
├─────────────────────────────┤
│  常用                         │  ← Section header（uppercase, +5% kerning）
│  ✓  查驗            12       │
│  ⚠  缺失             3 ●     │  ← 紅點＝有未上傳
│  🔧 報修             7       │
│  📐 圖說管理                  │
│  📝 日誌                      │
├─────────────────────────────┤
│  最近 / 釘選                  │  ← 動態區（可選，預設折疊）
│  📌 4F 樓地板查驗單           │
│  📌 B1 機房漏水報修           │
├─────────────────────────────┤
│  [↕] 同步狀態：12 筆待上傳    │  ← Footer，永遠可見
│  [⚙] 設定                    │
└─────────────────────────────┘
```

#### 4.1 視覺規格

- **背景**：`surface` + `glassEffect(.regular)`（Liquid Glass）。
- **每列高度**：**44pt**（符合 HIG 觸控目標 + Magic Keyboard 鍵盤導覽舒適度）。
- **選取狀態**：12pt 圓角、`primary` 漸層填滿整列、文字白；**非選取列 hover** 時 `surfaceContainer` 半透。
- **數字徽章**：右側 `surfaceContainerHigh` 膠囊；超過 99 顯示 `99+`。
- **未上傳紅點**：徽章後加 `statusDanger` 8pt 圓點，提示有離線資料。

#### 4.2 折疊狀態（76pt，icon-only）

- 僅顯示 SF Symbol，置中。
- 選取項：12pt 圓角主色方塊（與現有 FloatingTabBar 選中膠囊一致）。
- Hover 顯示 tooltip（`.help()`），含模組名與徽章。

#### 4.3 與 FloatingTabBar 的取捨

> **不是替換，而是分流**：
> - **Compact**：底部 `FloatingTabBar`（單手、窄）。
> - **Regular**：左側 `Sidebar`（鍵盤、生產力）。
>
> 兩者共用 `FieldModuleTab` enum，狀態同步；切換 SizeClass 時模組選取狀態 **保留不重置**。

#### 4.5 Toolbar 設計：Capsule 群組（核心規範）

> **這是與 iOS 既有設計最大的不同。** 在 iPad 上，Detail 欄頂部 toolbar **不再是「跨欄一條霧化長條」**，而是 **多個各自獨立的 Liquid Glass 膠囊**。直接呼應 iPadOS 26 備忘錄的 toolbar 語言（IMG_0337/0338/0339）。

##### 4.5.1 Capsule 群組分配

每個 Detail 頂部 toolbar 由 **3 個 capsule 群組**（左／中／右）組成，中間用 `Spacer()` 推開：

```
┌──────────┐  ┌─────────────────────────────┐                ┌──────────┐
│  ◧   +  │  │ 格式  ☰  ▦  ✎  ↑  ⋯          │                │  🔍   ◨   │
└──────────┘  └─────────────────────────────┘                └──────────┘
   左群             中群（內容操作）              ← spacer →        右群
   欄位 + 新增      contextual actions                          搜尋 + Inspector
```

| 群組 | 內容 | 寬度 |
|------|------|------|
| **左群** | (1) 切換左隔壁欄、(2) 新增 | 跟隨內容 |
| **中群** | 該模組的 contextual actions（格式、清單、表格、Pencil、分享、更多…） | 跟隨內容 |
| **右群** | 搜尋、Inspector toggle | 跟隨內容 |

##### 4.5.2 Capsule 視覺規格

- **背景**：`Material.regularMaterial` + 自訂 tint，dark `rgba(28,38,52,.78)` / light `rgba(255,255,255,.92)`
- **模糊**：`backdrop-filter: blur(28px) saturate(180%)`（CSS）／`.glassEffect(.regular)`（SwiftUI iOS 26+）
- **形狀**：`Capsule()`（HIG 標準膠囊）
- **內部 padding**：4pt
- **陰影**：`0 6px 20px -10px rgba(0,0,0,.6)` + 內框 `inset 0 0 0 1px rgba(255,255,255,.04)`
- **內部按鈕**：高度 34pt、最小寬 34pt（icon-only）；hover 時 `rgba(127,135,150,.14)` 圓角填色；選中時 `primary` 漸層

##### 4.5.3 漸進式顯示（Progressive disclosure）

當 Sidebar 或 List 收合時，Detail 欄獲得更多寬度，**中群可選擇性多顯示動作**：

| 狀態 | 中群顯示的動作數 |
|------|------------------|
| 三欄（窄 Detail） | 4 個（格式、Pencil、分享、⋯） |
| 雙欄（中 Detail） | 6 個（+ 清單、表格） |
| 僅 Detail（寬） | 7 個（+ 附件 / 麥克風） |

實作可用 `ViewThatFits { … }` 或對 toolbar items 量測寬度自動決定要不要顯示。

##### 4.5.4 浮動 Pencil FAB（圖說模組）

圖說 PDF 預覽右下角放一顆獨立浮動 Pencil 按鈕（56pt 圓形 + 主色漸層 + 大陰影），與 toolbar 分離，呼應備忘錄右下角 Pencil 喚起體驗。其他模組不顯示。

#### 4.6 列表選中態：Capsule fill（不貼欄位邊）

> 同樣承襲備忘錄：列表項選中時不是「整列拉滿底色」，而是 **保留 4–8pt 邊距的 capsule fill**。

```swift
// SwiftUI 大致樣式
RoundedRectangle(cornerRadius: 12, style: .continuous)
  .fill(isSelected
      ? LinearGradient(
          colors: [primary.mix(with: containerHigh, by: 0.20),
                   primary.mix(with: containerHigh, by: 0.08)],
          startPoint: .topLeading, endPoint: .bottomTrailing)
      : .clear)
  .padding(.horizontal, 4)
```

- **未選中**：透明背景，hover 時 `surfaceContainer`。
- **已選中**：圓角 12pt、保留水平 4pt 邊距、`primary` 漸層雙層透明（20% → 8%），加 `0 6px 18px -10px rgba(primary,.4)` 微陰影。
- **不再用奇偶交替背景**（與第一版設計差異）：留白 + 列高就足以辨識行。

---

### 5. 各模組三欄佈局（Module-by-Module）

#### 5.1 查驗（Self-Inspection）

```
Sidebar │ Inspection List                       │ Inspection Detail
        │ ┌─────────────────────────────┐    │ ┌──────────────────────────┐
        │ │ [搜尋]    [篩選 ▾] [+ 新增]   │    │ │ 4F 樓地板水平度查驗      │
        │ ├─────────────────────────────┤    │ │ 進行中 · 2026/04/30      │
        │ │ ▣ 4F 樓地板水平度  ●        │    │ ├──────────────────────────┤
        │ │   進行中 · 14 項              │    │ │ [雙欄表單]                │
        │ │ ─────────────────────       │    │ │ 項次｜判定｜備註           │
        │ │ ▣ 3F 隔間牆位置              │    │ │ ─────────────            │
        │ │   已通過 · 18 項              │    │ │ ⓘ 照片區（4 欄縮圖）      │
        │ │ ─────────────────────       │    │ │ ⓘ 簽名區                 │
        │ │ ▣ B2 機電配管                │    │ ├──────────────────────────┤
        │ │   待覆驗 · 9 項               │    │ │ [儲存]  [送審]  […]       │
        │ └─────────────────────────────┘    │ └──────────────────────────┘
```

- **List 欄**：每項 **76pt** 高，標題 17pt semibold + 副標 13pt mutedLabel + 狀態徽章；交替背景 `surfaceContainerLow` / `surfaceContainer` 取代分隔線。
- **Detail 欄頂部**：sticky toolbar，`.glassEffect(.thin)`；包含麵包屑 + 同步狀態 + Pencil 切換。
- **雙欄表單**：寬度 ≥ 720pt 時自動轉 2 column（左：項次/標籤，右：判定/輸入），減少捲動。
- **Inspector（可選）**：照片大圖檢視、版本歷史。

#### 5.2 缺失（Deficiency）

```
Sidebar │ Map / List 切換                        │ Deficiency Detail + Inspector
        │ [▦ 平面圖] [☰ 列表]                    │ ┌──────────────────────────┐
        │                                        │ │ #DEF-0427-002             │
        │ 平面圖模式：                            │ │ 5F 走廊 · 滲水            │
        │  顯示縮小平面，紅點＝缺失位置；          │ ├──────────────────────────┤
        │  點選紅點 → 右側 Detail 直接開啟。       │ │ 照片輪播（大圖）          │
        │                                        │ │ 描述／責任單位／回覆紀錄  │
        │ 列表模式：                              │ ├──────────────────────────┤
        │  類同 5.1，但篩選 chip 含「責任單位」    │ │ Inspector：時間軸         │
        │  與「狀態」雙軸。                        │ │ · 04/27 開立              │
        │                                        │ │ · 04/28 派工              │
        │                                        │ │ · 04/29 完工待驗          │
```

- **平面圖／列表切換**：在 List 欄頂部以 `Picker(.segmented)` 切換；狀態記憶在使用者偏好。
- **平面圖**：以縮放（pinch / Pencil double-tap）查看；紅點 hover 顯示 tooltip 卡片。
- **Inspector 時間軸**：iPad 三欄獨有；雙欄／Compact 時收成 Detail 內可摺疊段落。

#### 5.3 報修（Repair）

```
Sidebar │ Repair Tickets                          │ Repair Detail
        │ ┌─────────────────────────────┐    │ ┌──────────────────────────┐
        │ │ Kanban 切換：                  │    │ │ #REP-0428-005             │
        │ │ [待派工 5][處理中 12][完工 33] │    │ │ B1 機房 · 漏水            │
        │ ├─────────────────────────────┤    │ ├──────────────────────────┤
        │ │ 卡片列：                       │    │ │ 描述、照片、回填、簽收    │
        │ │ ・ #REP-0428-005             │    │ │                            │
        │ │   B1 機房漏水 · 高優先         │    │ │                            │
        │ │ ・ #REP-0428-006             │    │ │                            │
        │ └─────────────────────────────┘    │ └──────────────────────────┘
```

- **List 欄**：Segmented 切換看板狀態；卡片帶優先級色條（左 4pt 直紋，`statusDanger` / `tertiary` / `mutedLabel`）。
- **拖放**：iPad 上支援把卡片從 List 拖到 Sidebar 的「不同責任單位」做派工（選用，M3 之後）。

#### 5.4 圖說管理（Drawing）— iPad 旗艦體驗

```
Sidebar │ Drawing Browser                         │ PDF Preview         │ Layers Inspector
        │ [專案 ▾]                                │ ┌─────────────────┐ │ ┌──────────────┐
        │ ┌──────────────┐                       │ │                 │ │ │ 顯示圖層      │
        │ │ 縮圖格線      │                       │ │  全頁 PDF       │ │ │ ☑ 結構       │
        │ │ 4 cols        │                       │ │  + 標註覆蓋     │ │ │ ☑ 機電       │
        │ │               │                       │ │                 │ │ │ ☐ 給水       │
        │ │ 每張帶版本    │                       │ │                 │ │ ├──────────────┤
        │ │ 與下載狀態    │                       │ │                 │ │ │ Pencil 工具   │
        │ │ ⏬ 雲端 / 已快取│                       │ │                 │ │ │ 鋼筆／螢光／橡│
        │ └──────────────┘                       │ └─────────────────┘ │ │ 顏色 / 粗細    │
        │                                         │ [縮圖 1/24] [+] [─]│ ├──────────────┤
        │                                         │                     │ │ 標註列表      │
```

- **Preview 欄**：全頁 PDF；雙指縮放、Pencil 直接書寫；底部頁碼縮圖膠囊。
- **Inspector**：圖層、Pencil 工具盤、標註列表（時間軸排序）。
- **離線狀態**：縮圖四角顯示雲／本機 icon；批量下載按鈕在 List 欄頂部。

#### 5.5 日誌（Daily Log）— 寬螢幕雙視圖

```
Sidebar │ Calendar / Day Picker                   │ Day Editor (今日)
        │ ┌─────────────────────────────┐    │ ┌──────────────────────────┐
        │ │ ◀ 2026 年 4 月 ▶              │    │ │ 4 月 30 日（週四）        │
        │ ├─────────────────────────────┤    │ │ 天氣 ☀ 32°C / 18°C        │
        │ │ 月曆視圖                      │    │ ├──────────────────────────┤
        │ │ 圓點＝有日誌                  │    │ │ ■ 出工人員 (12)           │
        │ │ 橘環＝今日                    │    │ │ ■ 進場材料 (4)            │
        │ ├─────────────────────────────┤    │ │ ■ 施工項目 (PCCES) (7)    │
        │ │ 最近 7 天時間軸                │    │ │ ■ 照片紀錄 (24)           │
        │ │ 4/30 ●  人員 12 / 工項 7      │    │ │ ■ 自由文字                │
        │ │ 4/29 ●  人員 11 / 工項 6      │    │ ├──────────────────────────┤
        │ │ 4/28 ─                        │    │ │ [儲存草稿] [送出]         │
        │ └─────────────────────────────┘    │ └──────────────────────────┘
```

- **Calendar**：仿備忘錄「按月折疊」；月曆與時間軸並列，提供雙視角。
- **Editor**：每個 section 為可摺疊卡片，sticky 副標 + 段內 inline 編輯（不再彈 sheet）。
- **Pencil**：「自由文字」段支援手寫直接轉文字（Scribble）。

---

### 6. 互動規範（Interaction）

#### 6.1 Apple Pencil

| 場景 | 行為 |
|------|------|
| 圖說 PDF | 直接書寫；雙擊筆桿切換橡皮擦；Squeeze 開工具盤。 |
| 簽名欄 | 自動切入 Pencil-only 模式（手掌觸控不留痕）。 |
| 表單文字欄 | Scribble 手寫轉文字；超過 1 行自動展開。 |
| 缺失平面圖 | 點選 → 紅點；按住拖曳 → 拉框框選範圍。 |

#### 6.2 鍵盤快捷鍵（`.keyboardShortcut`）

| 動作 | 快捷鍵 |
|------|-------|
| 切換 Sidebar | ⌘\\ |
| 全域搜尋 | ⌘F |
| 新增（當前模組） | ⌘N |
| 儲存 | ⌘S |
| 送出 | ⌘⏎ |
| 切換模組 1–5 | ⌘1 ~ ⌘5 |
| 開／關 Inspector | ⌘⌥I |

並在 Menu Bar（外接鍵盤連線時下拉的 ⌘ 提示頁）統一以群組顯示，符合 HIG。

#### 6.3 觸控板 / 游標 hover

- **列表列**：hover 時 `surfaceContainer` 浮現、+1pt 微抬升；click 後 `primary` 漸層滑入。
- **CTA 按鈕**：hover scale 1.02、+8% 高光；保留 `pointerStyle(.lift)`。
- **Sidebar 折疊把手**：hover 顯示「⌘\\」提示。

#### 6.4 拖放（M3 之後）

- 缺失：把照片從 Files App 拖入即附加。
- 圖說：把 PDF 拖入 Sidebar 的專案資料夾即上傳。
- 報修：Kanban 卡片可跨欄拖。

#### 6.5 多視窗（Stage Manager / Slide Over）

- 啟用 **Multiple Windows**（`UIApplicationSupportsMultipleScenes = true`，需業務同意）。
- 典型情境：左視窗開圖說，右視窗開查驗單對照填寫。
- 兩視窗共用同一 outbox；衝突時以「最後寫入勝出 + 顯示衝突徽章」處理。

---

### 7. 視覺 Token 在 iPad 的調整

| Token | iPhone | iPad 調整 |
|-------|--------|-----------|
| 圓角 | 12pt | **不變**（仍 12pt continuous） |
| 卡片內距 | 16pt | **20pt**（更大留白，編輯台感） |
| Section 間距 | 24pt | **32pt** |
| 字級 Body | 17pt | **17pt**（不放大，避免「巨型 iPhone」） |
| 字級 Display | 28pt | **34pt**（headline 區） |
| Sidebar 圖示 | n/a | **20pt**，semibold，hierarchical |
| List 列高 | 64pt | **76pt** |
| Detail toolbar 高度 | 44pt | **52pt** |
| 玻璃模糊 | `.thin` | Sidebar `.regular`、Toolbar `.thin`、Sheet `.ultraThin` |

> **絕對守則**：不要在 iPad 把字級整體放大。 iPad「看起來像 iPad」靠的是 **版型**，不是字大。

---

### 8. 無障礙（Accessibility）

- **Dynamic Type**：所有列高用 `.minimumScaleFactor(0.85)` + `lineLimit` 動態計算；Sidebar 在 XXL 字級自動退回單欄全寬。
- **VoiceOver**：Sidebar 為 single rotor；List 欄為 second rotor；Detail 表單欄位完整 trait。
- **對比**：Safety Blue 在 `surface` 上 AA 對比 ≥ 4.5；徽章字白底色 ≥ 3。
- **減少動態效果**：尊重 `Reduce Motion`，三欄切換改用淡入淡出。

---

### 9. 品牌延續清單

| 項目 | 在 iPad 上維持 |
|------|----------------|
| Tactical Architect 色票 | ✅ 完全沿用 |
| 12pt continuous corner | ✅ 全站統一 |
| 無 1px 主分割線 | ✅ 用色階差 |
| Safety Blue 點到為止 | ✅ 僅 CTA / 選取 |
| Space Grotesk 字型 | ✅ Display + Body 均用 |
| Liquid Glass 浮層 | ✅ Sidebar、Toolbar、Inspector 漸進採用 |

---

### 10. 設計交付清單（Deliverables）

- [x] **本規格書**（本文件）
- [x] **互動式設計稿**：`docs/ipados-design-preview.html`
  - 4 種欄位狀態切換（三欄 / 隱藏 Sidebar / 隱藏 List / 僅 Detail）+ Compact 退回
  - Light / Dark 雙主題
  - 5 個模組切換、Inspector 開合、Pencil FAB（圖說）
  - 每欄 toolbar 都採 Liquid Glass capsule 群組設計，每欄都有獨立的展開／收合按鈕
  - 列表選中態為 capsule fill（保留邊距，不貼欄位邊）
  - 鍵盤：`⌘1`~`⌘5` 切模組、`⌘\` 收合 Sidebar、`⌘⌥I` 開合 Inspector
- [ ] Figma 高保真稿（後續，依此規格產出）
- [ ] SwiftUI 適應骨架程式碼骨幹（M1 里程碑後產出）

---

### 11. 與既有報告的銜接

| 文件 | 內容 |
|------|------|
| `docs/ipados-development-report.md` | 工程可行性、Xcode 設定、實施里程碑（M0~M4） |
| `docs/ipados-design-spec.md`（本文件） | 視覺與互動規格、模組版型、Token、Pencil/鍵盤 |
| `docs/ipados-design-preview.html` | 可視原型，三欄／雙欄／單欄 即時切換 |

> 落地建議：**M1 適應性骨架** 先做完，再依本文 §5 各模組逐一 polish；不要五個模組一起翻新，會卡進度。

---

*本文件以 2026-04-30 之 repo 狀態為基底；視覺規範以 `Core/Design/FieldThemePalette.swift` 與 `.cursor/rules/tactical-obsidian-design.mdc` 為唯一真實來源。若衝突以程式碼為準。*
