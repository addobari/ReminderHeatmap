import EventKit
import Foundation

@MainActor
final class ReminderManager: ObservableObject {
    @Published var isAuthorized = false
    @Published var isFetching = false
    @Published var lastSyncDate: Date?
    @Published var days: [HeatmapDay] = []
    @Published var yearDays: [HeatmapDay] = []
    @Published var weekCount = 0
    @Published var streak = 0
    @Published var trackerSummaries: [TrackerSummary] = []
    @Published var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @Published var earliestYear: Int = Calendar.current.component(.year, from: Date())

    private let store = EKEventStore()

    var currentYear: Int { Calendar.current.component(.year, from: Date()) }

    var todayReminders: [CompletedReminder] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return yearDays.first(where: { calendar.isDate($0.date, inSameDayAs: today) })?.reminders ?? []
    }

    var todayCount: Int { todayReminders.count }

    func requestAccess() async {
        do {
            let granted = try await store.requestFullAccessToReminders()
            isAuthorized = granted
        } catch {
            isAuthorized = false
        }
    }

    func refresh() async {
        if !isAuthorized {
            await requestAccess()
        }
        guard isAuthorized else { return }

        isFetching = true
        defer { isFetching = false }

        // Fetch current year data for stats (streak, week count always use current year)
        let currentYearDays = await HeatmapData.shared.fetchYearData(year: currentYear)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Week count (Mon-today)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? today
        weekCount = currentYearDays
            .filter { $0.date >= weekStart }
            .reduce(0) { $0 + $1.count }

        // Streak calculation across all data (use 90 days for streak lookback)
        let countByDate: [Date: Int] = Dictionary(
            currentYearDays.map { (calendar.startOfDay(for: $0.date), $0.count) },
            uniquingKeysWith: { _, new in new }
        )
        let tc = countByDate[today] ?? 0
        var s = 0
        let startOffset = tc > 0 ? 0 : 1
        for offset in startOffset..<366 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { break }
            if (countByDate[date] ?? 0) > 0 {
                s += 1
            } else {
                break
            }
        }
        streak = s

        // If viewing current year, reuse the data; otherwise fetch selected year
        if selectedYear == currentYear {
            yearDays = currentYearDays
        } else {
            yearDays = await HeatmapData.shared.fetchYearData(year: selectedYear)
        }

        // Also keep days for backward compat (widget data, etc.)
        days = currentYearDays

        // Earliest year
        earliestYear = await HeatmapData.shared.earliestCompletionYear()

        // Trackers
        let trackerData = await HeatmapData.shared.fetchTrackerData(last: 30)
        trackerSummaries = trackerData.summaries

        lastSyncDate = Date()
    }

    func switchYear(to year: Int) async {
        selectedYear = year
        isFetching = true
        defer { isFetching = false }
        yearDays = await HeatmapData.shared.fetchYearData(year: year)
    }
}
