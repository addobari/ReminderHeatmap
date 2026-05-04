import Foundation
import SwiftUI

// MARK: - Home Header Models

struct WeekdayChipState: Identifiable {
    var id: Int { weekday }
    let weekday: Int        // 1 = Sun … 7 = Sat
    let letter: String      // "M" / "T" / "W" / "T" / "F" / "S" / "S"
    let date: Date
    let count: Int
    let isToday: Bool
    let isFuture: Bool
}

enum WeekRhythm {
    /// Build a chip per day of the current Mon→Sun week using `rollingDays` data.
    static func currentWeekChips(rollingDays: [HeatmapDay]) -> [WeekdayChipState] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Find Monday of the current week
        let weekday = calendar.component(.weekday, from: today) // 1=Sun … 7=Sat
        let daysFromMonday = (weekday + 5) % 7
        guard let weekStart = calendar.date(byAdding: .day, value: -daysFromMonday, to: today) else { return [] }

        let countByDate: [Date: Int] = Dictionary(
            rollingDays.map { (calendar.startOfDay(for: $0.date), $0.count) },
            uniquingKeysWith: { _, new in new }
        )

        let letters = ["M", "T", "W", "T", "F", "S", "S"]
        var chips: [WeekdayChipState] = []
        for offset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else { continue }
            let key = calendar.startOfDay(for: date)
            let wd = calendar.component(.weekday, from: date)
            let isToday = calendar.isDate(key, inSameDayAs: today)
            let isFuture = key > today
            chips.append(WeekdayChipState(
                weekday: wd,
                letter: letters[offset],
                date: key,
                count: countByDate[key] ?? 0,
                isToday: isToday,
                isFuture: isFuture
            ))
        }
        return chips
    }

    /// Active days so far this week (count > 0).
    static func activeDaysThisWeek(rollingDays: [HeatmapDay]) -> Int {
        currentWeekChips(rollingDays: rollingDays)
            .filter { !$0.isFuture && $0.count > 0 }
            .count
    }
}

// MARK: - Active Goal Pace

struct GoalPace {
    enum Status {
        case ahead        // throughput > target
        case onTrack      // within ±10% of target
        case behind       // throughput < target
        case noData
    }

    let totalSessionsNeeded: Int      // not used directly, placeholder for future
    let sessionsSoFar: Int
    let activeDays: Int
    let totalDays: Int
    let timeElapsedFraction: Double
    let sessionFraction: Double       // sessionsSoFar / projectedTotal at target rate
    let currentRateDaysPerSession: Double  // observed days between sessions
    let targetRateDaysPerSession: Double   // baseline expectation
    let status: Status
    let message: String?

    /// Heuristic pace evaluator:
    /// - "current" rate: activeDays / sessionsSoFar (days per session) since milestone created
    /// - "target" rate: linkedReminder summary's overall rate (days / activeDays in last 30)
    /// - We compare observed vs target. Behind if current > target * 1.15.
    static func evaluate(
        milestone: Milestone,
        effort: BehaviorIntelligence.MilestoneEffort?,
        trackerSummaries: [TrackerSummary]
    ) -> GoalPace? {
        guard let effort, effort.totalSessions > 0 else { return nil }

        // Aggregate rolling 30-day rate from linked trackers as the "target" expectation.
        var targetActive = 0
        var targetTotal = 0
        for linked in milestone.linkedReminders {
            guard let s = trackerSummaries.first(where: {
                $0.calendarIdentifier == linked.calendarIdentifier && $0.reminderTitle == linked.reminderTitle
            }) else { continue }
            targetActive += s.days.filter { $0.count > 0 }.count
            targetTotal += s.days.count
        }
        let target30Rate = targetTotal > 0 ? Double(targetActive) / Double(targetTotal) : 0
        let targetDaysPerSession = target30Rate > 0 ? 1.0 / target30Rate : .infinity

        let currentRate = effort.totalDays > 0 ? Double(effort.totalSessions) / Double(effort.totalDays) : 0
        let currentDaysPerSession = currentRate > 0 ? 1.0 / currentRate : .infinity

        // Time elapsed in milestone window
        let timeElapsed = milestone.timeElapsedFraction
        let sessionFraction = min(1.0, timeElapsed > 0 && targetDaysPerSession.isFinite
            ? Double(effort.totalSessions) / max(Double(effort.totalDays) / targetDaysPerSession, 1)
            : 0)

        let status: Status
        let message: String?
        if !targetDaysPerSession.isFinite || !currentDaysPerSession.isFinite {
            status = .noData
            message = nil
        } else if currentDaysPerSession > targetDaysPerSession * 1.15 {
            status = .behind
            message = "Slightly behind pace — sessions are bunched, not spread. Aim for 1× every \(Int(targetDaysPerSession.rounded())) days."
        } else if currentDaysPerSession < targetDaysPerSession * 0.85 {
            status = .ahead
            message = "Ahead of pace — current cadence is 1× every \(Int(currentDaysPerSession.rounded())) days."
        } else {
            status = .onTrack
            message = nil
        }

        return GoalPace(
            totalSessionsNeeded: 0,
            sessionsSoFar: effort.totalSessions,
            activeDays: effort.activeDays,
            totalDays: effort.totalDays,
            timeElapsedFraction: timeElapsed,
            sessionFraction: sessionFraction,
            currentRateDaysPerSession: currentDaysPerSession,
            targetRateDaysPerSession: targetDaysPerSession,
            status: status,
            message: message
        )
    }
}

// MARK: - Keystone Message

enum KeystoneMessageBuilder {
    /// Build a richer, contextual keystone message given today's state.
    /// Falls back to keystone.message if anything is missing.
    static func build(
        keystone: BehaviorIntelligence.KeystoneHabit,
        insights: InsightsData?,
        currentDayReminders: [CompletedReminder]
    ) -> String {
        let calendar = Calendar.current
        let todayWeekday = calendar.component(.weekday, from: Date())

        let didKeystoneToday = currentDayReminders.contains { $0.title == keystone.trackerName }

        let trackerName = keystone.trackerName
        let lift = String(format: "%.1f", keystone.liftFactor)

        var sentence = "On \(trackerName) days you complete \(lift)× more tasks."

        if !didKeystoneToday {
            sentence += " You haven't logged it yet"
        }

        // Add weekday-rank context
        if let insights = insights {
            let ranked = insights.weekdayAverages.sorted { $0.average > $1.average }
            if let myRankIndex = ranked.firstIndex(where: { $0.weekday == todayWeekday }), ranked[myRankIndex].average > 0 {
                let dayName = fullWeekdayName(short: ranked[myRankIndex].shortName)
                let rank = myRankIndex + 1
                let ordinal = ordinalString(rank)
                let separator = didKeystoneToday ? "." : " — and"
                sentence += "\(separator) \(dayName)s are your \(ordinal) strongest day."
            } else if !didKeystoneToday {
                sentence += "."
            }
        } else if !didKeystoneToday {
            sentence += "."
        }

        return sentence
    }

    private static func fullWeekdayName(short: String) -> String {
        switch short {
        case "Mon": return "Monday"
        case "Tue": return "Tuesday"
        case "Wed": return "Wednesday"
        case "Thu": return "Thursday"
        case "Fri": return "Friday"
        case "Sat": return "Saturday"
        case "Sun": return "Sunday"
        default:    return short
        }
    }

    private static func ordinalString(_ n: Int) -> String {
        switch n {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(n)th"
        }
    }
}

// MARK: - Tracker Sort Mode

enum TrackerSortMode: String, CaseIterable, Identifiable {
    case count
    case alphabetical
    case domain
    case recent

    var id: String { rawValue }

    var label: String {
        switch self {
        case .count:        return "Most done"
        case .alphabetical: return "A → Z"
        case .domain:       return "By list"
        case .recent:       return "Recent activity"
        }
    }

    var icon: String {
        switch self {
        case .count:        return "chart.bar.fill"
        case .alphabetical: return "textformat"
        case .domain:       return "folder"
        case .recent:       return "clock"
        }
    }
}

extension Array where Element == TrackerSummary {
    func sorted(by mode: TrackerSortMode) -> [TrackerSummary] {
        switch mode {
        case .count:
            return self.sorted { $0.totalCount > $1.totalCount }
        case .alphabetical:
            return self.sorted { $0.reminderTitle.localizedCaseInsensitiveCompare($1.reminderTitle) == .orderedAscending }
        case .domain:
            return self.sorted { lhs, rhs in
                if lhs.calendarTitle == rhs.calendarTitle {
                    return lhs.totalCount > rhs.totalCount
                }
                return lhs.calendarTitle.localizedCaseInsensitiveCompare(rhs.calendarTitle) == .orderedAscending
            }
        case .recent:
            return self.sorted { lhs, rhs in
                let lhsLast = lhs.days.reversed().first(where: { $0.count > 0 })?.date ?? .distantPast
                let rhsLast = rhs.days.reversed().first(where: { $0.count > 0 })?.date ?? .distantPast
                return lhsLast > rhsLast
            }
        }
    }
}

// MARK: - Excluded Lists Persistence

enum ExcludedListsStore {
    static let key = "excludedListIDs"

    static func current() -> Set<String> {
        let csv = UserDefaults.standard.string(forKey: key) ?? ""
        return Set(csv.split(separator: ",").map { String($0) }.filter { !$0.isEmpty })
    }

    static func save(_ set: Set<String>) {
        let csv = set.sorted().joined(separator: ",")
        UserDefaults.standard.set(csv, forKey: key)
    }
}

// MARK: - Tracker Frequency Targets

/// A weekly frequency target the user sets per tracker (e.g. "3× / week").
/// Used to compute a rate of progress and surface a "set target" CTA on tracker cards.
enum TrackerTarget: String, CaseIterable, Identifiable, Codable {
    case unset
    case oneWeekly
    case twoWeekly
    case threeWeekly
    case fourWeekly
    case fiveWeekly
    case sixWeekly
    case daily

    var id: String { rawValue }

    var label: String {
        switch self {
        case .unset:        return "No target"
        case .oneWeekly:    return "1× / week"
        case .twoWeekly:    return "2× / week"
        case .threeWeekly:  return "3× / week"
        case .fourWeekly:   return "4× / week"
        case .fiveWeekly:   return "5× / week"
        case .sixWeekly:    return "6× / week"
        case .daily:        return "Daily"
        }
    }

    /// Selectable options excluding "unset" — used in the picker grid.
    static var pickerOptions: [TrackerTarget] {
        [.oneWeekly, .twoWeekly, .threeWeekly, .fourWeekly, .fiveWeekly, .sixWeekly, .daily]
    }

    /// Sessions per week implied by this target.
    var perWeek: Double {
        switch self {
        case .unset:        return 0
        case .oneWeekly:    return 1
        case .twoWeekly:    return 2
        case .threeWeekly:  return 3
        case .fourWeekly:   return 4
        case .fiveWeekly:   return 5
        case .sixWeekly:    return 6
        case .daily:        return 7
        }
    }

    /// Expected number of sessions across an N-day window.
    func expectedSessions(over days: Int) -> Double {
        guard self != .unset, days > 0 else { return 0 }
        return perWeek * Double(days) / 7.0
    }
}

/// Persists per-tracker frequency targets in UserDefaults, keyed by the
/// tracker's stable id (calendarIdentifier:reminderTitle).
enum TrackerTargetsStore {
    private static let key = "trackerTargets"
    /// Posted after `set(_:for:)` so views relying on UserDefaults can refresh.
    static let didChange = Notification.Name("TrackerTargetsStore.didChange")

    static func all() -> [String: TrackerTarget] {
        let raw = (UserDefaults.standard.dictionary(forKey: key) as? [String: String]) ?? [:]
        return raw.compactMapValues { TrackerTarget(rawValue: $0) }
    }

    static func target(for trackerID: String) -> TrackerTarget {
        all()[trackerID] ?? .unset
    }

    static func set(_ target: TrackerTarget, for trackerID: String) {
        var dict = (UserDefaults.standard.dictionary(forKey: key) as? [String: String]) ?? [:]
        if target == .unset {
            dict.removeValue(forKey: trackerID)
        } else {
            dict[trackerID] = target.rawValue
        }
        UserDefaults.standard.set(dict, forKey: key)
        NotificationCenter.default.post(name: didChange, object: nil)
    }
}

// MARK: - Daily Brief

struct DailyBrief {
    let bullets: [NarrativeBullet]
    let summary: String

    static func make(
        todayCount: Int,
        dailyGoal: Int,
        streak: Int,
        peakHourRange: InsightsData.PeakHours?,
        bestWeekdayName: String?,
        streakAtRisk: Bool,
        accentGreen: Color,
        accentWarm: Color
    ) -> DailyBrief {
        var bullets: [NarrativeBullet] = []

        // Goal progress
        let goalIcon: String
        let goalColor: Color
        let goalText: String
        if todayCount >= dailyGoal {
            goalIcon = "checkmark.circle.fill"
            goalColor = accentGreen
            goalText = "Daily goal hit — \(todayCount) of \(dailyGoal)"
        } else if todayCount > 0 {
            goalIcon = "circle.bottomhalf.filled"
            goalColor = accentWarm
            goalText = "\(todayCount) of \(dailyGoal) done — \(dailyGoal - todayCount) to go"
        } else {
            goalIcon = "circle"
            goalColor = .secondary
            goalText = "Day's wide open — \(dailyGoal) on the slate"
        }
        bullets.append(NarrativeBullet(icon: goalIcon, iconColor: goalColor, text: goalText))

        // Streak status
        if streak > 0 {
            if streakAtRisk {
                bullets.append(NarrativeBullet(
                    icon: "exclamationmark.triangle.fill",
                    iconColor: .orange,
                    text: "Streak at risk — \(streak) day\(streak == 1 ? "" : "s") riding on today"
                ))
            } else {
                bullets.append(NarrativeBullet(
                    icon: "flame.fill",
                    iconColor: accentWarm,
                    text: "\(streak)-day streak going"
                ))
            }
        }

        // Peak hour window
        if let peak = peakHourRange {
            bullets.append(NarrativeBullet(
                icon: "bolt.fill",
                iconColor: .yellow,
                text: "Peak window: \(formatHour(peak.startHour))–\(formatHour(peak.endHour))"
            ))
        }

        // Best weekday hint, only useful when not the same one
        if let bestDay = bestWeekdayName {
            bullets.append(NarrativeBullet(
                icon: "calendar",
                iconColor: .blue,
                text: "\(bestDay)s tend to be your strongest"
            ))
        }

        let summary: String
        if todayCount >= dailyGoal {
            summary = "Goal hit · \(streak)d streak"
        } else if todayCount > 0 {
            summary = "\(todayCount)/\(dailyGoal) done · \(dailyGoal - todayCount) to go"
        } else if streakAtRisk {
            summary = "Streak at risk — pick one to start"
        } else {
            summary = "0/\(dailyGoal) — let's begin"
        }

        return DailyBrief(bullets: bullets, summary: summary)
    }

    private static func formatHour(_ hour: Int) -> String {
        let h = ((hour % 24) + 24) % 24
        if h == 0 { return "12am" }
        if h == 12 { return "12pm" }
        return h < 12 ? "\(h)am" : "\(h - 12)pm"
    }
}

// MARK: - Dormant Tracker Detection

struct DormantTracker: Identifiable {
    var id: String { summary.id }
    let summary: TrackerSummary
    let daysSilent: Int
    let priorActiveDays: Int
}

enum DormantDetector {
    /// Returns trackers that were active in the past but have gone silent for `silenceThreshold`+ days.
    static func detect(
        summaries: [TrackerSummary],
        silenceThreshold: Int = 5,
        minPriorActiveDays: Int = 5
    ) -> [DormantTracker] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var results: [DormantTracker] = []
        for summary in summaries {
            guard let lastActive = summary.days.reversed().first(where: { $0.count > 0 }) else { continue }
            let daysSilent = calendar.dateComponents([.day], from: lastActive.date, to: today).day ?? 0
            guard daysSilent >= silenceThreshold else { continue }
            let priorActiveDays = summary.days.filter { $0.count > 0 }.count
            guard priorActiveDays >= minPriorActiveDays else { continue }
            results.append(DormantTracker(
                summary: summary,
                daysSilent: daysSilent,
                priorActiveDays: priorActiveDays
            ))
        }
        return results.sorted { $0.priorActiveDays > $1.priorActiveDays }
    }
}

// MARK: - Habit DNA

struct HabitDNA {
    let peakHourLabel: String
    let bestDayLabel: String
    let consistencyPct: Int
    let velocityLabel: String
    let bullets: [NarrativeBullet]

    static func make(
        insights: InsightsData,
        timeIntelligence: TimeIntelligence?,
        rollingDays: [HeatmapDay]
    ) -> HabitDNA? {
        guard !rollingDays.isEmpty else { return nil }

        let peakLabel: String
        if let peak = insights.peakHourRange {
            peakLabel = "\(formatHour(peak.startHour))–\(formatHour(peak.endHour))"
        } else if let median = insights.medianCompletionHour {
            peakLabel = formatHour(median)
        } else {
            peakLabel = "—"
        }

        let bestDayLabel = insights.bestWeekday?.shortName ?? "—"

        let activeDays = rollingDays.filter { $0.count > 0 }.count
        let consistency = rollingDays.isEmpty ? 0 : Int(round(Double(activeDays) / Double(rollingDays.count) * 100))

        let velocityLabel: String
        if let v = timeIntelligence?.velocityStats {
            velocityLabel = formatHours(v.medianHours)
        } else {
            velocityLabel = "—"
        }

        var bullets: [NarrativeBullet] = []
        bullets.append(NarrativeBullet(
            icon: "bolt.fill",
            iconColor: .yellow,
            text: "Peak window: \(peakLabel)"
        ))
        bullets.append(NarrativeBullet(
            icon: "calendar",
            iconColor: .blue,
            text: "Strongest day: \(bestDayLabel)"
        ))
        bullets.append(NarrativeBullet(
            icon: "chart.line.uptrend.xyaxis",
            iconColor: .green,
            text: "Consistency: \(consistency)% of days active"
        ))
        if let _ = timeIntelligence?.velocityStats {
            bullets.append(NarrativeBullet(
                icon: "timer",
                iconColor: .purple,
                text: "Median velocity: \(velocityLabel)"
            ))
        }

        return HabitDNA(
            peakHourLabel: peakLabel,
            bestDayLabel: bestDayLabel,
            consistencyPct: consistency,
            velocityLabel: velocityLabel,
            bullets: bullets
        )
    }

    private static func formatHour(_ hour: Int) -> String {
        let h = ((hour % 24) + 24) % 24
        if h == 0 { return "12am" }
        if h == 12 { return "12pm" }
        return h < 12 ? "\(h)am" : "\(h - 12)pm"
    }

    private static func formatHours(_ hours: Double) -> String {
        if hours < 1 { return "\(Int(hours * 60))m" }
        if hours < 24 { return String(format: "%.1fh", hours) }
        return String(format: "%.1fd", hours / 24)
    }
}

// MARK: - Weekly Digest

struct WeeklyDigest {
    let headline: String
    let bullets: [NarrativeBullet]

    static func make(
        insights: InsightsData,
        rollingDays: [HeatmapDay],
        accentGreen: Color,
        accentWarm: Color
    ) -> WeeklyDigest? {
        guard let momentum = insights.momentum else { return nil }

        let headline: String
        if momentum.thisWeek == 0 && momentum.lastWeek == 0 {
            return nil
        } else if momentum.lastWeek == 0 {
            headline = "Fresh week — \(momentum.thisWeek) completion\(momentum.thisWeek == 1 ? "" : "s")"
        } else if momentum.difference > 0 {
            headline = "Up \(Int(abs(momentum.percentChange)))% over last week"
        } else if momentum.difference < 0 {
            headline = "Down \(Int(abs(momentum.percentChange)))% from last week"
        } else {
            headline = "Steady — same pace as last week"
        }

        var bullets: [NarrativeBullet] = []
        bullets.append(NarrativeBullet(
            icon: "checkmark.circle",
            iconColor: accentGreen,
            text: "This week: \(momentum.thisWeek) · last week: \(momentum.lastWeek)"
        ))

        if let best = insights.bestWeekday, best.average > 0 {
            bullets.append(NarrativeBullet(
                icon: "calendar.badge.clock",
                iconColor: .blue,
                text: "Best day: \(best.shortName) — avg \(String(format: "%.1f", best.average))"
            ))
        }

        if let peak = insights.peakHourRange {
            bullets.append(NarrativeBullet(
                icon: "bolt.fill",
                iconColor: .yellow,
                text: "Peak hours: \(formatHour(peak.startHour))–\(formatHour(peak.endHour))"
            ))
        }

        // Top list this week (last 7 days of rollingDays)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekAgo = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let weekReminders = rollingDays
            .filter { $0.date >= weekAgo && $0.date <= today }
            .flatMap(\.reminders)
        if !weekReminders.isEmpty {
            var listCounts: [String: Int] = [:]
            for r in weekReminders { listCounts[r.listName, default: 0] += 1 }
            if let top = listCounts.max(by: { $0.value < $1.value }) {
                bullets.append(NarrativeBullet(
                    icon: "list.bullet",
                    iconColor: accentWarm,
                    text: "Top list: \(top.key) — \(top.value) completion\(top.value == 1 ? "" : "s")"
                ))
            }
        }

        return WeeklyDigest(headline: headline, bullets: bullets)
    }

    private static func formatHour(_ hour: Int) -> String {
        let h = ((hour % 24) + 24) % 24
        if h == 0 { return "12am" }
        if h == 12 { return "12pm" }
        return h < 12 ? "\(h)am" : "\(h - 12)pm"
    }
}
