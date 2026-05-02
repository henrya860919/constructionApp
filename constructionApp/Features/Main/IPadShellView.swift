//
//  IPadShellView.swift
//  constructionApp
//
//  iPad regular size class 專用 Shell：**正規三欄 NavigationSplitView**。
//
//  HIG 規範對齊（iPad 備忘錄 / Mail / Files）：
//  - 三欄初始化 `NavigationSplitView { sidebar } content: { } detail: { }`：每欄結構性存在，系統自動處理欄位寬度、可拖動分隔、欄位 visibility 切換。
//  - 系統會在 content / detail 的 navigation bar leading **自動**提供 sidebar / content toggle 按鈕（icon: `sidebar.left`），不需自繪。
//  - 每欄各自包獨立 `NavigationStack`，內部 push 子層級不互相干擾。
//
//  iPhone（compact）由 MainShellCompactView 走 FloatingTabBar，本檔不會被使用，兩條路徑完全獨立。
//
//  各模組 master-detail 改造進度：
//  - ✅ 缺失：DefectListView (content) ↔ DefectDetailView (detail)，靠 selectedDefectId 雙向綁定
//  - ⏳ 查驗 / 報修 / 圖說 / 日誌：尚未拆 list/detail，content 欄暫放整個模組 home view（內部仍用 push detail），detail 欄顯示通用空狀態 placeholder。後續逐個改造。
//

import SwiftUI

struct IPadShellView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.fieldTheme) private var theme
    @Environment(SessionManager.self) private var session

    @Binding var selection: FieldModuleTab

    @State private var splitVisibility: NavigationSplitViewVisibility = .all
    @State private var settingsPresented: Bool = false

    /// 各模組 detail 欄當前選取的 id；切換模組時統一在 onChange(of: selection) 清掉。
    @State private var selectedDefectId: String?
    @State private var selectedRepairId: String?

    /// 缺失模組 list view 共用 viewModel 與 FAB 狀態，避免每次重繪重置。
    @State private var defectListModel = DefectListViewModel()
    @State private var defectFABScrollIdle: Bool = true

    /// 報修模組 list view 共用 viewModel 與 FAB 狀態。
    @State private var repairListModel = RepairListViewModel()
    @State private var repairFABScrollIdle: Bool = true

    /// 圖說管理 model 與 selection（reference 物件透過 view init 一路傳給所有 drill-down 層級，跨 navigation push 邊界保持指向同一物件）。
    @State private var drawingTreeVM = DrawingTreeViewModel()
    @State private var drawingSelection = DrawingIPadSelection()

    /// 日誌 store 與當前選中日期；中欄／右欄共享。
    @State private var dailyLogStore = FieldDailyLogLocalStore()
    @State private var dailyLogSelectedDate: Date = FieldDailyLogCalendar.startOfDay(Date())

    /// detail 欄頂部搜尋框內容（備忘錄式：寬度夠時為輸入框、否則收成 magnifyingglass icon button）。
    @State private var detailSearchText: String = ""

    var body: some View {
        NavigationSplitView(columnVisibility: $splitVisibility) {
            sidebar
        } content: {
            contentColumn
        } detail: {
            detailColumn
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $settingsPresented) {
            NavigationStack {
                FieldSettingsView()
            }
            .tint(theme.primary)
        }
        .onChange(of: selection) { _, _ in
            /// 切換模組時清掉所有 detail selection，避免跨模組殘留。
            selectedDefectId = nil
            selectedRepairId = nil
            drawingSelection.reset()
        }
    }

    // MARK: - Sidebar (左欄)

    private var sidebar: some View {
        IPadSidebarView(
            selection: $selection,
            onOpenSettings: { settingsPresented = true },
            onSwitchProject: { session.clearProjectSelection() },
            onCollapseSidebar: {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                    splitVisibility = .doubleColumn
                }
            }
        )
        .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
    }

    // MARK: - Content (中欄)

    @ViewBuilder
    private var contentColumn: some View {
        NavigationStack {
            VStack(spacing: 0) {
                /// 自製 list 欄頂部 toolbar 條：含 sidebar toggle 按鈕（與備忘錄圖 16 一致的位置與行為）。藏掉系統 nav bar 後自繪這條，避免 SwiftUI 對 NavigationSplitView 自動 toggle 的不穩定行為，且只會有一顆按鈕、不會 overlay 蓋到 list 內容。
                contentColumnToolbar

                Group {
                    if let pid = session.selectedProjectId, session.isAuthenticated {
                        moduleContentView(for: selection, projectId: pid)
                    } else {
                        Text("缺少專案或登入狀態")
                            .foregroundStyle(theme.mutedLabel)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            /// list 欄背景與 sidebar 同色（surface），視覺一體；toggle 由 sidebar 內 trailing / list 欄 leading 動態切換位置，不需要靠顏色區隔欄位。
            .background(theme.surface)
            .toolbar(.hidden, for: .navigationBar)
        }
        .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 380)
    }

    /// list 欄頂部 toolbar 條：toggle 只在 sidebar 收合（.doubleColumn）時顯示為「展開 sidebar」按鈕。Sidebar 顯示時 toggle 在 sidebar 內 trailing（IPadSidebarView 處理），這裡不重複顯示。
    private var contentColumnToolbar: some View {
        HStack(spacing: 8) {
            if splitVisibility == .doubleColumn {
                Button {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                        splitVisibility = .all
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(theme.onSurface)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("展開側欄")
                .keyboardShortcut("\\", modifiers: .command)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .frame(minHeight: 48)
    }

    @ViewBuilder
    private func moduleContentView(for module: FieldModuleTab, projectId: String) -> some View {
        switch module {
        case .deficiency:
            DefectListView(
                projectId: projectId,
                model: defectListModel,
                fabScrollIdle: $defectFABScrollIdle,
                onSelectDefect: { id in
                    selectedDefectId = id
                },
                selectedDefectId: selectedDefectId
            )
        case .repair:
            RepairRequestsListView(
                projectId: projectId,
                model: repairListModel,
                fabScrollIdle: $repairFABScrollIdle,
                onSelectRepair: { id in
                    selectedRepairId = id
                },
                selectedRepairId: selectedRepairId
            )
        case .selfInspection:
            SelfInspectionHomeView()
        case .drawingManagement:
            /// iPad 專用 drill-down 瀏覽器（與 iPhone 同樣 NavigationLink push pattern），但點檔案後寫入 reference selection 物件而非開全螢幕，由 detail 欄 observe 顯示。
            DrawingIPadFolderView(
                projectId: projectId,
                nodes: drawingTreeVM.tree,
                vm: drawingTreeVM,
                selection: drawingSelection,
                isRoot: true
            )
            .task {
                if drawingTreeVM.tree.isEmpty {
                    await drawingTreeVM.load(projectId: projectId, session: session)
                }
            }
        case .dailyLog:
            DailyLogIPadBrowserView(
                projectId: projectId,
                store: dailyLogStore,
                selectedDate: $dailyLogSelectedDate
            )
        }
    }

    // MARK: - Detail (右欄)

    @ViewBuilder
    private var detailColumn: some View {
        NavigationStack {
            Group {
                if session.selectedProjectId != nil, session.isAuthenticated {
                    moduleDetailView(for: selection)
                } else {
                    detailPlaceholder("尚未進入工作區")
                }
            }
            .background(theme.surface)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    fullScreenToggleButton
                }
            }
            .searchable(text: $detailSearchText, placement: .toolbar, prompt: "搜尋")
            /// 全螢幕（.detailOnly）時藏整條 nav bar：避免系統在 .detailOnly 強制加的 sidebar toggle 與自繪的 fullScreenToggleButton 並列（API .toolbar(removing:) 在此狀態無效）。回到三欄／雙欄 nav bar 自動恢復。
            .toolbar(splitVisibility == .detailOnly ? .hidden : .visible, for: .navigationBar)
            .overlay(alignment: .topLeading) {
                /// 全螢幕時 nav bar 已藏，浮動「縮回三欄」按鈕補償回到 .all 的入口。
                if splitVisibility == .detailOnly {
                    floatingCollapseButton
                        .padding(.leading, 16)
                        .padding(.top, 6)
                }
            }
        }
    }

    /// 全螢幕時的浮動縮回按鈕，對齊系統 NavigationSplitView toggle 視覺：
    /// - 44×44 圓形（與系統 toggle 同尺寸）
    /// - 白底（surfaceContainerLowest 在 light=#FFF / dark=#151B24，自動切換）
    /// - icon 用 theme.primary 主色（與系統 toggle 的 tint 一致）
    /// - 較強陰影（系統 toggle 也有明顯浮起效果）
    private var floatingCollapseButton: some View {
        Button {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                splitVisibility = .all
            }
        } label: {
            Image(systemName: "arrow.down.right.and.arrow.up.left")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.primary)
                .frame(width: 44, height: 44)
                .background {
                    Circle()
                        .fill(theme.surfaceContainerLowest)
                }
                .shadow(color: .black.opacity(0.16), radius: 10, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("回到三欄")
        .keyboardShortcut("\\", modifiers: [.command, .option])
    }

    private var fullScreenToggleButton: some View {
        Button {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                splitVisibility = (splitVisibility == .detailOnly) ? .all : .detailOnly
            }
        } label: {
            Image(systemName: splitVisibility == .detailOnly
                  ? "arrow.down.right.and.arrow.up.left"
                  : "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 14, weight: .semibold))
        }
        .accessibilityLabel(splitVisibility == .detailOnly ? "回到列表" : "全螢幕展開")
    }

    @ViewBuilder
    private func moduleDetailView(for module: FieldModuleTab) -> some View {
        switch module {
        case .deficiency:
            if let id = selectedDefectId, let pid = session.selectedProjectId {
                DefectDetailView(
                    projectId: pid,
                    defectId: id,
                    accessToken: session.accessToken ?? "",
                    ipadEmbedded: true
                )
                .id(id)
            } else {
                detailPlaceholder("從中欄選擇一筆缺失紀錄")
            }
        case .repair:
            if let id = selectedRepairId, let pid = session.selectedProjectId {
                RepairRequestDetailView(
                    projectId: pid,
                    repairId: id,
                    accessToken: session.accessToken ?? "",
                    ipadEmbedded: true
                )
                .id(id)
            } else {
                detailPlaceholder("從中欄選擇一筆報修紀錄")
            }
        case .drawingManagement:
            if let url = drawingSelection.url {
                FieldQuickLookPreviewEmbedded(fileURL: url, title: drawingSelection.title)
                    .id(url)
            } else {
                detailPlaceholder("從中欄選擇圖說檔案以預覽")
            }
        case .dailyLog:
            if let pid = session.selectedProjectId {
                DailyLogIPadDayDetailView(
                    projectId: pid,
                    date: dailyLogSelectedDate,
                    store: dailyLogStore
                )
                .id(FieldDailyLogCalendar.dayKey(dailyLogSelectedDate))
            } else {
                detailPlaceholder("尚未選擇專案")
            }
        default:
            detailPlaceholder("此模組三欄式即將支援")
        }
    }

    private func detailPlaceholder(_ title: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(theme.mutedLabel.opacity(0.6))
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(theme.onSurface)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.surface)
    }
}
