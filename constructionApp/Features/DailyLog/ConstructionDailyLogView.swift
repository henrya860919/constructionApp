//
//  ConstructionDailyLogView.swift
//  constructionApp
//

import SwiftUI
import UIKit

// MARK: - Weather

enum FieldDailyLogWeather: String, CaseIterable {
    case clearSky = "晴"
    case rain = "雨"
    case cloudy = "雲"
}

// MARK: - Calendar helpers

private enum FieldDailyLogCalendar {
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
    let projectId: String
    let date: Date
    @Bindable var store: FieldDailyLogLocalStore

    @State private var weatherSelection: FieldDailyLogWeather?
    @State private var notesText = ""
    @State private var savePulse = false
    @FocusState private var isNotesFocused: Bool

    private var normalizedDate: Date { FieldDailyLogCalendar.startOfDay(date) }
    private var dayKey: String { FieldDailyLogCalendar.dayKey(normalizedDate) }

    private var isDirty: Bool {
        store.isDirty(dayKey: dayKey)
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
                editNotesSection

                if isDirty {
                    Button {
                        dismissKeyboard()
                        persist()
                    } label: {
                        Text("儲存")
                    }
                    .buttonStyle(TacticalPrimaryButtonStyle())
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
        .toolbarBackground(theme.surfaceContainerLow, for: .navigationBar)
        .toolbarColorScheme(colorScheme, for: .navigationBar)
        .onAppear {
            store.activateProject(projectId)
            syncFromStore()
        }
        .animation(.easeOut(duration: 0.22), value: isDirty)
        .sensoryFeedback(.success, trigger: savePulse)
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
    }

    private func persistedFromUI() -> FieldDailyLogPersistedDay {
        FieldDailyLogPersistedDay(weatherRaw: weatherSelection?.rawValue, notes: notesText)
    }

    private func pushDraft() {
        store.setDay(dayKey, value: persistedFromUI())
    }

    private func persist() {
        store.activateProject(projectId)
        pushDraft()
        store.save(dayKey: dayKey)
        savePulse.toggle()
    }

    /// 收鍵盤：SwiftUI 焦點 + 確保 UITextView（TextEditor）一併 resign。
    private func dismissKeyboard() {
        isNotesFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
