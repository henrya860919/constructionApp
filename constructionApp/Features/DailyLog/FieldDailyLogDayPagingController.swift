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
    let persisted: FieldDailyLogPersistedDay

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            weatherBlock
            notesBlock
        }
    }

    private var weatherBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("天氣")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                .tracking(1.1)

            HStack(spacing: 10) {
                ForEach(FieldDailyLogWeather.allCases, id: \.self) { w in
                    let on = persisted.weatherRaw == w.rawValue
                    Text(w.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(on ? TacticalGlassTheme.onPrimary : Color.white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background {
                            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                                .fill(
                                    on
                                        ? AnyShapeStyle(TacticalGlassTheme.primaryGradient())
                                        : AnyShapeStyle(TacticalGlassTheme.surfaceContainerHighest.opacity(0.55))
                                )
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                                .strokeBorder(TacticalGlassTheme.ghostBorder, lineWidth: on ? 0 : 1)
                        }
                        .accessibilityAddTraits(on ? .isSelected : [])
                }
            }

            if (persisted.weatherRaw ?? "").isEmpty {
                Text("尚未填寫天氣")
                    .font(.footnote)
                    .foregroundStyle(TacticalGlassTheme.mutedLabel.opacity(0.85))
                    .padding(.top, 2)
            }
        }
    }

    private var notesBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("重要事項")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(TacticalGlassTheme.mutedLabel)
                .tracking(1.1)

            let trimmed = persisted.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            Text(trimmed.isEmpty ? "尚無內容，點右下角編輯以新增。" : trimmed)
                .font(.body)
                .foregroundStyle(trimmed.isEmpty ? TacticalGlassTheme.mutedLabel.opacity(0.65) : Color.white.opacity(0.92))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background {
                    RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                        .fill(TacticalGlassTheme.surfaceContainerLowest.opacity(0.95))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: TacticalGlassTheme.cornerRadius, style: .continuous)
                        .strokeBorder(TacticalGlassTheme.outlineVariant.opacity(0.18), lineWidth: 1)
                }
        }
    }
}

// MARK: - Single page（給 HostingController）

struct FieldDailyLogDaySwipeHostingPage: View {
    let date: Date
    @Bindable var store: FieldDailyLogLocalStore

    private var normalized: Date {
        FieldDailyLogDayPagingCalendar.startOfDay(date)
    }

    private var persisted: FieldDailyLogPersistedDay {
        store.day(for: FieldDailyLogDayPagingCalendar.dayKey(normalized))
    }

    var body: some View {
        FieldDailyLogReadOnlyDayContent(persisted: persisted)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(TacticalGlassTheme.surface)
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
