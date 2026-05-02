//
//  ConstructionDailyLogView.swift
//  constructionApp
//

import SwiftUI
import UIKit

// MARK: - 有未儲存變更時關閉側滑返回（與自訂返回確認一致）

private struct DailyLogEditInteractivePopGate: UIViewControllerRepresentable {
    /// `true` ＝ 允許系統邊緣滑回上一頁。
    var allowsInteractivePop: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        weak var navigationController: UINavigationController?
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        vc.view.isUserInteractionEnabled = false
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            guard let nav = uiViewController.navigationController else { return }
            context.coordinator.navigationController = nav
            nav.interactivePopGestureRecognizer?.isEnabled = allowsInteractivePop
        }
    }

    static func dismantleUIViewController(_ uiViewController: UIViewController, coordinator: Coordinator) {
        DispatchQueue.main.async {
            coordinator.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        }
    }
}

// MARK: - Weather

enum FieldDailyLogWeather: String, CaseIterable {
    case clearSky = "晴"
    case rain = "雨"
    case cloudy = "雲"
}

// MARK: - Calendar helpers

enum FieldDailyLogCalendar {
    static let gregorian: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "zh_Hant_TW")
        c.timeZone = .current
        c.firstWeekday = 1 // 日 — 與常見 iOS 日曆週列一致
        return c
    }()

    static func startOfDay(_ date: Date) -> Date {
        gregorian.startOfDay(for: date)
    }

    static func dayKey(_ date: Date) -> String {
        let y = gregorian.component(.year, from: date)
        let m = gregorian.component(.month, from: date)
        let d = gregorian.component(.day, from: date)
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    static func startOfWeek(containing date: Date) -> Date {
        let sod = startOfDay(date)
        let wd = gregorian.component(.weekday, from: sod)
        let delta = 1 - wd
        return gregorian.date(byAdding: .day, value: delta, to: sod) ?? sod
    }

    static func weekDates(from weekStart: Date) -> [Date] {
        (0 ..< 7).compactMap { gregorian.date(byAdding: .day, value: $0, to: weekStart) }
    }

    static func weekdaySymbolShort(_ date: Date) -> String {
        let idx = gregorian.component(.weekday, from: date) - 1
        let syms = gregorian.shortWeekdaySymbols
        guard syms.indices.contains(idx) else { return "" }
        return syms[idx]
    }
}

// MARK: - Browse (read-only)

struct ConstructionDailyLogView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.fieldTheme) private var theme
    @Environment(SessionManager.self) private var session
    @State private var store = FieldDailyLogLocalStore()
    @State private var centerWeekStart = FieldDailyLogCalendar.startOfWeek(containing: Date())
    @State private var weekCarouselPage = 1
    @State private var selectedDate = FieldDailyLogCalendar.startOfDay(Date())
    @State private var showMonthPicker = false
    @State private var monthPickerDate = Date()
    @State private var fabScrollIdle = true
    @State private var editingDate: Date?

    private var isSelectedDateToday: Bool {
        FieldDailyLogCalendar.dayKey(selectedDate) == FieldDailyLogCalendar.dayKey(Date())
    }

    var body: some View {
        Group {
            if let pid = session.selectedProjectId, session.isAuthenticated {
                logBrowse(projectId: pid)
            } else {
                Text("缺少專案或登入狀態")
                    .font(.subheadline)
                    .foregroundStyle(theme.mutedLabel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(theme.surface)
        .onChange(of: session.selectedProjectId) { _, newId in
            if let id = newId {
                store.activateProject(id)
            }
        }
    }

    @ViewBuilder
    private func logBrowse(projectId: String) -> some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center, spacing: 12) {
                        monthPillButton
                        Spacer(minLength: 8)
                        if !isSelectedDateToday {
                            todayPillButton
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                    weekSwipeStrip
                        .padding(.bottom, 16)

                    selectedDayTitle
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)

                    dayContentSwipePager
                        .padding(.bottom, 24)
                }
            }
            .contentMargins(.bottom, TacticalGlassTheme.tabBarScrollBottomMargin, for: .scrollContent)
            .scrollDismissesKeyboard(.interactively)
            .fieldFABScrollIdleTracking($fabScrollIdle)

            Button {
                editingDate = selectedDate
            } label: {
                ObsidianSquareFAB(systemImage: "square.and.pencil", accessibilityLabel: "編輯日報")
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
            .padding(.bottom, TacticalGlassTheme.fieldFABBottomInset)
            .opacity(fabScrollIdle ? 1 : 0)
            .allowsHitTesting(fabScrollIdle)
            .animation(.easeInOut(duration: 0.2), value: fabScrollIdle)
        }
        .onAppear {
            store.activateProject(projectId)
        }
        .sheet(isPresented: $showMonthPicker) {
            monthPickerSheet
        }
        .navigationDestination(item: $editingDate) { date in
            ConstructionDailyLogEditView(projectId: projectId, date: date, store: store)
        }
    }

    private func jumpToToday() {
        let today = FieldDailyLogCalendar.startOfDay(Date())
        selectedDate = today
        centerWeekStart = FieldDailyLogCalendar.startOfWeek(containing: today)
    }

    // MARK: Month row（月份膠囊 + 今天）

    private var todayPillButton: some View {
        Button {
            jumpToToday()
        } label: {
            Text("今天")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background {
                    Capsule(style: .continuous)
                        .fill(theme.surfaceContainerHighest.opacity(0.72))
                }
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(theme.ghostBorder, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("回到今天")
    }

    private var monthPillButton: some View {
        Button {
            monthPickerDate = selectedDate
            showMonthPicker = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.mutedLabel)
                Text(monthYearLabel(for: selectedDate))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.onSurface)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.mutedLabel.opacity(0.75))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background {
                Capsule(style: .continuous)
                    .fill(theme.surfaceContainerHighest.opacity(0.72))
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(theme.ghostBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("選擇月份或日期")
    }

    private func monthYearLabel(for date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_Hant_TW")
        f.calendar = FieldDailyLogCalendar.gregorian
        f.timeZone = .current
        f.setLocalizedDateFormatFromTemplate("yMMM")
        return f.string(from: date)
    }

    // MARK: Week strip (paged swipe)

    private var weekSwipeStrip: some View {
        TabView(selection: $weekCarouselPage) {
            weekRow(weekStart: weekStart(forCarouselIndex: 0))
                .tag(0)
            weekRow(weekStart: weekStart(forCarouselIndex: 1))
                .tag(1)
            weekRow(weekStart: weekStart(forCarouselIndex: 2))
                .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 86)
        .onChange(of: weekCarouselPage) { _, new in
            if new == 0 {
                bumpWeek(by: -1)
                DispatchQueue.main.async { weekCarouselPage = 1 }
            } else if new == 2 {
                bumpWeek(by: 1)
                DispatchQueue.main.async { weekCarouselPage = 1 }
            }
        }
    }

    private func weekStart(forCarouselIndex index: Int) -> Date {
        let delta = index - 1
        return FieldDailyLogCalendar.gregorian.date(byAdding: .day, value: delta * 7, to: centerWeekStart) ?? centerWeekStart
    }

    private func bumpWeek(by weeks: Int) {
        centerWeekStart =
            FieldDailyLogCalendar.gregorian.date(byAdding: .weekOfYear, value: weeks, to: centerWeekStart) ?? centerWeekStart
        if !weekContains(centerWeekStart, date: selectedDate) {
            if let sameWeekday = alignSameWeekday(in: centerWeekStart, as: selectedDate) {
                selectDate(sameWeekday)
            } else {
                selectDate(centerWeekStart)
            }
        }
    }

    private func weekContains(_ weekStart: Date, date: Date) -> Bool {
        let days = FieldDailyLogCalendar.weekDates(from: weekStart)
        let dk = FieldDailyLogCalendar.dayKey(date)
        return days.contains { FieldDailyLogCalendar.dayKey($0) == dk }
    }

    private func alignSameWeekday(in newWeekStart: Date, as reference: Date) -> Date? {
        let targetWeekday = FieldDailyLogCalendar.gregorian.component(.weekday, from: reference)
        let days = FieldDailyLogCalendar.weekDates(from: newWeekStart)
        return days.first { FieldDailyLogCalendar.gregorian.component(.weekday, from: $0) == targetWeekday }
    }

    private func weekRow(weekStart: Date) -> some View {
        let days = FieldDailyLogCalendar.weekDates(from: weekStart)
        return HStack(spacing: 0) {
            ForEach(days, id: \.timeIntervalSince1970) { day in
                dayCell(day: day)
            }
        }
        .padding(.horizontal, 12)
    }

    private func dayCell(day: Date) -> some View {
        let selected = FieldDailyLogCalendar.dayKey(day) == FieldDailyLogCalendar.dayKey(selectedDate)
        let dayNum = FieldDailyLogCalendar.gregorian.component(.day, from: day)
        let sym = FieldDailyLogCalendar.weekdaySymbolShort(day)

        return Button {
            selectDate(day)
        } label: {
            VStack(spacing: 5) {
                Text(sym)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(selected ? theme.primary : theme.onSurface.opacity(0.5))
                ZStack {
                    if selected {
                        Circle()
                            .fill(theme.primaryGradient())
                            .frame(width: 36, height: 36)
                    }
                    Text("\(dayNum)")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(selected ? theme.onPrimaryGradientForeground : theme.onSurface)
                }
                .frame(height: 36)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(sym) \(dayNum)日")
    }

    // MARK: Selected day title

    private var selectedDayTitle: some View {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_Hant_TW")
        f.calendar = FieldDailyLogCalendar.gregorian
        f.timeZone = .current
        f.dateFormat = "yyyy年M月d日 EEEE"
        return Text(f.string(from: selectedDate))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(theme.onSurface)
            .multilineTextAlignment(.center)
    }

    // MARK: 日內容 — UIPageViewController 連續滑動 ±1 日（與週列同步）

    private var dayContentSwipePager: some View {
        FieldDailyLogDayPagingController(
            selectedDate: $selectedDate,
            centerWeekStart: $centerWeekStart,
            store: store
        )
        .frame(minHeight: 360)
    }

    // MARK: Month sheet

    private var monthPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DatePicker(
                    "",
                    selection: $monthPickerDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .tint(theme.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.surface)
            .navigationTitle("選擇日期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(theme.surfaceContainerLow, for: .navigationBar)
            .toolbarColorScheme(colorScheme, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showMonthPicker = false }
                        .foregroundStyle(theme.primary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        applyPickedDate(monthPickerDate)
                        showMonthPicker = false
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.primary)
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: Navigation / selection

    private func selectDate(_ date: Date) {
        let normalized = FieldDailyLogCalendar.startOfDay(date)
        guard normalized != selectedDate else { return }
        selectedDate = normalized
        centerWeekStart = FieldDailyLogCalendar.startOfWeek(containing: normalized)
    }

    private func applyPickedDate(_ date: Date) {
        let normalized = FieldDailyLogCalendar.startOfDay(date)
        selectedDate = normalized
        centerWeekStart = FieldDailyLogCalendar.startOfWeek(containing: normalized)
    }
}

// MARK: - Edit

struct ConstructionDailyLogEditView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.fieldTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionManager.self) private var session
    let projectId: String
    let date: Date
    @Bindable var store: FieldDailyLogLocalStore

    @State private var weatherSelection: FieldDailyLogWeather?
    @State private var workItems: [FieldDailyLogWorkItem] = []
    @State private var materials: [FieldDailyLogMaterialRow] = []
    @State private var materialPriorsByResourceId: [String: String] = [:]
    @State private var personnelRows: [FieldDailyLogPersonnelEquipmentRow] = []
    @State private var personnelPriorsByResourceId: [String: String] = [:]
    @State private var notesText = ""
    @State private var savePulse = false
    @FocusState private var isNotesFocused: Bool
    @State private var showLeaveWithoutSaveConfirmation = false
    /// 後端載入的完整日誌（供 PATCH 合併未在 App 編輯的欄位）。
    @State private var loadedLog: ConstructionDailyLogDetailDTO?
    /// 最近一次 `defaults` 回應（新建日誌時必填 projectName 等）。
    @State private var formDefaultsSnapshot: ConstructionDailyLogFormDefaultsDTO?
    @State private var saveError: String?
    @State private var isSaving = false

    private var normalizedDate: Date { FieldDailyLogCalendar.startOfDay(date) }
    private var dayKey: String { FieldDailyLogCalendar.dayKey(normalizedDate) }

    /// 編輯既有日誌時帶給工項／材料選擇器與 defaults，排除本筆。
    private var excludeLogIdForApi: String? {
        loadedLog?.id ?? store.day(for: dayKey).remoteLogId
    }

    private var isDirty: Bool {
        store.isDirty(dayKey: dayKey)
    }

    /// 子畫面改選工項時必須寫入 store；僅依賴 `onChange(of: workItems)` 在 Navigation 返回時可能不觸發。
    private var workItemsDraftBinding: Binding<[FieldDailyLogWorkItem]> {
        Binding(
            get: { workItems },
            set: { newValue in
                workItems = newValue
                pushDraft()
            }
        )
    }

    private var materialsDraftBinding: Binding<[FieldDailyLogMaterialRow]> {
        Binding(
            get: { materials },
            set: { newValue in
                materials = newValue
                pushDraft()
            }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(dayTitleString)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.onSurface)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)

                editWeatherSection
                editWorkItemsSection
                editMaterialsSection
                editPersonnelSection
                editNotesSection

                if isDirty {
                    Button {
                        dismissKeyboard()
                        persist()
                    } label: {
                        Text(isSaving ? "同步中…" : "儲存")
                    }
                    .buttonStyle(TacticalPrimaryButtonStyle())
                    .disabled(isSaving)
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .contentMargins(.bottom, TacticalGlassTheme.tabBarScrollBottomMargin + (isDirty ? 8 : 0), for: .scrollContent)
        .scrollDismissesKeyboard(.immediately)
        .background(theme.surface)
        .navigationTitle("編輯日報")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(theme.surfaceContainerLow, for: .navigationBar)
        .toolbarColorScheme(colorScheme, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    attemptLeaveEditor()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                        Text("返回")
                            .font(.body.weight(.medium))
                    }
                    .foregroundStyle(theme.primary)
                }
                .accessibilityLabel("返回上一頁")
            }
        }
        .alert("同步失敗", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("確定", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
        .alert("尚未儲存變更", isPresented: $showLeaveWithoutSaveConfirmation) {
            Button("儲存並離開") {
                dismissKeyboard()
                Task { await saveThenDismiss() }
            }
            Button("捨棄並離開", role: .destructive) {
                store.revertToLastSaved(dayKey: dayKey)
                dismiss()
            }
            Button("繼續編輯", role: .cancel) {}
        } message: {
            Text("您有未同步的編輯內容。建議先按「儲存」同步至伺服器再離開，或選擇捨棄本次變更。")
        }
        .background(DailyLogEditInteractivePopGate(allowsInteractivePop: !isDirty))
        .onAppear {
            store.activateProject(projectId)
        }
        .onChange(of: dayKey) { _, _ in
            syncFromStore()
        }
        /// 初次進入與換日：先拉遠端日誌（若有）→ 再 defaults；從子頁返回不重跑本 task。
        .task(id: dayKey) {
            await MainActor.run {
                store.activateProject(projectId)
                loadedLog = nil
                formDefaultsSnapshot = nil
                syncFromStore()
            }
            await loadRemoteConstructionDailyLog()
            await refreshConstructionDailyLogDefaultsFromAPI()
        }
        .animation(.easeOut(duration: 0.22), value: isDirty)
        .sensoryFeedback(.success, trigger: savePulse)
    }

    private func attemptLeaveEditor() {
        dismissKeyboard()
        if isDirty {
            showLeaveWithoutSaveConfirmation = true
        } else {
            dismiss()
        }
    }

    private var dayTitleString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_Hant_TW")
        f.calendar = FieldDailyLogCalendar.gregorian
        f.timeZone = .current
        f.dateFormat = "yyyy年M月d日 EEEE"
        return f.string(from: normalizedDate)
    }

    private var editWeatherSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("天氣")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(theme.mutedLabel)
                .tracking(1.1)

            HStack(spacing: 10) {
                ForEach(FieldDailyLogWeather.allCases, id: \.self) { w in
                    let on = weatherSelection == w
                    Button {
                        dismissKeyboard()
                        weatherSelection = w
                        pushDraft()
                    } label: {
                        Text(w.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(on ? theme.onPrimary : theme.onSurface)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background {
                                RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                                    .fill(
                                        on
                                            ? AnyShapeStyle(theme.primaryGradient())
                                            : AnyShapeStyle(theme.surfaceContainerHighest.opacity(0.88))
                                    )
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                                    .strokeBorder(theme.ghostBorder, lineWidth: on ? 0 : 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var editWorkItemsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("施工項目")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(theme.mutedLabel)
                .tracking(1.1)

            NavigationLink {
                ConstructionDailyLogPccesWorkItemsPickerView(
                    projectId: projectId,
                    logDate: dayKey,
                    excludeLogId: excludeLogIdForApi,
                    workItems: workItemsDraftBinding
                )
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.primary)
                    Text("選擇工項")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.onSurface)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.mutedLabel.opacity(0.75))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background {
                    RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                        .fill(theme.surfaceContainerHighest.opacity(0.88))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                        .strokeBorder(theme.ghostBorder, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)

            if workItems.isEmpty {
                Text(
                    "尚未加入工項，新增完工項後再回到此處填寫本日完成量。"
                )
                .font(.footnote)
                .foregroundStyle(theme.mutedLabel.opacity(0.85))
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach($workItems) { $item in
                        let unitLabel = item.unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? "—"
                            : item.unit
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .center, spacing: 10) {
                                Text(item.itemNo)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(theme.mutedLabel)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: true, vertical: true)
                                Text(item.workItemName)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(theme.onSurface)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                Text(unitLabel)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(theme.mutedLabel.opacity(0.9))
                                    .multilineTextAlignment(.trailing)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(minWidth: 44, alignment: .trailing)
                                Button {
                                    let rowId = item.id
                                    workItems.removeAll { $0.id == rowId }
                                    pushDraft()
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(theme.statusDanger)
                                        .frame(width: 36, height: 36)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("移除此工項")
                            }
                            Text("本日完成量（\(unitLabel)）")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(theme.mutedLabel)
                            TextField("0", text: $item.dailyQty)
                                .font(.body)
                                .foregroundStyle(theme.onSurface)
                                .keyboardType(.decimalPad)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background {
                                    RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                                        .fill(theme.surfaceContainerLowest.opacity(0.95))
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                                        .strokeBorder(theme.outlineVariant.opacity(0.18), lineWidth: 1)
                                }
                                .onChange(of: item.dailyQty) { _, _ in
                                    pushDraft()
                                }
                        }
                        .padding(12)
                        .background {
                            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                                .fill(theme.surfaceContainerLow.opacity(0.6))
                        }
                        .contextMenu {
                            Button("移除此工項", role: .destructive) {
                                workItems.removeAll { $0.id == item.id }
                                pushDraft()
                            }
                        }
                    }
                }
            }
        }
    }

    private var editMaterialsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("材料")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(theme.mutedLabel)
                .tracking(1.1)

            NavigationLink {
                ConstructionDailyLogMaterialResourcesPickerView(
                    projectId: projectId,
                    logDate: dayKey,
                    excludeLogId: excludeLogIdForApi,
                    materials: materialsDraftBinding
                )
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "cube.box")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.primary)
                    Text("選擇材料")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.onSurface)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.mutedLabel.opacity(0.75))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background {
                    RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                        .fill(theme.surfaceContainerHighest.opacity(0.88))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                        .strokeBorder(theme.ghostBorder, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)

            if materials.isEmpty {
                Text("尚未加入材料。請從資源庫選擇，或點下方新增手填列後在此填寫本日使用量。")
                    .font(.footnote)
                    .foregroundStyle(theme.mutedLabel.opacity(0.85))
                    .padding(.top, 2)
            }

            ForEach(Array(materials.enumerated()), id: \.element.id) { index, row in
                materialRowEditor(index: index, row: row)
            }

            Button {
                dismissKeyboard()
                materials.append(FieldDailyLogMaterialRow.emptyManual())
                pushDraft()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                    Text("新增手填列")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(theme.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background {
                    RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                        .strokeBorder(theme.primary.opacity(0.35), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func materialRowEditor(index: Int, row: FieldDailyLogMaterialRow) -> some View {
        let isResource = row.projectResourceId != nil
        VStack(alignment: .leading, spacing: 10) {
            if isResource {
                HStack(alignment: .top, spacing: 10) {
                    Text("材料")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.mutedLabel)
                        .frame(width: 36, alignment: .leading)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.materialName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : row.materialName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.onSurface)
                        Text("單位：\(row.unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : row.unit)")
                            .font(.caption)
                            .foregroundStyle(theme.mutedLabel)
                    }
                    Spacer(minLength: 0)
                    Button {
                        materials.remove(at: index)
                        pushDraft()
                    } label: {
                        Image(systemName: "trash")
                            .font(.body.weight(.medium))
                            .foregroundStyle(theme.statusDanger)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("移除此列")
                }
            }

            if isResource {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("本日使用")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(theme.mutedLabel)
                        TextField("0", text: materialDailyUsedBinding(index: index))
                            .font(.body)
                            .foregroundStyle(theme.onSurface)
                            .keyboardType(.decimalPad)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background {
                                RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                                    .fill(theme.surfaceContainerLowest.opacity(0.95))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                                    .strokeBorder(theme.outlineVariant.opacity(0.18), lineWidth: 1)
                            }
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("累計使用")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(theme.mutedLabel)
                        Text(materials[index].accumulatedQty)
                            .font(.body.weight(.medium))
                            .foregroundStyle(theme.onSurface)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background {
                                RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                                    .fill(theme.surfaceContainerLow.opacity(0.5))
                            }
                    }
                    .frame(maxWidth: .infinity)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("備註")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(theme.mutedLabel)
                    TextField("選填", text: materialRemarkBinding(index: index))
                        .font(.body)
                        .foregroundStyle(theme.onSurface)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background {
                            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                                .fill(theme.surfaceContainerLowest.opacity(0.95))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                                .strokeBorder(theme.outlineVariant.opacity(0.18), lineWidth: 1)
                        }
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    labeledPersonnelField(title: "材料名稱", text: materialNameBinding(index: index))
                    HStack(spacing: 10) {
                        labeledPersonnelField(title: "單位", text: materialUnitBinding(index: index))
                        labeledPersonnelField(title: "契約數量", text: materialContractQtyBinding(index: index), kind: .decimal)
                    }
                    HStack(spacing: 10) {
                        labeledPersonnelField(title: "本日使用", text: materialDailyUsedBinding(index: index), kind: .decimal)
                        labeledPersonnelField(title: "累計使用", text: materialAccumulatedBinding(index: index), kind: .decimal)
                    }
                    labeledPersonnelField(title: "備註", text: materialRemarkBinding(index: index))
                    Button {
                        materials.remove(at: index)
                        pushDraft()
                    } label: {
                        Label("移除此列", systemImage: "trash")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(theme.statusDanger)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                .fill(theme.surfaceContainerLow.opacity(0.6))
        }
    }

    private func materialNameBinding(index: Int) -> Binding<String> {
        Binding(
            get: { materials[index].materialName },
            set: {
                materials[index].materialName = $0
                pushDraft()
            }
        )
    }

    private func materialUnitBinding(index: Int) -> Binding<String> {
        Binding(
            get: { materials[index].unit },
            set: {
                materials[index].unit = $0
                pushDraft()
            }
        )
    }

    private func materialContractQtyBinding(index: Int) -> Binding<String> {
        Binding(
            get: { materials[index].contractQty },
            set: {
                materials[index].contractQty = $0
                pushDraft()
            }
        )
    }

    private func materialDailyUsedBinding(index: Int) -> Binding<String> {
        Binding(
            get: { materials[index].dailyUsedQty },
            set: {
                materials[index].dailyUsedQty = $0
                recalcMaterialAccumulated(at: index)
                pushDraft()
            }
        )
    }

    private func materialAccumulatedBinding(index: Int) -> Binding<String> {
        Binding(
            get: { materials[index].accumulatedQty },
            set: {
                materials[index].accumulatedQty = $0
                pushDraft()
            }
        )
    }

    private func materialRemarkBinding(index: Int) -> Binding<String> {
        Binding(
            get: { materials[index].remark },
            set: {
                materials[index].remark = $0
                pushDraft()
            }
        )
    }

    private func recalcMaterialAccumulated(at index: Int) {
        guard materials.indices.contains(index) else { return }
        guard let rid = materials[index].projectResourceId, !rid.isEmpty else { return }
        let prior = materialPriorsByResourceId[rid] ?? "0"
        let p = FieldDailyLogPersonnelReconcile.parseDecimalString(prior)
        let d = FieldDailyLogPersonnelReconcile.parseDecimalString(materials[index].dailyUsedQty)
        materials[index].accumulatedQty = FieldDailyLogPersonnelReconcile.formatDecimal(p + d)
    }

    private var editPersonnelSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("人員及機具")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(theme.mutedLabel)
                .tracking(1.1)

            if personnelRows.isEmpty {
                Text("尚無列。請確認已登入且專案資源庫已建人力／機具，或點下方新增手填列。")
                    .font(.footnote)
                    .foregroundStyle(theme.mutedLabel.opacity(0.85))
                    .padding(.top, 2)
            }

            ForEach(Array(personnelRows.enumerated()), id: \.element.id) { index, row in
                personnelRowEditor(index: index, row: row)
            }

            Button {
                dismissKeyboard()
                personnelRows.append(FieldDailyLogPersonnelEquipmentRow.emptyManualRow())
                pushDraft()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                    Text("新增手填列")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(theme.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background {
                    RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                        .strokeBorder(theme.primary.opacity(0.35), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func personnelRowEditor(index: Int, row: FieldDailyLogPersonnelEquipmentRow) -> some View {
        let isBoundResource = row.projectResourceId != nil && row.resourceType != nil
        VStack(alignment: .leading, spacing: 10) {
            if isBoundResource {
                HStack(alignment: .top, spacing: 10) {
                    Text(row.resourceType == "equipment" ? "機具" : "人力")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.mutedLabel)
                        .frame(width: 36, alignment: .leading)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.resourceType == "equipment" ? (row.equipmentName.isEmpty ? "—" : row.equipmentName) : (row.workType.isEmpty ? "—" : row.workType))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.onSurface)
                        Text("單位：\(row.unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : row.unit)")
                            .font(.caption)
                            .foregroundStyle(theme.mutedLabel)
                    }
                    Spacer(minLength: 0)
                }

                if row.resourceType == "labor" {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("本日人數")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(theme.mutedLabel)
                            TextField("0", text: personnelDailyWorkersBinding(index: index))
                                .font(.body)
                                .foregroundStyle(theme.onSurface)
                                .keyboardType(.numberPad)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background {
                                    RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                                        .fill(theme.surfaceContainerLowest.opacity(0.95))
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                                        .strokeBorder(theme.outlineVariant.opacity(0.18), lineWidth: 1)
                                }
                        }
                        .frame(maxWidth: .infinity)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("累計")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(theme.mutedLabel)
                            Text(personnelRows[index].accumulatedWorkers)
                                .font(.body.weight(.medium))
                                .foregroundStyle(theme.onSurface)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background {
                                    RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                                        .fill(theme.surfaceContainerLow.opacity(0.5))
                                }
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("本日數量")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(theme.mutedLabel)
                            TextField("0", text: personnelDailyEquipmentBinding(index: index))
                                .font(.body)
                                .foregroundStyle(theme.onSurface)
                                .keyboardType(.decimalPad)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background {
                                    RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                                        .fill(theme.surfaceContainerLowest.opacity(0.95))
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                                        .strokeBorder(theme.outlineVariant.opacity(0.18), lineWidth: 1)
                                }
                        }
                        .frame(maxWidth: .infinity)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("累計")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(theme.mutedLabel)
                            Text(personnelRows[index].accumulatedEquipmentQty)
                                .font(.body.weight(.medium))
                                .foregroundStyle(theme.onSurface)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background {
                                    RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                                        .fill(theme.surfaceContainerLow.opacity(0.5))
                                }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    labeledPersonnelField(title: "工別", text: personnelWorkTypeBinding(index: index))
                    HStack(spacing: 10) {
                        labeledPersonnelField(title: "本日人數", text: personnelDailyWorkersBinding(index: index), kind: .int)
                        labeledPersonnelField(title: "累計人數", text: personnelAccumulatedWorkersBinding(index: index), kind: .int)
                    }
                    labeledPersonnelField(title: "機具名稱", text: personnelEquipmentNameBinding(index: index))
                    HStack(spacing: 10) {
                        labeledPersonnelField(title: "本日機具量", text: personnelDailyEquipmentBinding(index: index), kind: .decimal)
                        labeledPersonnelField(title: "累計機具量", text: personnelAccumulatedEquipmentBinding(index: index), kind: .decimal)
                    }
                    Button {
                        personnelRows.remove(at: index)
                        pushDraft()
                    } label: {
                        Label("移除此列", systemImage: "trash")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(theme.statusDanger)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                .fill(theme.surfaceContainerLow.opacity(0.6))
        }
    }

    private enum PersonnelFieldKeyboardKind {
        case text
        case int
        case decimal
    }

    @ViewBuilder
    private func labeledPersonnelField(
        title: String,
        text: Binding<String>,
        kind: PersonnelFieldKeyboardKind = .text
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(theme.mutedLabel)
            switch kind {
            case .text:
                TextField("—", text: text)
                    .font(.body)
                    .foregroundStyle(theme.onSurface)
                    .keyboardType(.default)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background {
                        RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                            .fill(theme.surfaceContainerLowest.opacity(0.95))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                            .strokeBorder(theme.outlineVariant.opacity(0.18), lineWidth: 1)
                    }
            case .int:
                TextField("—", text: text)
                    .font(.body)
                    .foregroundStyle(theme.onSurface)
                    .keyboardType(.numberPad)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background {
                        RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                            .fill(theme.surfaceContainerLowest.opacity(0.95))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                            .strokeBorder(theme.outlineVariant.opacity(0.18), lineWidth: 1)
                    }
            case .decimal:
                TextField("—", text: text)
                    .font(.body)
                    .foregroundStyle(theme.onSurface)
                    .keyboardType(.decimalPad)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background {
                        RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                            .fill(theme.surfaceContainerLowest.opacity(0.95))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                            .strokeBorder(theme.outlineVariant.opacity(0.18), lineWidth: 1)
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func personnelWorkTypeBinding(index: Int) -> Binding<String> {
        Binding(
            get: { personnelRows[index].workType },
            set: {
                personnelRows[index].workType = $0
                pushDraft()
            }
        )
    }

    private func personnelDailyWorkersBinding(index: Int) -> Binding<String> {
        Binding(
            get: { personnelRows[index].dailyWorkers },
            set: {
                personnelRows[index].dailyWorkers = $0
                recalcPersonnelAccumulated(at: index)
                pushDraft()
            }
        )
    }

    private func personnelAccumulatedWorkersBinding(index: Int) -> Binding<String> {
        Binding(
            get: { personnelRows[index].accumulatedWorkers },
            set: {
                personnelRows[index].accumulatedWorkers = $0
                pushDraft()
            }
        )
    }

    private func personnelEquipmentNameBinding(index: Int) -> Binding<String> {
        Binding(
            get: { personnelRows[index].equipmentName },
            set: {
                personnelRows[index].equipmentName = $0
                pushDraft()
            }
        )
    }

    private func personnelDailyEquipmentBinding(index: Int) -> Binding<String> {
        Binding(
            get: { personnelRows[index].dailyEquipmentQty },
            set: {
                personnelRows[index].dailyEquipmentQty = $0
                recalcPersonnelAccumulated(at: index)
                pushDraft()
            }
        )
    }

    private func personnelAccumulatedEquipmentBinding(index: Int) -> Binding<String> {
        Binding(
            get: { personnelRows[index].accumulatedEquipmentQty },
            set: {
                personnelRows[index].accumulatedEquipmentQty = $0
                pushDraft()
            }
        )
    }

    private func recalcPersonnelAccumulated(at index: Int) {
        guard personnelRows.indices.contains(index) else { return }
        let row = personnelRows[index]
        guard let rid = row.projectResourceId, let rt = row.resourceType, !rid.isEmpty else { return }
        let prior = personnelPriorsByResourceId[rid] ?? "0"
        if rt == "labor" {
            let p = FieldDailyLogPersonnelReconcile.parseIntString(prior)
            let d = FieldDailyLogPersonnelReconcile.parseIntString(row.dailyWorkers)
            personnelRows[index].accumulatedWorkers = String(p + d)
        } else {
            let p = FieldDailyLogPersonnelReconcile.parseDecimalString(prior)
            let d = FieldDailyLogPersonnelReconcile.parseDecimalString(row.dailyEquipmentQty)
            personnelRows[index].accumulatedEquipmentQty = FieldDailyLogPersonnelReconcile.formatDecimal(p + d)
        }
    }

    private func refreshConstructionDailyLogDefaultsFromAPI() async {
        guard session.isAuthenticated else { return }
        let exclude = await MainActor.run { excludeLogIdForApi }
        do {
            let defs = try await session.withValidAccessToken { token in
                try await APIService.fetchConstructionDailyLogFormDefaults(
                    baseURL: AppConfiguration.apiRootURL,
                    token: token,
                    projectId: projectId,
                    logDate: dayKey,
                    excludeLogId: exclude
                )
            }
            await MainActor.run {
                formDefaultsSnapshot = defs
                personnelPriorsByResourceId = defs.personnelResourcePriors
                personnelRows = FieldDailyLogPersonnelReconcile.reconcile(
                    resources: defs.personnelResources,
                    saved: personnelRows,
                    priors: defs.personnelResourcePriors
                )
                materialPriorsByResourceId = defs.materialResourcePriors
                var nextMaterials = FieldDailyLogMaterialReconcile.mergeSaved(
                    resources: defs.materialResources,
                    saved: materials,
                    priors: defs.materialResourcePriors
                )
                FieldDailyLogMaterialReconcile.recalcAccumulatedFromPriors(
                    &nextMaterials,
                    priors: defs.materialResourcePriors
                )
                materials = nextMaterials
                pushDraft()
            }
        } catch {
            // 離線或權限失敗時保留本地草稿列，不阻擋編輯。
        }
    }

    private var editNotesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("重要事項")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(theme.mutedLabel)
                .tracking(1.1)

            ZStack(alignment: .topLeading) {
                if notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("記錄當日重點…")
                        .font(.body)
                        .foregroundStyle(theme.mutedLabel.opacity(0.55))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $notesText)
                    .font(.body)
                    .foregroundStyle(theme.onSurface)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 200)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .focused($isNotesFocused)
                    .onChange(of: notesText) { _, _ in
                        pushDraft()
                    }
            }
            .background {
                RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                    .fill(theme.surfaceContainerLowest.opacity(0.95))
            }
            .overlay {
                RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                    .strokeBorder(theme.outlineVariant.opacity(0.18), lineWidth: 1)
            }
        }
    }

    private func syncFromStore() {
        let persisted = store.day(for: dayKey)
        if let raw = persisted.weatherRaw, let w = FieldDailyLogWeather(rawValue: raw) {
            weatherSelection = w
        } else {
            weatherSelection = nil
        }
        notesText = persisted.notes
        workItems = persisted.workItems
        materials = persisted.materials
        personnelRows = persisted.personnelRows
    }

    private func persistedFromUI() -> FieldDailyLogPersistedDay {
        FieldDailyLogPersistedDay(
            weatherRaw: weatherSelection?.rawValue,
            notes: notesText,
            workItems: workItems,
            materials: materials,
            personnelRows: personnelRows,
            remoteLogId: loadedLog?.id ?? store.day(for: dayKey).remoteLogId
        )
    }

    private func pushDraft() {
        store.setDay(dayKey, value: persistedFromUI())
    }

    private func persist() {
        store.activateProject(projectId)
        dismissKeyboard()
        if !session.isAuthenticated {
            pushDraft()
            store.save(dayKey: dayKey)
            savePulse.toggle()
            return
        }
        guard formDefaultsSnapshot != nil else {
            saveError = "無法同步伺服器：尚未載入表單預設，請確認網路後再試。"
            return
        }
        Task { @MainActor in
            await runServerPersist { savePulse.toggle() }
        }
    }

    @MainActor
    private func saveThenDismiss() async {
        saveError = nil
        store.activateProject(projectId)
        if session.isAuthenticated, formDefaultsSnapshot != nil {
            await runServerPersist {}
        } else {
            pushDraft()
            store.save(dayKey: dayKey)
            savePulse.toggle()
        }
        if saveError == nil {
            dismiss()
        }
    }

    @MainActor
    private func runServerPersist(_ afterSuccess: @escaping () -> Void) async {
        isSaving = true
        defer { isSaving = false }
        guard let defs = formDefaultsSnapshot else {
            saveError = "無法同步伺服器：尚未載入表單預設，請確認網路後再試。"
            return
        }
        pushDraft()
        let logIdForUpsert = loadedLog?.id ?? store.day(for: dayKey).remoteLogId
        do {
            let body = buildUpsertBody(defaults: defs)
            let dto: ConstructionDailyLogDetailDTO = try await session.withValidAccessToken { token in
                if let rid = logIdForUpsert {
                    return try await APIService.updateConstructionDailyLog(
                        baseURL: AppConfiguration.apiRootURL,
                        token: token,
                        projectId: projectId,
                        logId: rid,
                        body: body
                    )
                }
                return try await APIService.createConstructionDailyLog(
                    baseURL: AppConfiguration.apiRootURL,
                    token: token,
                    projectId: projectId,
                    body: body
                )
            }
            applyServerDto(dto)
            afterSuccess()
        } catch let e as APIRequestError {
            saveError = e.localizedDescription
        } catch is FieldSessionAuthError {
            saveError = "登入已過期，請重新登入。"
        } catch {
            saveError = "同步失敗，請稍後再試。"
        }
    }

    private func loadRemoteConstructionDailyLog() async {
        guard session.isAuthenticated else { return }
        do {
            let logId = try await session.withValidAccessToken { token in
                try await APIService.findConstructionDailyLogId(
                    baseURL: AppConfiguration.apiRootURL,
                    token: token,
                    projectId: projectId,
                    logDateYMD: dayKey
                )
            }
            guard let logId else { return }
            let dto = try await session.withValidAccessToken { token in
                try await APIService.getConstructionDailyLog(
                    baseURL: AppConfiguration.apiRootURL,
                    token: token,
                    projectId: projectId,
                    logId: logId
                )
            }
            await MainActor.run {
                applyServerDto(dto)
            }
        } catch {
            // 離線或尚無遠端日誌：沿用本地草稿
        }
    }

    private func applyServerDto(_ d: ConstructionDailyLogDetailDTO) {
        loadedLog = d
        let am = d.weatherAm?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        weatherSelection = FieldDailyLogWeather(rawValue: am)
        notesText = d.importantNotes
        workItems = d.workItems.map { FieldDailyLogWorkItem.fromServer($0) }
        materials = d.materials.map { FieldDailyLogMaterialRow.fromServer($0) }
        personnelRows = d.personnelEquipmentRows.map { FieldDailyLogPersonnelEquipmentRow.fromServer($0) }
        pushDraft()
        store.save(dayKey: dayKey)
    }

    private func buildUpsertBody(defaults: ConstructionDailyLogFormDefaultsDTO) -> ConstructionDailyLogUpsertBody {
        let b = loadedLog
        let pn = nonEmptyOrPlaceholder(b?.projectName ?? defaults.projectName, placeholder: "（未填專案名稱）")
        let cn = nonEmptyOrPlaceholder(b?.contractorName ?? defaults.contractorName, placeholder: "（未填廠商名稱）")

        let weatherAm = weatherSelection.map(\.rawValue)

        let workPayload: [ConstructionDailyLogUpsertWorkItem] = workItems
            .filter { !$0.workItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { w in
                let up = w.unitPrice?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let acc = w.accumulatedQty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "0"
                    : w.accumulatedQty.trimmingCharacters(in: .whitespacesAndNewlines)
                return ConstructionDailyLogUpsertWorkItem(
                    pccesItemId: w.pccesItemId,
                    unitPrice: up.isEmpty ? nil : up,
                    workItemName: w.workItemName.trimmingCharacters(in: .whitespacesAndNewlines),
                    unit: w.unit.trimmingCharacters(in: .whitespacesAndNewlines),
                    contractQty: w.contractQty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "0"
                        : w.contractQty.trimmingCharacters(in: .whitespacesAndNewlines),
                    dailyQty: w.dailyQty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "0"
                        : w.dailyQty.trimmingCharacters(in: .whitespacesAndNewlines),
                    accumulatedQty: acc,
                    remark: w.remark
                )
            }

        let mats: [ConstructionDailyLogUpsertMaterial] = materials
            .filter { m in
                if m.projectResourceId != nil { return true }
                return !m.materialName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            .map { m in
                let hasRes = m.projectResourceId != nil
                let cq = m.contractQty.trimmingCharacters(in: .whitespacesAndNewlines)
                return ConstructionDailyLogUpsertMaterial(
                    projectResourceId: m.projectResourceId,
                    materialName: m.materialName.trimmingCharacters(in: .whitespacesAndNewlines),
                    unit: m.unit.trimmingCharacters(in: .whitespacesAndNewlines),
                    contractQty: hasRes ? "0" : (cq.isEmpty ? "0" : cq),
                    dailyUsedQty: m.dailyUsedQty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "0"
                        : m.dailyUsedQty.trimmingCharacters(in: .whitespacesAndNewlines),
                    accumulatedQty: m.accumulatedQty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "0"
                        : m.accumulatedQty.trimmingCharacters(in: .whitespacesAndNewlines),
                    remark: m.remark
                )
            }

        let pe: [ConstructionDailyLogUpsertPersonnel] = personnelRows
            .filter { p in
                if p.projectResourceId != nil { return true }
                let wt = p.workType.trimmingCharacters(in: .whitespacesAndNewlines)
                let en = p.equipmentName.trimmingCharacters(in: .whitespacesAndNewlines)
                let dw = Int(p.dailyWorkers) ?? 0
                let aw = Int(p.accumulatedWorkers) ?? 0
                let dq = FieldDailyLogPersonnelReconcile.parseDecimalString(p.dailyEquipmentQty)
                let aq = FieldDailyLogPersonnelReconcile.parseDecimalString(p.accumulatedEquipmentQty)
                return !wt.isEmpty || !en.isEmpty || dw > 0 || aw > 0 || dq > 0 || aq > 0
            }
            .map { p in
                ConstructionDailyLogUpsertPersonnel(
                    projectResourceId: p.projectResourceId,
                    workType: p.workType.trimmingCharacters(in: .whitespacesAndNewlines),
                    dailyWorkers: max(0, Int(p.dailyWorkers) ?? 0),
                    accumulatedWorkers: max(0, Int(p.accumulatedWorkers) ?? 0),
                    equipmentName: p.equipmentName.trimmingCharacters(in: .whitespacesAndNewlines),
                    dailyEquipmentQty: p.dailyEquipmentQty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "0"
                        : p.dailyEquipmentQty.trimmingCharacters(in: .whitespacesAndNewlines),
                    accumulatedEquipmentQty: p.accumulatedEquipmentQty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "0"
                        : p.accumulatedEquipmentQty.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }

        let nwi: String = {
            guard let v = b?.newWorkerInsurance else { return "no_new" }
            if v == "yes" || v == "no" { return v }
            return "no_new"
        }()

        return ConstructionDailyLogUpsertBody(
            reportNo: trimmedOptional(b?.reportNo),
            weatherAm: weatherAm,
            weatherPm: trimmedOptional(b?.weatherPm),
            logDate: dayKey,
            projectName: pn,
            contractorName: cn,
            approvedDurationDays: b?.approvedDurationDays ?? defaults.approvedDurationDays,
            accumulatedDays: b?.accumulatedDays,
            remainingDays: b?.remainingDays,
            extendedDays: b?.extendedDays,
            startDate: b?.startDate ?? defaults.startDate,
            completionDate: trimmedOptional(b?.completionDate),
            actualProgress: parseActualProgressDouble(b?.actualProgress),
            specialItemA: b?.specialItemA ?? "",
            specialItemB: b?.specialItemB ?? "",
            hasTechnician: b?.hasTechnician ?? false,
            preWorkEducation: (b?.preWorkEducation == "yes") ? "yes" : "no",
            newWorkerInsurance: nwi,
            ppeCheck: (b?.ppeCheck == "yes") ? "yes" : "no",
            otherSafetyNotes: b?.otherSafetyNotes ?? "",
            sampleTestRecord: b?.sampleTestRecord ?? "",
            subcontractorNotice: b?.subcontractorNotice ?? "",
            importantNotes: notesText,
            siteManagerSigned: b?.siteManagerSigned ?? false,
            workItems: workPayload,
            materials: mats,
            personnelEquipmentRows: pe
        )
    }

    private func nonEmptyOrPlaceholder(_ s: String, placeholder: String) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? placeholder : t
    }

    private func trimmedOptional(_ s: String?) -> String? {
        guard let s else { return nil }
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private func parseActualProgressDouble(_ s: String?) -> Double? {
        guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        return Double(s.replacingOccurrences(of: ",", with: ""))
    }

    /// 收鍵盤：SwiftUI 焦點 + 確保 UITextView（TextEditor）一併 resign。
    private func dismissKeyboard() {
        isNotesFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
