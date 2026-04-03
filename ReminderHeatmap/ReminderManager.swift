import EventKit
import Foundation
import WidgetKit

@MainActor
final class ReminderManager: ObservableObject {
    @Published var isAuthorized = false
    @Published var isFetching = false
    @Published var lastSyncDate: Date?
    @Published var days: [HeatmapDay] = []
    @Published var yearDays: [HeatmapDay] = []
    @Published var currentDayReminders: [CompletedReminder] = []
    @Published var weekCount = 0
    @Published var streak = 0
    @Published var trackerSummaries: [TrackerSummary] = []
    @Published var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @Published var earliestYear: Int = Calendar.current.component(.year, from: Date())
    @Published var needsRefresh = true

    private let store = EKEventStore()
    private var storeChangedObserver: Any?

    var currentYear: Int { Calendar.current.component(.year, from: Date()) }

    init() {
        storeChangedObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.markNeedsRefresh()
                await HeatmapData.shared.invalidateCache()
            }
        }
    }

    deinit {
        if let observer = storeChangedObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    var todayCount: Int { currentDayReminders.count }

    func requestAccess() async {
        do {
            let granted = try await store.requestFullAccessToReminders()
            isAuthorized = granted
            if granted {
                await refresh()
                WidgetCenter.shared.reloadAllTimelines()
            }
        } catch {
            isAuthorized = false
        }
    }

    func refresh() async {
        if !isAuthorized {
            await requestAccess()
            return
        }

        isFetching = true
        defer { isFetching = false }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Rolling 90-day window for stats (streak + weekCount), independent of year
        let rollingDays = await HeatmapData.shared.fetchDays(last: 90)

        let countByDate: [Date: Int] = Dictionary(
            rollingDays.map { (calendar.startOfDay(for: $0.date), $0.count) },
            uniquingKeysWith: { _, new in new }
        )

        // Today's reminders from rolling data, independent of selectedYear
        currentDayReminders = rollingDays
            .first(where: { calendar.isDate($0.date, inSameDayAs: today) })?
            .reminders ?? []

        // Week count from rolling window
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? today
        weekCount = rollingDays
            .filter { $0.date >= weekStart }
            .reduce(0) { $0 + $1.count }

        // Streak from rolling window
        let tc = countByDate[today] ?? 0
        var s = 0
        let startOffset = tc > 0 ? 0 : 1
        for offset in startOffset..<90 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { break }
            if (countByDate[date] ?? 0) > 0 {
                s += 1
            } else {
                break
            }
        }
        streak = s

        // Year grid data for the selected year
        let targetYear = selectedYear
        let fetchedYearDays: [HeatmapDay]
        if targetYear == currentYear {
            // Reuse rolling 90-day data: it covers recent days; fetch the full year
            // but the rolling data already warmed the cache for overlapping dates
            fetchedYearDays = await HeatmapData.shared.fetchYearData(year: targetYear)
        } else {
            fetchedYearDays = await HeatmapData.shared.fetchYearData(year: targetYear)
        }
        guard selectedYear == targetYear else { return }
        yearDays = fetchedYearDays

        if targetYear == currentYear {
            days = fetchedYearDays
        }

        // Update UI first, then fetch secondary data
        lastSyncDate = Date()
        needsRefresh = false

        // Deferred: earliest year and tracker data (non-blocking for main UI)
        earliestYear = await HeatmapData.shared.earliestCompletionYear()

        let trackerData = await HeatmapData.shared.fetchTrackerData(last: 30)
        trackerSummaries = trackerData.summaries
    }

    func switchYear(to year: Int) async {
        selectedYear = year
        isFetching = true
        defer { isFetching = false }
        let targetYear = year
        let fetchedDays = await HeatmapData.shared.fetchYearData(year: targetYear)
        guard selectedYear == targetYear else { return }
        yearDays = fetchedDays
    }

    func refreshIfNeeded() async {
        guard needsRefresh else { return }
        await refresh()
    }

    func markNeedsRefresh() {
        needsRefresh = true
    }
}
