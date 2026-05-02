//
//  DailyLogIPadBrowserView.swift
//  constructionApp
//
//  iPad 三欄式日誌中欄：月曆 + 下拉式最近 7 天時間軸（含「已填／未填」標注）。
//  選中日期透過 `@Binding selectedDate` 與 IPadShellView 雙向綁定，detail 欄即時切換到該日內容。
//
//  iPhone 路徑（ConstructionDailyLogView）完全不動。共享 model：FieldDailyLogLocalStore、FieldDailyLogCalendar、FieldDailyLogPersistedDay。
//

import SwiftUI

struct DailyLogIPadBrowserView: View {
    let projectId: String
    @Bindable var store: FieldDailyLogLocalStore
    @Binding var selectedDate: Date

    @Environment(\.fieldTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    @State private var recentExpanded: Bool = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ObsidianModuleHeaderView(title: "施工日誌")
                    .padding(.top, 8)

                calendarBlock

                recentDaysBlock

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(theme.surface)
        .onAppear {
            store.activateProject(projectId)
        }
    }

    // MARK: - Calendar block

    private var calendarBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            DatePicker(
                "",
                selection: Binding(
                    get: { selectedDate },
                    set: { selectedDate = FieldDailyLogCalendar.startOfDay($0) }
                ),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .tint(theme.primary)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                .fill(theme.surfaceContainer)
        }
    }

    // MARK: - Recent 7 days

    private var recent7Days: [Date] {
        let cal = FieldDailyLogCalendar.gregorian
        let today = FieldDailyLogCalendar.startOfDay(Date())
        return (0..<7).compactMap { offset in
            cal.date(byAdding: .day, value: -offset, to: today)
        }
    }

    private var recentDaysBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    recentExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Text("最近 7 天")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.onSurface)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.mutedLabel)
                        .rotationEffect(.degrees(recentExpanded ? 0 : -90))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if recentExpanded {
                VStack(spacing: 4) {
                    ForEach(recent7Days, id: \.timeIntervalSince1970) { day in
                        recentDayRow(day)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 6)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                .fill(theme.surfaceContainer)
        }
    }

    private func recentDayRow(_ day: Date) -> some View {
        let isSelected = FieldDailyLogCalendar.dayKey(day) == FieldDailyLogCalendar.dayKey(selectedDate)
        let hasLog = dayHasContent(day)
        return Button {
            selectedDate = day
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(hasLog ? theme.primary : theme.mutedLabel.opacity(0.35))
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(dayPrimaryLabel(day))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? theme.onPrimaryGradientForeground : theme.onSurface)
                    Text(daySecondaryLabel(day, hasLog: hasLog))
                        .font(.caption)
                        .foregroundStyle(isSelected
                                         ? theme.onPrimaryGradientForeground.opacity(0.82)
                                         : theme.mutedLabel)
                }
                Spacer(minLength: 0)
                if isSameDay(day, Date()) {
                    Text("今天")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(isSelected ? theme.onPrimaryGradientForeground : theme.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background {
                            Capsule()
                                .fill(isSelected
                                      ? theme.onPrimaryGradientForeground.opacity(0.18)
                                      : theme.primary.opacity(0.16))
                        }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(theme.primaryGradient()) : AnyShapeStyle(Color.clear))
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func dayHasContent(_ day: Date) -> Bool {
        let key = FieldDailyLogCalendar.dayKey(day)
        return store.day(for: key) != .empty
    }

    private func dayPrimaryLabel(_ day: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_Hant_TW")
        f.calendar = FieldDailyLogCalendar.gregorian
        f.timeZone = .current
        f.dateFormat = "M月d日 EEEE"
        return f.string(from: day)
    }

    private func daySecondaryLabel(_ day: Date, hasLog: Bool) -> String {
        hasLog ? "已填寫" : "尚未填寫"
    }

    private func isSameDay(_ a: Date, _ b: Date) -> Bool {
        FieldDailyLogCalendar.dayKey(a) == FieldDailyLogCalendar.dayKey(b)
    }
}
