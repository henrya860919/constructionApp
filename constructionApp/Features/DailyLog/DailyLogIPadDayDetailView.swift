//
//  DailyLogIPadDayDetailView.swift
//  constructionApp
//
//  iPad 三欄式日誌右欄：顯示當前在中欄選中日期的完整內容（read-only）+「編輯」按鈕。
//  Reuse 共用元件 `FieldDailyLogReadOnlyDayContent`（與 iPhone path 同款），編輯 push 進 `ConstructionDailyLogEditView`。
//

import SwiftUI

struct DailyLogIPadDayDetailView: View {
    let projectId: String
    let date: Date
    @Bindable var store: FieldDailyLogLocalStore

    @Environment(\.fieldTheme) private var theme

    @State private var showEdit: Bool = false

    private var dayKey: String {
        FieldDailyLogCalendar.dayKey(date)
    }

    private var persisted: FieldDailyLogPersistedDay {
        store.day(for: dayKey)
    }

    private var hasContent: Bool {
        persisted != .empty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if hasContent {
                    FieldDailyLogReadOnlyDayContent(persisted: persisted)
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 48)
        }
        .background(theme.surface)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showEdit = true
                } label: {
                    Text(hasContent ? "編輯" : "填寫")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.primary)
                }
            }
        }
        .navigationDestination(isPresented: $showEdit) {
            ConstructionDailyLogEditView(projectId: projectId, date: date, store: store)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(longDateLabel)
                .font(.title3.weight(.bold))
                .foregroundStyle(theme.onSurface)
            Text(weekdayLabel)
                .font(.subheadline)
                .foregroundStyle(theme.mutedLabel)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(theme.mutedLabel.opacity(0.5))
            Text("此日尚未填寫日報")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.onSurface)
            Text("點右上角「填寫」開始")
                .font(.caption)
                .foregroundStyle(theme.mutedLabel)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var longDateLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_Hant_TW")
        f.calendar = FieldDailyLogCalendar.gregorian
        f.timeZone = .current
        f.dateFormat = "yyyy年M月d日"
        return f.string(from: date)
    }

    private var weekdayLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_Hant_TW")
        f.calendar = FieldDailyLogCalendar.gregorian
        f.timeZone = .current
        f.dateFormat = "EEEE"
        return f.string(from: date)
    }
}
