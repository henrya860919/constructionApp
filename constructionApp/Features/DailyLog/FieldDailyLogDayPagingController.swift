//
//  FieldDailyLogDayPagingController.swift
//  constructionApp
//
//  以 UIPageViewController 實作「可連續左右滑、逐日切換」，避免 SwiftUI TabView 三頁回彈導致無法連續滑動。
//

import SwiftUI
import UIKit

// MARK: - Read-only day stack（供分頁與其他畫面共用）

struct FieldDailyLogReadOnlyDayContent: View {
    @Environment(\.fieldTheme) private var theme
    let persisted: FieldDailyLogPersistedDay

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            weatherBlock
            workItemsBlock
            materialsBlock
            personnelBlock
            notesBlock
        }
    }

    private var weatherBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("天氣")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(theme.mutedLabel)
                .tracking(1.1)

            HStack(spacing: 10) {
                ForEach(FieldDailyLogWeather.allCases, id: \.self) { w in
                    let on = persisted.weatherRaw == w.rawValue
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
                                        : AnyShapeStyle(theme.surfaceContainerHighest.opacity(0.55))
                                )
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                                .strokeBorder(theme.ghostBorder, lineWidth: on ? 0 : 1)
                        }
                        .accessibilityAddTraits(on ? .isSelected : [])
                }
            }

            if (persisted.weatherRaw ?? "").isEmpty {
                Text("尚未填寫天氣")
                    .font(.footnote)
                    .foregroundStyle(theme.mutedLabel.opacity(0.85))
                    .padding(.top, 2)
            }
        }
    }

    private var workItemsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("施工項目")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(theme.mutedLabel)
                .tracking(1.1)

            if persisted.workItems.isEmpty {
                Text("尚無施工項目")
                    .font(.footnote)
                    .foregroundStyle(theme.mutedLabel.opacity(0.85))
                    .padding(.top, 2)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(persisted.workItems) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(item.itemNo)　\(item.workItemName)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(theme.onSurface)
                            let qty = item.dailyQty.trimmingCharacters(in: .whitespacesAndNewlines)
                            Text(qty.isEmpty ? "本日完成量：—（\(item.unit)）" : "本日完成量：\(qty)（\(item.unit)）")
                                .font(.footnote)
                                .foregroundStyle(theme.mutedLabel)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
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
            }
        }
    }

    private var materialsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("材料")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(theme.mutedLabel)
                .tracking(1.1)

            let rows = persisted.materials.filter { m in
                let name = m.materialName.trimmingCharacters(in: .whitespacesAndNewlines)
                let du = FieldDailyLogPersonnelReconcile.parseDecimalString(m.dailyUsedQty)
                let acc = FieldDailyLogPersonnelReconcile.parseDecimalString(m.accumulatedQty)
                let remark = m.remark.trimmingCharacters(in: .whitespacesAndNewlines)
                return m.projectResourceId != nil || !name.isEmpty || du != 0 || acc != 0 || !remark.isEmpty
            }

            if rows.isEmpty {
                Text("尚無材料紀錄")
                    .font(.footnote)
                    .foregroundStyle(theme.mutedLabel.opacity(0.85))
                    .padding(.top, 2)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(rows) { m in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(m.materialName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "（未命名）" : m.materialName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(theme.onSurface)
                            Text("單位：\(m.unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : m.unit)")
                                .font(.caption)
                                .foregroundStyle(theme.mutedLabel)
                            Text("本日 \(m.dailyUsedQty)　累計 \(m.accumulatedQty)")
                                .font(.footnote)
                                .foregroundStyle(theme.mutedLabel)
                            let r = m.remark.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !r.isEmpty {
                                Text("備註：\(r)")
                                    .font(.footnote)
                                    .foregroundStyle(theme.mutedLabel)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
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
            }
        }
    }

    private var personnelBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("人員及機具")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(theme.mutedLabel)
                .tracking(1.1)

            let rows = persisted.personnelRows.filter { row in
                if row.projectResourceId != nil { return true }
                let t = row.workType.trimmingCharacters(in: .whitespacesAndNewlines)
                let en = row.equipmentName.trimmingCharacters(in: .whitespacesAndNewlines)
                let dw = FieldDailyLogPersonnelReconcile.parseIntString(row.dailyWorkers)
                let aw = FieldDailyLogPersonnelReconcile.parseIntString(row.accumulatedWorkers)
                let deq = FieldDailyLogPersonnelReconcile.parseDecimalString(row.dailyEquipmentQty)
                let aeq = FieldDailyLogPersonnelReconcile.parseDecimalString(row.accumulatedEquipmentQty)
                return !t.isEmpty || !en.isEmpty || dw != 0 || aw != 0 || deq != 0 || aeq != 0
            }

            if rows.isEmpty {
                Text("尚無人員／機具紀錄")
                    .font(.footnote)
                    .foregroundStyle(theme.mutedLabel.opacity(0.85))
                    .padding(.top, 2)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(rows) { row in
                        VStack(alignment: .leading, spacing: 6) {
                            if let rt = row.resourceType, row.projectResourceId != nil {
                                HStack(spacing: 8) {
                                    Text(rt == "equipment" ? "機具" : "人力")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(theme.mutedLabel)
                                    Text(rt == "equipment"
                                        ? (row.equipmentName.isEmpty ? "—" : row.equipmentName)
                                        : (row.workType.isEmpty ? "—" : row.workType))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(theme.onSurface)
                                }
                                Text("單位：\(row.unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : row.unit)")
                                    .font(.caption)
                                    .foregroundStyle(theme.mutedLabel)
                                if rt == "labor" {
                                    Text("本日 \(row.dailyWorkers)　累計 \(row.accumulatedWorkers)")
                                        .font(.footnote)
                                        .foregroundStyle(theme.mutedLabel)
                                } else {
                                    Text("本日 \(row.dailyEquipmentQty)　累計 \(row.accumulatedEquipmentQty)")
                                        .font(.footnote)
                                        .foregroundStyle(theme.mutedLabel)
                                }
                            } else {
                                if !row.workType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text("工別：\(row.workType)")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(theme.onSurface)
                                }
                                Text("本日人數 \(row.dailyWorkers)　累計 \(row.accumulatedWorkers)")
                                    .font(.footnote)
                                    .foregroundStyle(theme.mutedLabel)
                                if !row.equipmentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text("機具：\(row.equipmentName)")
                                        .font(.footnote)
                                        .foregroundStyle(theme.mutedLabel)
                                }
                                Text("本日機具 \(row.dailyEquipmentQty)　累計 \(row.accumulatedEquipmentQty)")
                                    .font(.footnote)
                                    .foregroundStyle(theme.mutedLabel)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
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
            }
        }
    }

    private var notesBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("重要事項")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(theme.mutedLabel)
                .tracking(1.1)

            let trimmed = persisted.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            Text(trimmed.isEmpty ? "尚無內容，點右下角編輯以新增。" : trimmed)
                .font(.body)
                .foregroundStyle(trimmed.isEmpty ? theme.mutedLabel.opacity(0.65) : theme.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
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
}

// MARK: - Single page（給 HostingController）

struct FieldDailyLogDaySwipeHostingPage: View {
    @Environment(\.fieldTheme) private var theme
    let date: Date
    @Bindable var store: FieldDailyLogLocalStore

    private var normalized: Date {
        FieldDailyLogDayPagingCalendar.startOfDay(date)
    }

    private var persisted: FieldDailyLogPersistedDay {
        store.day(for: FieldDailyLogDayPagingCalendar.dayKey(normalized))
    }

    var body: some View {
        ScrollView {
            FieldDailyLogReadOnlyDayContent(persisted: persisted)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                // 與日誌列表外層一致：底部留出 tab／FAB 可捲動空間
                .padding(.bottom, TacticalGlassTheme.fieldFABBottomInset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.surface)
        .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - Calendar（與 ConstructionDailyLogView 一致）

private enum FieldDailyLogDayPagingCalendar {
    static let gregorian: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "zh_Hant_TW")
        c.timeZone = .current
        c.firstWeekday = 1
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
}

// MARK: - UIPageViewController

struct FieldDailyLogDayPagingController: UIViewControllerRepresentable {
    @Binding var selectedDate: Date
    @Binding var centerWeekStart: Date
    var store: FieldDailyLogLocalStore

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedDate: $selectedDate, centerWeekStart: $centerWeekStart, store: store)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pvc = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal,
            options: [UIPageViewController.OptionsKey.interPageSpacing: 0]
        )
        pvc.dataSource = context.coordinator
        pvc.delegate = context.coordinator
        context.coordinator.pageViewController = pvc

        let start = FieldDailyLogDayPagingCalendar.startOfDay(selectedDate)
        context.coordinator.displayedDate = start
        let vc = context.coordinator.hostingController(for: start)
        pvc.setViewControllers([vc], direction: .forward, animated: false)
        return pvc
    }

    func updateUIViewController(_ pageVC: UIPageViewController, context: Context) {
        let coordinator = context.coordinator
        coordinator.store = store

        if coordinator.isPagingInProgress { return }

        let target = FieldDailyLogDayPagingCalendar.startOfDay(selectedDate)
        if FieldDailyLogDayPagingCalendar.dayKey(target) == FieldDailyLogDayPagingCalendar.dayKey(coordinator.displayedDate) {
            return
        }

        let previous = coordinator.displayedDate
        coordinator.displayedDate = target
        let vc = coordinator.hostingController(for: target)
        let dir: UIPageViewController.NavigationDirection = target > previous ? .forward : .reverse
        pageVC.setViewControllers([vc], direction: dir, animated: false)
    }

    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var selectedDate: Binding<Date>
        var centerWeekStart: Binding<Date>
        var store: FieldDailyLogLocalStore

        weak var pageViewController: UIPageViewController?
        var displayedDate: Date = .distantPast
        var isPagingInProgress = false

        init(selectedDate: Binding<Date>, centerWeekStart: Binding<Date>, store: FieldDailyLogLocalStore) {
            self.selectedDate = selectedDate
            self.centerWeekStart = centerWeekStart
            self.store = store
        }

        func hostingController(for date: Date) -> UIHostingController<FieldDailyLogDaySwipeHostingPage> {
            let d = FieldDailyLogDayPagingCalendar.startOfDay(date)
            let host = UIHostingController(
                rootView: FieldDailyLogDaySwipeHostingPage(date: d, store: store)
            )
            host.view.backgroundColor = .clear
            return host
        }

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let host = viewController as? UIHostingController<FieldDailyLogDaySwipeHostingPage> else { return nil }
            let d = FieldDailyLogDayPagingCalendar.startOfDay(host.rootView.date)
            guard let prev = FieldDailyLogDayPagingCalendar.gregorian.date(byAdding: .day, value: -1, to: d) else { return nil }
            return hostingController(for: prev)
        }

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let host = viewController as? UIHostingController<FieldDailyLogDaySwipeHostingPage> else { return nil }
            let d = FieldDailyLogDayPagingCalendar.startOfDay(host.rootView.date)
            guard let next = FieldDailyLogDayPagingCalendar.gregorian.date(byAdding: .day, value: 1, to: d) else { return nil }
            return hostingController(for: next)
        }

        func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
            isPagingInProgress = true
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController],
            transitionCompleted completed: Bool
        ) {
            isPagingInProgress = false
            guard completed,
                  let host = pageViewController.viewControllers?.first as? UIHostingController<FieldDailyLogDaySwipeHostingPage>
            else { return }

            let d = FieldDailyLogDayPagingCalendar.startOfDay(host.rootView.date)
            displayedDate = d
            selectedDate.wrappedValue = d
            centerWeekStart.wrappedValue = FieldDailyLogDayPagingCalendar.startOfWeek(containing: d)
        }
    }
}
