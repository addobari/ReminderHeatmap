import EventKit
import Foundation
import UserNotifications
import WidgetKit
import SwiftUI

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
    @Published var insights: InsightsData?
    @Published var timeIntelligence: TimeIntelligence?
    @Published var badges: [Badge] = []
    @Published var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @Published var earliestYear: Int = Calendar.current.component(.year, from: Date())
    @Published var needsRefresh = true
    @Published var streakFreezeUsedToday: Bool = false
    @Published var newlyUnlockedBadge: Badge?
    @Published var milestones: [Milestone] = []
    @Published var isCalendarAuthorized = false
    @Published var calendarEvents: [CalendarEvent] = []

    var behaviorIntelligence: BehaviorIntelligence {
        BehaviorIntelligence.compute(
            yearDays: yearDays,
            trackerSummaries: trackerSummaries,
            milestones: milestones,
            streak: streak
        )
    }

    var systemIntelligence: SystemIntelligence {
        SystemIntelligence.compute(
            yearDays: yearDays,
            trackerSummaries: trackerSummaries,
            milestones: milestones
        )
    }

    var calendarIntelligence: CalendarIntelligence? {
        guard isCalendarAuthorized, !calendarEvents.isEmpty else { return nil }
        return CalendarIntelligence.compute(
            events: calendarEvents,
            yearDays: yearDays,
            trackerNames: Set(trackerSummaries.map(\.reminderTitle))
        )
    }

    @AppStorage("dailyGoal") var dailyGoal: Int = 5
    @AppStorage("streakFreezeEnabled") var streakFreezeEnabled: Bool = true

    private let store = EKEventStore()
    private var storeChangedObserver: Any?

    var currentYear: Int { Calendar.current.component(.year, from: Date()) }

    init() {
        milestones = MilestoneStore.load()
        checkCalendarAuthorization()
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

    var dailyGoalProgress: Double {
        min(Double(todayCount) / max(Double(dailyGoal), 1), 1.0)
    }

    var dailyGoalMet: Bool {
        todayCount >= dailyGoal
    }

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

        // Streak from rolling window (with optional streak freeze)
        let tc = countByDate[today] ?? 0
        var s = 0
        var freezeUsed = false
        let startOffset = tc > 0 ? 0 : 1
        for offset in startOffset..<90 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { break }
            if (countByDate[date] ?? 0) > 0 {
                s += 1
            } else if streakFreezeEnabled && !freezeUsed {
                // Allow 1 gap day — but check the next day back too
                guard let nextDate = calendar.date(byAdding: .day, value: -(offset + 1), to: today) else { break }
                if (countByDate[nextDate] ?? 0) > 0 {
                    freezeUsed = true
                    // Skip this gap day (don't increment s, don't break)
                } else {
                    break
                }
            } else {
                break
            }
        }
        streak = s
        streakFreezeUsedToday = freezeUsed

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

        // Compute insights from rolling 90-day data (no additional fetch)
        insights = InsightsData.compute(from: rollingDays)
        let oldUnlockedIDs = Set(badges.filter { $0.isUnlocked }.map { $0.id })
        badges = BadgeChecker.evaluate(days: rollingDays, currentStreak: streak)
        let newlyUnlocked = badges.first { $0.isUnlocked && !oldUnlockedIDs.contains($0.id) }
        if let newlyUnlocked {
            newlyUnlockedBadge = newlyUnlocked
        }

        // Deferred: earliest year and tracker data (non-blocking for main UI)
        earliestYear = await HeatmapData.shared.earliestCompletionYear()

        let trackerData = await HeatmapData.shared.fetchTrackerData(last: 30)
        trackerSummaries = trackerData.summaries

        timeIntelligence = await HeatmapData.shared.fetchTimeIntelligence(last: 90)

        // Calendar events (if authorized)
        await fetchCalendarEvents()

        scheduleWeeklyDigest()
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

    // MARK: - Milestones

    func saveMilestone(_ milestone: Milestone) {
        if let idx = milestones.firstIndex(where: { $0.id == milestone.id }) {
            milestones[idx] = milestone
        } else {
            milestones.append(milestone)
        }
        MilestoneStore.save(milestones)
    }

    func deleteMilestone(_ milestone: Milestone) {
        milestones.removeAll { $0.id == milestone.id }
        MilestoneStore.save(milestones)
    }

    func setReflection(_ text: String, for milestone: Milestone) {
        guard let idx = milestones.firstIndex(where: { $0.id == milestone.id }) else { return }
        milestones[idx].reflection = text
        MilestoneStore.save(milestones)
    }

    // MARK: - Calendar Integration

    func checkCalendarAuthorization() {
        let status = EKEventStore.authorizationStatus(for: .event)
        isCalendarAuthorized = status == .fullAccess || status == .authorized
    }

    func requestCalendarAccess() async {
        do {
            let granted = try await store.requestFullAccessToEvents()
            isCalendarAuthorized = granted
            if granted {
                await fetchCalendarEvents()
            }
        } catch {
            isCalendarAuthorized = false
        }
    }

    func fetchCalendarEvents() async {
        guard isCalendarAuthorized else { return }
        calendarEvents = await HeatmapData.shared.fetchCalendarEvents(last: 90)
    }

    private func scheduleWeeklyDigest() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }

        let content = UNMutableNotificationContent()
        content.title = "Plotted Weekly Digest"
        content.body = "You completed \(weekCount) tasks this week"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.weekday = 1 // Sunday
        dateComponents.hour = 18  // 6 PM

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "weekly-digest", content: content, trigger: trigger)

        center.removePendingNotificationRequests(withIdentifiers: ["weekly-digest"])
        center.add(request)
    }
}
