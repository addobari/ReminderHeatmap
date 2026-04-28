import EventKit
import Foundation
import SwiftUI

// MARK: - Models

struct CompletedReminder: Codable, Identifiable, Hashable {
    let id = UUID()
    let title: String
    let listName: String
    let listColorIndex: Int
    let completionTime: Date
}

struct HeatmapDay: Codable, Identifiable, Hashable {
    var id: Date { date }
    let date: Date
    let count: Int
    let reminders: [CompletedReminder]

    init(date: Date, count: Int, reminders: [CompletedReminder] = []) {
        self.date = date
        self.count = count
        self.reminders = reminders
    }
}

struct TrackerDay: Codable, Identifiable, Hashable {
    var id: Date { date }
    let date: Date
    let count: Int
    let completions: [CompletedReminder]

    init(date: Date, count: Int, completions: [CompletedReminder] = []) {
        self.date = date
        self.count = count
        self.completions = completions
    }
}

struct TrackerSummary: Codable, Identifiable, Hashable {
    var id: String { calendarIdentifier + ":" + reminderTitle }
    let reminderTitle: String
    let calendarTitle: String
    let calendarIdentifier: String
    let calendarColorIndex: Int
    let days: [TrackerDay]
    let totalCount: Int
}

struct WidgetData {
    let days: [HeatmapDay]
    let weekCount: Int
    let todayCount: Int
    let streak: Int
    let bestDayCount: Int
    let isError: Bool

    init(days: [HeatmapDay], weekCount: Int, todayCount: Int, streak: Int, bestDayCount: Int, isError: Bool = false) {
        self.days = days
        self.weekCount = weekCount
        self.todayCount = todayCount
        self.streak = streak
        self.bestDayCount = bestDayCount
        self.isError = isError
    }
}

struct TrackerWidgetData {
    let summaries: [TrackerSummary]
    let isError: Bool

    init(summaries: [TrackerSummary], isError: Bool = false) {
        self.summaries = summaries
        self.isError = isError
    }
}

struct TimeIntelligence {
    let velocityStats: VelocityStats?
    let onTimeStats: OnTimeStats?

    struct VelocityStats {
        let medianHours: Double
        let averageHours: Double
        let fastestHours: Double
        let slowestHours: Double
        let totalTracked: Int
        let distribution: [VelocityBucket]
    }

    struct VelocityBucket: Identifiable {
        var id: String { label }
        let label: String
        let count: Int
    }

    struct OnTimeStats {
        let onTimeCount: Int
        let overdueCount: Int
        let noDueDateCount: Int
        let totalCount: Int
        var onTimePercentage: Double {
            let tracked = onTimeCount + overdueCount
            guard tracked > 0 else { return 0 }
            return Double(onTimeCount) / Double(tracked) * 100
        }
        let averageOverdueDays: Double?
    }
}

// MARK: - List Color Palette

enum ListColorPalette {
    static let colors: [Color] = [
        Color(red: 0.25, green: 0.77, blue: 0.39),  // green
        Color(red: 0.30, green: 0.60, blue: 0.90),  // blue
        Color(red: 0.90, green: 0.50, blue: 0.20),  // orange
        Color(red: 0.80, green: 0.30, blue: 0.35),  // red
        Color(red: 0.60, green: 0.40, blue: 0.80),  // purple
        Color(red: 0.95, green: 0.70, blue: 0.20),  // yellow
        Color(red: 0.40, green: 0.75, blue: 0.75),  // teal
        Color(red: 0.85, green: 0.45, blue: 0.65),  // pink
    ]

    static func color(for index: Int) -> Color {
        colors[index % colors.count]
    }
}

// MARK: - Data Fetcher

actor HeatmapData {
    static let shared = HeatmapData()
    private let store = EKEventStore()
    private var cachedEarliestYear: Int?

    private init() {}

    // MARK: - TrackerKey

    private struct TrackerKey: Hashable {
        let calendarIdentifier: String
        let title: String
    }

    // MARK: - List Color Index Map

    /// Builds a dictionary mapping calendar identifiers to stable color indices.
    private func buildColorIndexMap(from calendars: [EKCalendar]) -> [String: Int] {
        let sorted = calendars.sorted { $0.calendarIdentifier < $1.calendarIdentifier }
        var map: [String: Int] = [:]
        for (index, cal) in sorted.enumerated() {
            map[cal.calendarIdentifier] = index
        }
        return map
    }

    // MARK: - Heatmap Fetch

    func fetchDays(last n: Int = 90) async -> [HeatmapDay] {
        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -n, to: calendar.startOfDay(for: now)) else {
            return []
        }

        let predicate = store.predicateForCompletedReminders(
            withCompletionDateStarting: startDate,
            ending: now,
            calendars: nil
        )

        let reminders: [EKReminder]
        do {
            reminders = try await withCheckedThrowingContinuation { continuation in
                store.fetchReminders(matching: predicate) { result in
                    continuation.resume(returning: result ?? [])
                }
            }
        } catch {
            return []
        }

        let allCalendars = store.calendars(for: .reminder)
        let colorMap = buildColorIndexMap(from: allCalendars)

        // Group by day with reminder details
        var dayReminders: [Date: [CompletedReminder]] = [:]
        for reminder in reminders {
            guard let completionDate = reminder.completionDate else { continue }
            let day = calendar.startOfDay(for: completionDate)
            let completed = CompletedReminder(
                title: reminder.title ?? "Untitled",
                listName: reminder.calendar?.title ?? "Unknown",
                listColorIndex: colorMap[reminder.calendar?.calendarIdentifier ?? ""] ?? 0,
                completionTime: completionDate
            )
            dayReminders[day, default: []].append(completed)
        }

        // Sort reminders within each day by completion time
        for (day, items) in dayReminders {
            dayReminders[day] = items.sorted { $0.completionTime < $1.completionTime }
        }

        // Fill in zero-days
        return (0..<n).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: now)) else {
                return nil
            }
            let items = dayReminders[date] ?? []
            return HeatmapDay(date: date, count: items.count, reminders: items)
        }
        .sorted { $0.date < $1.date }
    }

    func completionsThisWeek() async -> Int {
        let days = await fetchDays(last: 7)
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
        return days
            .filter { $0.date >= weekStart }
            .reduce(0) { $0 + $1.count }
    }

    // MARK: - Widget bundle

    func fetchWidgetData(last n: Int = 90) async -> WidgetData {
        let days = await fetchDays(last: n)
        let hasPermission = EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
            || EKEventStore.authorizationStatus(for: .reminder) == .authorized
        let isError = days.isEmpty && !hasPermission
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? today
        let weekCount = days
            .filter { $0.date >= weekStart }
            .reduce(0) { $0 + $1.count }

        let todayCount = days.first(where: { calendar.isDate($0.date, inSameDayAs: today) })?.count ?? 0

        // Streak — build a date→count lookup and walk backwards day by day
        let countByDate: [Date: Int] = Dictionary(
            days.map { (calendar.startOfDay(for: $0.date), $0.count) },
            uniquingKeysWith: { _, new in new }
        )
        var streak = 0
        // If today has completions, start counting from today; otherwise from yesterday
        let startOffset = todayCount > 0 ? 0 : 1
        for offset in startOffset..<n {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { break }
            if (countByDate[date] ?? 0) > 0 {
                streak += 1
            } else {
                break
            }
        }

        let bestDayCount = days.max(by: { $0.count < $1.count })?.count ?? 0

        return WidgetData(
            days: days,
            weekCount: weekCount,
            todayCount: todayCount,
            streak: streak,
            bestDayCount: bestDayCount,
            isError: isError
        )
    }

    // MARK: - Year Fetch (for app full-year view)

    func fetchYearData(year: Int) async -> [HeatmapDay] {
        let calendar = Calendar.current
        let now = Date()

        guard let janFirst = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let decThirtyFirst = calendar.date(from: DateComponents(year: year, month: 12, day: 31)) else {
            return []
        }

        let endDate = min(now, calendar.startOfDay(for: decThirtyFirst).addingTimeInterval(86399))

        guard janFirst <= now else { return [] }

        let predicate = store.predicateForCompletedReminders(
            withCompletionDateStarting: janFirst,
            ending: endDate,
            calendars: nil
        )

        let reminders: [EKReminder]
        do {
            reminders = try await withCheckedThrowingContinuation { continuation in
                store.fetchReminders(matching: predicate) { result in
                    continuation.resume(returning: result ?? [])
                }
            }
        } catch {
            return []
        }

        let allCalendars = store.calendars(for: .reminder)
        let colorMap = buildColorIndexMap(from: allCalendars)

        var dayReminders: [Date: [CompletedReminder]] = [:]
        for reminder in reminders {
            guard let completionDate = reminder.completionDate else { continue }
            let day = calendar.startOfDay(for: completionDate)
            let completed = CompletedReminder(
                title: reminder.title ?? "Untitled",
                listName: reminder.calendar?.title ?? "Unknown",
                listColorIndex: colorMap[reminder.calendar?.calendarIdentifier ?? ""] ?? 0,
                completionTime: completionDate
            )
            dayReminders[day, default: []].append(completed)
        }

        for (day, items) in dayReminders {
            dayReminders[day] = items.sorted { $0.completionTime < $1.completionTime }
        }

        // Build all days in the year up to today
        let lastDay = min(calendar.startOfDay(for: now), calendar.startOfDay(for: decThirtyFirst))
        let totalDays = calendar.dateComponents([.day], from: janFirst, to: lastDay).day! + 1

        return (0..<totalDays).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: janFirst) else { return nil }
            let key = calendar.startOfDay(for: date)
            let items = dayReminders[key] ?? []
            return HeatmapDay(date: key, count: items.count, reminders: items)
        }
    }

    /// Returns the earliest year that has any completed reminder, or current year if none.
    func earliestCompletionYear() async -> Int {
        if let cached = cachedEarliestYear {
            return cached
        }

        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())

        // Fetch all completed reminders with no date bounds
        let predicate = store.predicateForCompletedReminders(
            withCompletionDateStarting: nil,
            ending: Date(),
            calendars: nil
        )

        let reminders: [EKReminder] = await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { result in
                continuation.resume(returning: result ?? [])
            }
        }

        let earliestYear = reminders.compactMap { $0.completionDate }
            .map { calendar.component(.year, from: $0) }
            .min()

        let result = earliestYear ?? currentYear
        cachedEarliestYear = result
        return result
    }

    func invalidateCache() {
        cachedEarliestYear = nil
    }

    // MARK: - Tracker Fetch

    func fetchTrackerData(last n: Int = 30) async -> TrackerWidgetData {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        guard let startDate = calendar.date(byAdding: .day, value: -(n - 1), to: today) else {
            return TrackerWidgetData(summaries: [])
        }

        let allCalendars = store.calendars(for: .reminder)
        let colorMap = buildColorIndexMap(from: allCalendars)

        // Fetch completed reminders in range
        let completedPredicate = store.predicateForCompletedReminders(
            withCompletionDateStarting: startDate,
            ending: now,
            calendars: nil
        )

        let completedReminders: [EKReminder] = await withCheckedContinuation { continuation in
            store.fetchReminders(matching: completedPredicate) { result in
                continuation.resume(returning: result ?? [])
            }
        }

        // Fetch incomplete reminders to find recurring ones not yet completed
        let incompletePredicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: nil
        )

        let incompleteReminders: [EKReminder] = await withCheckedContinuation { continuation in
            store.fetchReminders(matching: incompletePredicate) { result in
                continuation.resume(returning: result ?? [])
            }
        }

        // Collect recurring reminder metadata: TrackerKey → (calendarIdentifier, calendarTitle, colorIndex)
        var recurringMeta: [TrackerKey: (calendarIdentifier: String, calendarTitle: String, colorIndex: Int)] = [:]

        for reminder in completedReminders + incompleteReminders {
            guard let rules = reminder.recurrenceRules, !rules.isEmpty else { continue }
            let title = reminder.title ?? "Untitled"
            let calId = reminder.calendar?.calendarIdentifier ?? ""
            let key = TrackerKey(calendarIdentifier: calId, title: title)
            if recurringMeta[key] == nil {
                recurringMeta[key] = (
                    calendarIdentifier: calId,
                    calendarTitle: reminder.calendar?.title ?? "Unknown",
                    colorIndex: colorMap[calId] ?? 0
                )
            }
        }

        // Build completion lookup: TrackerKey → date → [CompletedReminder]
        var completionsByKeyDate: [TrackerKey: [Date: [CompletedReminder]]] = [:]
        for reminder in completedReminders {
            guard let completionDate = reminder.completionDate else { continue }
            let title = reminder.title ?? "Untitled"
            let calId = reminder.calendar?.calendarIdentifier ?? ""
            let key = TrackerKey(calendarIdentifier: calId, title: title)
            let day = calendar.startOfDay(for: completionDate)
            let cr = CompletedReminder(
                title: title,
                listName: reminder.calendar?.title ?? "Unknown",
                listColorIndex: colorMap[calId] ?? 0,
                completionTime: completionDate
            )
            completionsByKeyDate[key, default: [:]][day, default: []].append(cr)
        }

        // Build summaries
        var summaries: [TrackerSummary] = []

        for (key, meta) in recurringMeta {
            let dateCompletions = completionsByKeyDate[key] ?? [:]

            var trackerDays: [TrackerDay] = []
            var totalCount = 0

            for offset in (0..<n).reversed() {
                guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
                let day = calendar.startOfDay(for: date)
                let dayCompletions = dateCompletions[day] ?? []
                let count = dayCompletions.count
                totalCount += count
                trackerDays.append(TrackerDay(
                    date: day,
                    count: count,
                    completions: dayCompletions.sorted { $0.completionTime < $1.completionTime }
                ))
            }

            summaries.append(TrackerSummary(
                reminderTitle: key.title,
                calendarTitle: meta.calendarTitle,
                calendarIdentifier: meta.calendarIdentifier,
                calendarColorIndex: meta.colorIndex,
                days: trackerDays,
                totalCount: totalCount
            ))
        }

        // Sort by most completions descending
        summaries.sort { $0.totalCount > $1.totalCount }

        return TrackerWidgetData(summaries: summaries)
    }

    // MARK: - Time Intelligence

    func fetchTimeIntelligence(last n: Int = 90) async -> TimeIntelligence {
        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -n, to: calendar.startOfDay(for: now)) else {
            return TimeIntelligence(velocityStats: nil, onTimeStats: nil)
        }

        let predicate = store.predicateForCompletedReminders(
            withCompletionDateStarting: startDate,
            ending: now,
            calendars: nil
        )

        let reminders: [EKReminder]
        do {
            reminders = try await withCheckedThrowingContinuation { continuation in
                store.fetchReminders(matching: predicate) { result in
                    continuation.resume(returning: result ?? [])
                }
            }
        } catch {
            return TimeIntelligence(velocityStats: nil, onTimeStats: nil)
        }

        // --- Velocity ---
        var hoursArray: [Double] = []
        for reminder in reminders {
            guard let completion = reminder.completionDate,
                  let creation = reminder.creationDate else { continue }
            let hours = completion.timeIntervalSince(creation) / 3600.0
            if hours >= 0 {
                hoursArray.append(hours)
            }
        }

        let velocityStats: TimeIntelligence.VelocityStats?
        if hoursArray.isEmpty {
            velocityStats = nil
        } else {
            let sorted = hoursArray.sorted()
            let median: Double
            if sorted.count % 2 == 0 {
                median = (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2.0
            } else {
                median = sorted[sorted.count / 2]
            }

            let bucketDefs: [(label: String, low: Double, high: Double)] = [
                ("<1h", 0, 1),
                ("1–6h", 1, 6),
                ("6–24h", 6, 24),
                ("1–3d", 24, 72),
                ("3–7d", 72, 168),
                ("7d+", 168, .infinity),
            ]
            let distribution = bucketDefs.map { def in
                let count = sorted.filter { $0 >= def.low && $0 < def.high }.count
                return TimeIntelligence.VelocityBucket(label: def.label, count: count)
            }

            velocityStats = TimeIntelligence.VelocityStats(
                medianHours: median,
                averageHours: hoursArray.reduce(0, +) / Double(hoursArray.count),
                fastestHours: sorted.first!,
                slowestHours: sorted.last!,
                totalTracked: hoursArray.count,
                distribution: distribution
            )
        }

        // --- On-Time ---
        var onTimeCount = 0
        var overdueCount = 0
        var noDueDateCount = 0
        var overdueDays: [Double] = []

        for reminder in reminders {
            guard let completion = reminder.completionDate else { continue }

            guard let dueDateComponents = reminder.dueDateComponents,
                  let dueDate = calendar.date(from: dueDateComponents) else {
                noDueDateCount += 1
                continue
            }

            let dueEnd = calendar.startOfDay(for: dueDate).addingTimeInterval(86400)
            if completion <= dueEnd {
                onTimeCount += 1
            } else {
                overdueCount += 1
                let days = completion.timeIntervalSince(dueEnd) / 86400.0
                overdueDays.append(days)
            }
        }

        let totalCount = onTimeCount + overdueCount + noDueDateCount
        let averageOverdueDays: Double? = overdueDays.isEmpty ? nil : overdueDays.reduce(0, +) / Double(overdueDays.count)

        let onTimeStats = TimeIntelligence.OnTimeStats(
            onTimeCount: onTimeCount,
            overdueCount: overdueCount,
            noDueDateCount: noDueDateCount,
            totalCount: totalCount,
            averageOverdueDays: averageOverdueDays
        )

        return TimeIntelligence(velocityStats: velocityStats, onTimeStats: onTimeStats)
    }

    // MARK: - Calendar Events Fetch

    func fetchCalendarEvents(last days: Int = 90) async -> [CalendarEvent] {
        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: now)) else {
            return []
        }

        let predicate = store.predicateForEvents(withStart: startDate, end: now, calendars: nil)
        let ekEvents = store.events(matching: predicate)

        let allCalendars = store.calendars(for: .event)
        let colorMap = buildColorIndexMap(from: allCalendars)

        return ekEvents.map { event in
            CalendarEvent(
                title: event.title ?? "Untitled",
                calendarName: event.calendar?.title ?? "Unknown",
                calendarColorIndex: colorMap[event.calendar?.calendarIdentifier ?? ""] ?? 0,
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay
            )
        }
    }
}
