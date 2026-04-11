import Foundation

struct InsightsData {
    // Analytics
    let hourlyDistribution: [Int]          // 24 elements, index = hour, value = count
    let weekdayAverages: [WeekdayAverage]  // 7 elements, Mon–Sun
    let listRankings: [ListRanking]
    let weeklyTrend: [WeeklyTotal]         // last 12 weeks

    // Predictions
    let medianCompletionHour: Int?
    let bestWeekday: WeekdayAverage?
    let peakHourRange: PeakHours?
    let momentum: Momentum?
    let streakAtRisk: Bool

    struct WeekdayAverage: Identifiable {
        var id: Int { weekday }
        let weekday: Int        // 1=Sun … 7=Sat
        let shortName: String   // "Mon", "Tue", …
        let totalCount: Int
        let weekCount: Int      // number of that weekday in the data
        var average: Double { weekCount > 0 ? Double(totalCount) / Double(weekCount) : 0 }
    }

    struct ListRanking: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let colorIndex: Int
        let count: Int
        let percentage: Double
    }

    struct WeeklyTotal: Identifiable {
        var id: Date { weekStart }
        let weekStart: Date
        let count: Int
    }

    struct PeakHours {
        let startHour: Int
        let endHour: Int
        let count: Int
    }

    struct Momentum {
        let thisWeek: Int
        let lastWeek: Int
        var percentChange: Double {
            guard lastWeek > 0 else { return thisWeek > 0 ? 100 : 0 }
            return Double(thisWeek - lastWeek) / Double(lastWeek) * 100
        }
        var difference: Int { thisWeek - lastWeek }
    }

    static func compute(from days: [HeatmapDay]) -> InsightsData {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let allReminders = days.flatMap(\.reminders)

        // MARK: Hourly distribution
        var hourly = [Int](repeating: 0, count: 24)
        for r in allReminders {
            let hour = calendar.component(.hour, from: r.completionTime)
            hourly[hour] += 1
        }

        // MARK: Weekday averages
        // Count completions per weekday + how many of each weekday appear in the data
        var weekdayTotals = [Int](repeating: 0, count: 7) // index 0=Sun
        var weekdayCounts = [Int](repeating: 0, count: 7)
        for day in days {
            let wd = calendar.component(.weekday, from: day.date) - 1 // 0=Sun
            weekdayCounts[wd] += 1
            weekdayTotals[wd] += day.count
        }
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        // Reorder to Mon–Sun for display
        let monSunOrder = [1, 2, 3, 4, 5, 6, 0] // Mon=1, Tue=2, ... Sun=0
        let weekdayAverages = monSunOrder.map { i in
            WeekdayAverage(
                weekday: i + 1,
                shortName: dayNames[i],
                totalCount: weekdayTotals[i],
                weekCount: weekdayCounts[i]
            )
        }

        // MARK: List rankings
        var listCounts: [String: (colorIndex: Int, count: Int)] = [:]
        for r in allReminders {
            var entry = listCounts[r.listName] ?? (colorIndex: r.listColorIndex, count: 0)
            entry.count += 1
            listCounts[r.listName] = entry
        }
        let total = max(allReminders.count, 1)
        let listRankings = listCounts
            .map { ListRanking(name: $0.key, colorIndex: $0.value.colorIndex, count: $0.value.count, percentage: Double($0.value.count) / Double(total) * 100) }
            .sorted { $0.count > $1.count }

        // MARK: Weekly trend (last 12 weeks)
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        var weeklyTrend: [WeeklyTotal] = []
        for weekOffset in (0..<12).reversed() {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: currentWeekStart) else { continue }
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
            let count = days
                .filter { $0.date >= weekStart && $0.date < weekEnd }
                .reduce(0) { $0 + $1.count }
            weeklyTrend.append(WeeklyTotal(weekStart: weekStart, count: count))
        }

        // MARK: Median completion hour
        let completionHours = allReminders.map { calendar.component(.hour, from: $0.completionTime) }.sorted()
        let medianHour: Int? = completionHours.isEmpty ? nil : completionHours[completionHours.count / 2]

        // MARK: Best weekday
        let bestWeekday = weekdayAverages.max(by: { $0.average < $1.average })

        // MARK: Peak hours (best 2-hour window)
        var peakHourRange: PeakHours?
        if !allReminders.isEmpty {
            var bestWindow = 0
            var bestStart = 0
            for start in 0..<23 {
                let windowCount = hourly[start] + hourly[start + 1]
                if windowCount > bestWindow {
                    bestWindow = windowCount
                    bestStart = start
                }
            }
            if bestWindow > 0 {
                peakHourRange = PeakHours(startHour: bestStart, endHour: bestStart + 2, count: bestWindow)
            }
        }

        // MARK: Weekly momentum
        var momentum: Momentum?
        if weeklyTrend.count >= 2 {
            let thisWeek = weeklyTrend[weeklyTrend.count - 1].count
            let lastWeek = weeklyTrend[weeklyTrend.count - 2].count
            momentum = Momentum(thisWeek: thisWeek, lastWeek: lastWeek)
        }

        // MARK: Streak at risk
        var streakAtRisk = false
        if let median = medianHour {
            let currentHour = calendar.component(.hour, from: now)
            let todayCount = days.first(where: { calendar.isDate($0.date, inSameDayAs: today) })?.count ?? 0
            // At risk if: past median hour, no completions today, and had a streak going
            if currentHour >= median && todayCount == 0 {
                // Check if yesterday had completions (i.e. there's a streak to lose)
                let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
                let yesterdayCount = days.first(where: { calendar.isDate($0.date, inSameDayAs: yesterday) })?.count ?? 0
                streakAtRisk = yesterdayCount > 0
            }
        }

        return InsightsData(
            hourlyDistribution: hourly,
            weekdayAverages: weekdayAverages,
            listRankings: listRankings,
            weeklyTrend: weeklyTrend,
            medianCompletionHour: medianHour,
            bestWeekday: bestWeekday,
            peakHourRange: peakHourRange,
            momentum: momentum,
            streakAtRisk: streakAtRisk
        )
    }
}
