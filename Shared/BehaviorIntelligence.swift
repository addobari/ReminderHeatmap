import Foundation

struct BehaviorIntelligence {
    let correlations: [TrackerCorrelation]
    let sustainability: SustainabilitySignal?
    let keystoneHabit: KeystoneHabit?
    let identityStatement: String
    let milestoneEfforts: [UUID: MilestoneEffort]

    // MARK: - Types

    struct TrackerCorrelation: Identifiable {
        let id = UUID()
        let trackerA: String
        let trackerB: String
        let liftPercentage: Double
        let message: String
    }

    struct SustainabilitySignal {
        let currentWeekRate: Double
        let baselineRate: Double
        let ratio: Double
        let trend: Trend
        let message: String

        enum Trend { case spiking, declining, steady }
    }

    struct KeystoneHabit: Identifiable {
        let id = UUID()
        let trackerName: String
        let liftFactor: Double
        let message: String
    }

    struct MilestoneEffort {
        let totalSessions: Int
        let activeDays: Int
        let totalDays: Int
        let consistencyRate: Double
    }

    // MARK: - Compute

    static func compute(
        yearDays: [HeatmapDay],
        trackerSummaries: [TrackerSummary],
        milestones: [Milestone],
        streak: Int
    ) -> BehaviorIntelligence {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Identify tracker names from summaries
        let trackerNames = Set(trackerSummaries.map(\.reminderTitle))
        guard !trackerNames.isEmpty else {
            return BehaviorIntelligence(
                correlations: [],
                sustainability: nil,
                keystoneHabit: nil,
                identityStatement: identityStatement(consistency: 0, streak: streak, activeDays: 0),
                milestoneEfforts: [:]
            )
        }

        // Build per-day tracker presence from yearDays
        // dayData[date] = set of tracker names completed that day
        var dayTrackers: [Date: Set<String>] = [:]
        var dayTotalCount: [Date: Int] = [:]
        let pastDays = yearDays.filter { $0.date <= today }

        for day in pastDays {
            let key = calendar.startOfDay(for: day.date)
            let names = Set(day.reminders.map(\.title).filter { trackerNames.contains($0) })
            dayTrackers[key] = names
            dayTotalCount[key] = day.count
        }

        let allDates = pastDays.map { calendar.startOfDay(for: $0.date) }

        // MARK: Correlations
        let correlations = computeCorrelations(trackerNames: Array(trackerNames), dayTrackers: dayTrackers, allDates: allDates)

        // MARK: Sustainability
        let sustainability = computeSustainability(pastDays: pastDays, calendar: calendar, today: today)

        // MARK: Keystone Habit
        let keystoneHabit = computeKeystoneHabit(trackerNames: Array(trackerNames), dayTrackers: dayTrackers, dayTotalCount: dayTotalCount, allDates: allDates)

        // MARK: Identity
        let activeDays = pastDays.filter { $0.count > 0 }.count
        let consistency = pastDays.isEmpty ? 0 : Double(activeDays) / Double(pastDays.count)
        let identity = identityStatement(consistency: consistency, streak: streak, activeDays: activeDays)

        // MARK: Milestone Efforts
        let efforts = computeMilestoneEfforts(milestones: milestones, yearDays: yearDays, calendar: calendar, today: today)

        return BehaviorIntelligence(
            correlations: correlations,
            sustainability: sustainability,
            keystoneHabit: keystoneHabit,
            identityStatement: identity,
            milestoneEfforts: efforts
        )
    }

    // MARK: - Correlations

    private static func computeCorrelations(
        trackerNames: [String],
        dayTrackers: [Date: Set<String>],
        allDates: [Date]
    ) -> [TrackerCorrelation] {
        guard trackerNames.count >= 2, allDates.count >= 14 else { return [] }

        // Baseline rate for each tracker
        var baselineRates: [String: Double] = [:]
        for name in trackerNames {
            let daysPresent = allDates.filter { dayTrackers[$0]?.contains(name) == true }.count
            baselineRates[name] = Double(daysPresent) / max(Double(allDates.count), 1)
        }

        var results: [TrackerCorrelation] = []

        for i in 0..<trackerNames.count {
            for j in (i+1)..<trackerNames.count {
                let a = trackerNames[i]
                let b = trackerNames[j]

                let daysWithA = allDates.filter { dayTrackers[$0]?.contains(a) == true }
                guard daysWithA.count >= 7 else { continue }

                let daysWithAandB = daysWithA.filter { dayTrackers[$0]?.contains(b) == true }.count
                let conditionalRate = Double(daysWithAandB) / Double(daysWithA.count)
                let baselineB = baselineRates[b] ?? 0

                guard baselineB > 0.1 else { continue }

                let lift = ((conditionalRate - baselineB) / baselineB) * 100

                if lift > 20 {
                    let shortA = String(a.prefix(20))
                    let shortB = String(b.prefix(20))
                    results.append(TrackerCorrelation(
                        trackerA: a,
                        trackerB: b,
                        liftPercentage: lift,
                        message: "When you do \(shortA), you're \(Int(lift))% more likely to also do \(shortB)"
                    ))
                }
            }
        }

        return results.sorted { $0.liftPercentage > $1.liftPercentage }
    }

    // MARK: - Sustainability

    private static func computeSustainability(
        pastDays: [HeatmapDay],
        calendar: Calendar,
        today: Date
    ) -> SustainabilitySignal? {
        guard pastDays.count >= 28 else { return nil }

        let thisWeekStart = calendar.date(byAdding: .day, value: -6, to: today)!
        let thisWeek = pastDays.filter { $0.date >= thisWeekStart && $0.date <= today }
        let thisWeekAvg = thisWeek.isEmpty ? 0 : Double(thisWeek.reduce(0) { $0 + $1.count }) / Double(thisWeek.count)

        let fourWeeksAgo = calendar.date(byAdding: .day, value: -27, to: today)!
        let baseline = pastDays.filter { $0.date >= fourWeeksAgo && $0.date <= today }
        let baselineAvg = baseline.isEmpty ? 0 : Double(baseline.reduce(0) { $0 + $1.count }) / Double(baseline.count)

        guard baselineAvg > 0.5 else { return nil }

        let ratio = thisWeekAvg / baselineAvg

        if ratio > 1.5 {
            return SustainabilitySignal(
                currentWeekRate: thisWeekAvg,
                baselineRate: baselineAvg,
                ratio: ratio,
                trend: .spiking,
                message: "You're at \(Int(ratio * 100))% of your normal pace — impressive, but watch for burnout"
            )
        } else if ratio < 0.5 && baselineAvg > 1 {
            return SustainabilitySignal(
                currentWeekRate: thisWeekAvg,
                baselineRate: baselineAvg,
                ratio: ratio,
                trend: .declining,
                message: "Quieter week — you're at \(Int(ratio * 100))% of your usual pace"
            )
        }

        return nil
    }

    // MARK: - Keystone Habit

    private static func computeKeystoneHabit(
        trackerNames: [String],
        dayTrackers: [Date: Set<String>],
        dayTotalCount: [Date: Int],
        allDates: [Date]
    ) -> KeystoneHabit? {
        guard !trackerNames.isEmpty, allDates.count >= 14 else { return nil }

        let overallAvg = Double(allDates.compactMap { dayTotalCount[$0] }.reduce(0, +)) / max(Double(allDates.count), 1)
        guard overallAvg > 0.5 else { return nil }

        var bestLift = 1.0
        var bestName = ""

        for name in trackerNames {
            let daysWithTracker = allDates.filter { dayTrackers[$0]?.contains(name) == true }
            guard daysWithTracker.count >= 7 else { continue }

            let avgOnTrackerDays = Double(daysWithTracker.compactMap { dayTotalCount[$0] }.reduce(0, +)) / Double(daysWithTracker.count)
            let lift = avgOnTrackerDays / overallAvg

            if lift > bestLift {
                bestLift = lift
                bestName = name
            }
        }

        guard bestLift > 1.3, !bestName.isEmpty else { return nil }

        let short = String(bestName.prefix(25))
        return KeystoneHabit(
            trackerName: bestName,
            liftFactor: bestLift,
            message: "On days you do \(short), your overall output is \(String(format: "%.1f", bestLift))× higher"
        )
    }

    // MARK: - Identity Statement

    private static func identityStatement(consistency: Double, streak: Int, activeDays: Int) -> String {
        let pct = Int(consistency * 100)

        if activeDays < 7 {
            return "Just getting started"
        }

        let base: String
        switch pct {
        case 90...100: base = "You show up almost every day"
        case 75..<90:  base = "You've built a strong rhythm"
        case 60..<75:  base = "You're finding your pace"
        case 40..<60:  base = "Building consistency, one day at a time"
        default:       base = "Every day you show up matters"
        }

        if streak >= 30 {
            return "\(base) · \(streak)-day momentum"
        } else if streak >= 14 {
            return "\(base) · \(streak) days and counting"
        }

        return base
    }

    // MARK: - Milestone Efforts

    private static func computeMilestoneEfforts(
        milestones: [Milestone],
        yearDays: [HeatmapDay],
        calendar: Calendar,
        today: Date
    ) -> [UUID: MilestoneEffort] {
        var results: [UUID: MilestoneEffort] = [:]

        for milestone in milestones {
            let linkedTitles = Set(milestone.linkedReminders.map(\.reminderTitle))
            guard !linkedTitles.isEmpty else { continue }

            let startDate = calendar.startOfDay(for: milestone.createdAt)
            let endDate = milestone.isExpired ? calendar.startOfDay(for: milestone.targetDate) : today
            let relevantDays = yearDays.filter { $0.date >= startDate && $0.date <= endDate }

            var totalSessions = 0
            var activeDays = 0
            for day in relevantDays {
                let matched = day.reminders.filter { linkedTitles.contains($0.title) }.count
                totalSessions += matched
                if matched > 0 { activeDays += 1 }
            }

            let totalDays = max(calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 1, 1)
            let rate = Double(activeDays) / Double(totalDays)

            results[milestone.id] = MilestoneEffort(
                totalSessions: totalSessions,
                activeDays: activeDays,
                totalDays: totalDays,
                consistencyRate: rate
            )
        }

        return results
    }
}
