import Foundation

struct SystemIntelligence {
    let domains: [Domain]
    let capacity: CapacityScore
    let compoundingCurves: [UUID: [CurvePoint]]
    let health: SystemHealth

    // MARK: - Types

    struct Domain: Identifiable {
        let id = UUID()
        let name: String
        let colorIndex: Int
        let recentCount: Int
        let previousCount: Int
        let sharePercentage: Double
        var trendPercentage: Double {
            guard previousCount > 0 else { return recentCount > 0 ? 100 : 0 }
            return Double(recentCount - previousCount) / Double(previousCount) * 100
        }
    }

    struct CapacityScore {
        let activeGoals: Int
        let activeTrackers: Int
        let avgDailyCompletions: Double
        let sustainableGoals: Int
        let loadRatio: Double
        let message: String
    }

    struct CurvePoint: Identifiable {
        var id: Date { weekStart }
        let weekStart: Date
        let cumulativeSessions: Int
    }

    struct SystemHealth {
        let balanceScore: Double
        let dominantDomain: String?
        let starvedDomain: String?
        let message: String
    }

    // MARK: - Compute

    static func compute(
        yearDays: [HeatmapDay],
        trackerSummaries: [TrackerSummary],
        milestones: [Milestone]
    ) -> SystemIntelligence {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // MARK: Domains
        let domains = computeDomains(yearDays: yearDays, calendar: calendar, today: today)

        // MARK: Capacity
        let capacity = computeCapacity(
            yearDays: yearDays,
            trackerSummaries: trackerSummaries,
            milestones: milestones,
            calendar: calendar,
            today: today
        )

        // MARK: Compounding Curves
        let curves = computeCompoundingCurves(
            milestones: milestones,
            yearDays: yearDays,
            calendar: calendar,
            today: today
        )

        // MARK: System Health
        let health = computeHealth(domains: domains)

        return SystemIntelligence(
            domains: domains,
            capacity: capacity,
            compoundingCurves: curves,
            health: health
        )
    }

    // MARK: - Domains

    private static func computeDomains(
        yearDays: [HeatmapDay],
        calendar: Calendar,
        today: Date
    ) -> [Domain] {
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -29, to: today)!
        let sixtyDaysAgo = calendar.date(byAdding: .day, value: -59, to: today)!

        let recentDays = yearDays.filter { $0.date >= thirtyDaysAgo && $0.date <= today }
        let previousDays = yearDays.filter { $0.date >= sixtyDaysAgo && $0.date < thirtyDaysAgo }

        // Count per list for recent and previous periods
        var recentByList: [String: (colorIndex: Int, count: Int)] = [:]
        var previousByList: [String: Int] = [:]

        for day in recentDays {
            for r in day.reminders {
                var entry = recentByList[r.listName] ?? (colorIndex: r.listColorIndex, count: 0)
                entry.count += 1
                recentByList[r.listName] = entry
            }
        }
        for day in previousDays {
            for r in day.reminders {
                previousByList[r.listName, default: 0] += 1
            }
        }

        let totalRecent = max(recentByList.values.reduce(0) { $0 + $1.count }, 1)

        return recentByList
            .map { name, info in
                Domain(
                    name: name,
                    colorIndex: info.colorIndex,
                    recentCount: info.count,
                    previousCount: previousByList[name] ?? 0,
                    sharePercentage: Double(info.count) / Double(totalRecent) * 100
                )
            }
            .sorted { $0.recentCount > $1.recentCount }
    }

    // MARK: - Capacity

    private static func computeCapacity(
        yearDays: [HeatmapDay],
        trackerSummaries: [TrackerSummary],
        milestones: [Milestone],
        calendar: Calendar,
        today: Date
    ) -> CapacityScore {
        let activeGoals = milestones.filter { !$0.isExpired }.count
        let activeTrackers = trackerSummaries.count

        // Average daily completions over last 30 days
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -29, to: today)!
        let recentDays = yearDays.filter { $0.date >= thirtyDaysAgo && $0.date <= today }
        let totalCompletions = recentDays.reduce(0) { $0 + $1.count }
        let avgDaily = recentDays.isEmpty ? 0 : Double(totalCompletions) / Double(recentDays.count)

        // Estimate sustainable goals: ~1 goal per 2 daily tracked habits
        // This is a heuristic — if you average 6 completions/day and have 5 trackers,
        // you probably have bandwidth for about 3 goals
        let sustainableGoals = max(Int(ceil(avgDaily / 2.5)), 1)
        let loadRatio = activeGoals > 0 ? Double(activeGoals) / Double(sustainableGoals) : 0

        let message: String
        if activeGoals == 0 {
            message = "No active goals — set one to focus your energy"
        } else if loadRatio <= 0.7 {
            message = "You have room for more"
        } else if loadRatio <= 1.0 {
            message = "Good balance — your throughput supports this load"
        } else if loadRatio <= 1.3 {
            message = "Near capacity — prioritize to stay consistent"
        } else {
            message = "Stretched thin — consider deferring a goal"
        }

        return CapacityScore(
            activeGoals: activeGoals,
            activeTrackers: activeTrackers,
            avgDailyCompletions: avgDaily,
            sustainableGoals: sustainableGoals,
            loadRatio: loadRatio,
            message: message
        )
    }

    // MARK: - Compounding Curves

    private static func computeCompoundingCurves(
        milestones: [Milestone],
        yearDays: [HeatmapDay],
        calendar: Calendar,
        today: Date
    ) -> [UUID: [CurvePoint]] {
        var result: [UUID: [CurvePoint]] = [:]

        for milestone in milestones {
            let linkedTitles = Set(milestone.linkedReminders.map(\.reminderTitle))
            guard !linkedTitles.isEmpty else { continue }

            let startDate = calendar.startOfDay(for: milestone.createdAt)
            let endDate = milestone.isExpired ? calendar.startOfDay(for: milestone.targetDate) : today
            let relevantDays = yearDays
                .filter { $0.date >= startDate && $0.date <= endDate }
                .sorted { $0.date < $1.date }

            guard !relevantDays.isEmpty else { continue }

            // Group by week
            var weeklyPoints: [CurvePoint] = []
            var cumulative = 0
            var currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: startDate)?.start ?? startDate

            while currentWeekStart <= endDate {
                let weekEnd = calendar.date(byAdding: .day, value: 6, to: currentWeekStart)!
                let weekSessions = relevantDays
                    .filter { $0.date >= currentWeekStart && $0.date <= weekEnd }
                    .flatMap(\.reminders)
                    .filter { linkedTitles.contains($0.title) }
                    .count
                cumulative += weekSessions
                weeklyPoints.append(CurvePoint(weekStart: currentWeekStart, cumulativeSessions: cumulative))

                guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart) else { break }
                currentWeekStart = next
            }

            if weeklyPoints.count >= 2 {
                result[milestone.id] = weeklyPoints
            }
        }

        return result
    }

    // MARK: - System Health

    private static func computeHealth(domains: [Domain]) -> SystemHealth {
        guard !domains.isEmpty else {
            return SystemHealth(balanceScore: 0, dominantDomain: nil, starvedDomain: nil, message: "No activity yet")
        }

        // Shannon entropy normalized to 0-1
        let total = Double(domains.reduce(0) { $0 + $1.recentCount })
        guard total > 0 else {
            return SystemHealth(balanceScore: 0, dominantDomain: nil, starvedDomain: nil, message: "No recent activity")
        }

        let maxEntropy = log2(Double(domains.count))
        guard maxEntropy > 0 else {
            return SystemHealth(balanceScore: 1, dominantDomain: nil, starvedDomain: nil, message: "Focused")
        }

        var entropy = 0.0
        for d in domains {
            let p = Double(d.recentCount) / total
            if p > 0 { entropy -= p * log2(p) }
        }
        let balance = entropy / maxEntropy

        let dominant = domains.first
        let starved = domains.count > 2 ? domains.last : nil

        let message: String
        switch balance {
        case 0.8...: message = "Well-balanced across domains"
        case 0.6..<0.8: message = "Mostly balanced — \(starved?.name ?? "some areas") could use attention"
        case 0.4..<0.6: message = "Heavily focused on \(dominant?.name ?? "one area")"
        default: message = "Very concentrated — consider diversifying"
        }

        return SystemHealth(
            balanceScore: balance,
            dominantDomain: dominant?.name,
            starvedDomain: starved?.name,
            message: message
        )
    }
}
