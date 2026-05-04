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
    @Published var availableLists: [ReminderListInfo] = []

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

        let excludedIDs = ExcludedListsStore.current()

        // Rolling 90-day window for stats (streak + weekCount), independent of year
        let rollingDays = await HeatmapData.shared.fetchDays(last: 90, excludedListIDs: excludedIDs)

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
        let fetchedYearDays = await HeatmapData.shared.fetchYearData(year: targetYear, excludedListIDs: excludedIDs)
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

        let trackerData = await HeatmapData.shared.fetchTrackerData(last: 30, excludedListIDs: excludedIDs)
        trackerSummaries = trackerData.summaries

        timeIntelligence = await HeatmapData.shared.fetchTimeIntelligence(last: 90, excludedListIDs: excludedIDs)

        // Refresh the list of available reminder lists so Settings can show them
        availableLists = await HeatmapData.shared.availableLists()

        // Calendar events (if authorized)
        await fetchCalendarEvents()

        scheduleWeeklyDigest()
    }

    func switchYear(to year: Int) async {
        selectedYear = year
        isFetching = true
        defer { isFetching = false }
        let targetYear = year
        let excludedIDs = ExcludedListsStore.current()
        let fetchedDays = await HeatmapData.shared.fetchYearData(year: targetYear, excludedListIDs: excludedIDs)
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

    // MARK: - Reminder Write Operations

    /// Mark an open reminder as completed. Looks up an incomplete reminder by
    /// title in the given calendar (preferring the soonest due) and toggles it
    /// to complete. Returns true on success.
    @discardableResult
    func completeReminder(title: String, calendarIdentifier: String) async -> Bool {
        guard isAuthorized else { return false }
        guard let calendar = store.calendar(withIdentifier: calendarIdentifier) else { return false }

        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: [calendar]
        )

        let reminders: [EKReminder] = await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { result in
                continuation.resume(returning: result ?? [])
            }
        }

        // Prefer reminders matching the title, soonest due first; fall back to
        // any title match. Trim whitespace + case-insensitive comparison.
        let normalizedTarget = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matches = reminders.filter {
            ($0.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedTarget
        }
        let sorted = matches.sorted { lhs, rhs in
            let lhsDate = lhs.dueDateComponents?.date ?? .distantFuture
            let rhsDate = rhs.dueDateComponents?.date ?? .distantFuture
            return lhsDate < rhsDate
        }

        guard let target = sorted.first else { return false }

        target.isCompleted = true
        target.completionDate = Date()

        do {
            try store.save(target, commit: true)
            markNeedsRefresh()
            await refreshIfNeeded()
            WidgetCenter.shared.reloadAllTimelines()
            return true
        } catch {
            return false
        }
    }

    /// Recurrence options for newly-created reminders.
    enum RecurrenceOption: String, CaseIterable, Identifiable {
        case none, daily, weekly, monthly, yearly
        var id: String { rawValue }

        var label: String {
            switch self {
            case .none:    return "Never"
            case .daily:   return "Every day"
            case .weekly:  return "Every week"
            case .monthly: return "Every month"
            case .yearly:  return "Every year"
            }
        }

        fileprivate var ekFrequency: EKRecurrenceFrequency? {
            switch self {
            case .none:    return nil
            case .daily:   return .daily
            case .weekly:  return .weekly
            case .monthly: return .monthly
            case .yearly:  return .yearly
            }
        }

        fileprivate static func from(_ rule: EKRecurrenceRule?) -> RecurrenceOption {
            guard let rule else { return .none }
            switch rule.frequency {
            case .daily:   return .daily
            case .weekly:  return .weekly
            case .monthly: return .monthly
            case .yearly:  return .yearly
            @unknown default: return .none
            }
        }
    }

    /// A flattened editable view of an EKReminder used by the reminder editor sheet.
    struct EditableReminder: Equatable, Identifiable {
        let id: String                  // EKReminder.calendarItemIdentifier
        var title: String
        var calendarIdentifier: String
        var dueDate: Date?
        var recurrence: RecurrenceOption
        var notes: String
    }

    /// Create a new EKReminder in the specified list and save it. Returns true
    /// on success.
    @discardableResult
    func createReminder(
        title: String,
        calendarIdentifier: String,
        dueDate: Date? = nil,
        recurrence: RecurrenceOption = .none,
        notes: String? = nil
    ) async -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, isAuthorized else { return false }
        guard let calendar = store.calendar(withIdentifier: calendarIdentifier) else { return false }

        let reminder = EKReminder(eventStore: store)
        reminder.title = trimmed
        reminder.calendar = calendar
        if let notes, !notes.isEmpty { reminder.notes = notes }

        if let dueDate {
            let cal = Calendar.current
            reminder.dueDateComponents = cal.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: dueDate
            )
        }

        if let frequency = recurrence.ekFrequency {
            let rule = EKRecurrenceRule(recurrenceWith: frequency, interval: 1, end: nil)
            reminder.recurrenceRules = [rule]
        }

        do {
            try store.save(reminder, commit: true)
            markNeedsRefresh()
            await refreshIfNeeded()
            WidgetCenter.shared.reloadAllTimelines()
            return true
        } catch {
            return false
        }
    }

    /// Convert an EKReminder into a flattened EditableReminder snapshot.
    private func makeEditable(_ reminder: EKReminder) -> EditableReminder {
        let cal = Calendar.current
        let due = reminder.dueDateComponents.flatMap { cal.date(from: $0) }
        return EditableReminder(
            id: reminder.calendarItemIdentifier,
            title: reminder.title ?? "",
            calendarIdentifier: reminder.calendar?.calendarIdentifier ?? "",
            dueDate: due,
            recurrence: RecurrenceOption.from(reminder.recurrenceRules?.first),
            notes: reminder.notes ?? ""
        )
    }

    /// Load an editable snapshot of an existing reminder by its calendarItemIdentifier.
    func loadEditableReminder(reminderID: String) async -> EditableReminder? {
        guard isAuthorized, !reminderID.isEmpty else { return nil }
        guard let item = store.calendarItem(withIdentifier: reminderID) as? EKReminder else { return nil }
        return makeEditable(item)
    }

    /// Find the most relevant open reminder matching a tracker (title + calendar)
    /// and return it as an editable snapshot. Prefers reminders with a recurrence
    /// rule (the recurring template) over one-off instances.
    func loadEditableReminder(title: String, calendarIdentifier: String) async -> EditableReminder? {
        guard isAuthorized else { return nil }
        guard let calendar = store.calendar(withIdentifier: calendarIdentifier) else { return nil }

        let predicate = store.predicateForReminders(in: [calendar])
        let reminders: [EKReminder] = await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { result in
                continuation.resume(returning: result ?? [])
            }
        }

        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matches = reminders.filter {
            ($0.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized
        }
        // Prefer recurring template; then incomplete; then most recent.
        let sorted = matches.sorted { lhs, rhs in
            let lhsRec = (lhs.recurrenceRules?.isEmpty == false) ? 0 : 1
            let rhsRec = (rhs.recurrenceRules?.isEmpty == false) ? 0 : 1
            if lhsRec != rhsRec { return lhsRec < rhsRec }
            let lhsInc = lhs.isCompleted ? 1 : 0
            let rhsInc = rhs.isCompleted ? 1 : 0
            if lhsInc != rhsInc { return lhsInc < rhsInc }
            let lhsDate = lhs.lastModifiedDate ?? .distantPast
            let rhsDate = rhs.lastModifiedDate ?? .distantPast
            return lhsDate > rhsDate
        }

        guard let target = sorted.first else { return nil }
        return makeEditable(target)
    }

    /// Save edits to an existing reminder. Returns true on success.
    @discardableResult
    func updateReminder(_ edit: EditableReminder) async -> Bool {
        let trimmed = edit.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, isAuthorized, !edit.id.isEmpty else { return false }
        guard let item = store.calendarItem(withIdentifier: edit.id) as? EKReminder else { return false }

        item.title = trimmed
        item.notes = edit.notes.isEmpty ? nil : edit.notes

        if let newCalendar = store.calendar(withIdentifier: edit.calendarIdentifier),
           item.calendar?.calendarIdentifier != newCalendar.calendarIdentifier {
            item.calendar = newCalendar
        }

        if let due = edit.dueDate {
            item.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: due
            )
        } else {
            item.dueDateComponents = nil
        }

        // Recurrence: remove any existing rules, then add the desired one.
        if let existingRules = item.recurrenceRules {
            for rule in existingRules { item.removeRecurrenceRule(rule) }
        }
        if let frequency = edit.recurrence.ekFrequency {
            item.addRecurrenceRule(EKRecurrenceRule(recurrenceWith: frequency, interval: 1, end: nil))
        }

        do {
            try store.save(item, commit: true)
            markNeedsRefresh()
            await refreshIfNeeded()
            WidgetCenter.shared.reloadAllTimelines()
            return true
        } catch {
            return false
        }
    }

    /// Delete a reminder permanently. Returns true on success.
    @discardableResult
    func deleteReminder(reminderID: String) async -> Bool {
        guard isAuthorized, !reminderID.isEmpty else { return false }
        guard let item = store.calendarItem(withIdentifier: reminderID) as? EKReminder else { return false }

        do {
            try store.remove(item, commit: true)
            markNeedsRefresh()
            await refreshIfNeeded()
            WidgetCenter.shared.reloadAllTimelines()
            return true
        } catch {
            return false
        }
    }

    /// Mark a previously-completed reminder as not completed using its
    /// EKReminder calendarItemIdentifier. Returns true on success.
    @discardableResult
    func uncompleteReminder(reminderID: String) async -> Bool {
        guard isAuthorized, !reminderID.isEmpty else { return false }
        guard let item = store.calendarItem(withIdentifier: reminderID) as? EKReminder else { return false }

        item.isCompleted = false
        item.completionDate = nil

        do {
            try store.save(item, commit: true)
            markNeedsRefresh()
            await refreshIfNeeded()
            WidgetCenter.shared.reloadAllTimelines()
            return true
        } catch {
            return false
        }
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
