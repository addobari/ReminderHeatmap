import EventKit
import Foundation

// MARK: - Lightweight Calendar Event

struct CalendarEvent: Identifiable {
    let id = UUID()
    let title: String
    let calendarName: String
    let calendarColorIndex: Int
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool

    var durationHours: Double {
        isAllDay ? 8 : endDate.timeIntervalSince(startDate) / 3600
    }
}

// MARK: - Calendar Intelligence

struct CalendarIntelligence {
    let timeAllocation: [CalendarDomain]
    let meetingLoad: MeetingLoad
    let correlations: [CalendarCorrelation]
    let timeBlockMatches: [TimeBlockMatch]

    struct CalendarDomain: Identifiable {
        let id = UUID()
        let name: String
        let colorIndex: Int
        let hoursThisPeriod: Double
        let eventCount: Int
        let sharePercentage: Double
    }

    struct MeetingLoad {
        let avgHoursPerDay: Double
        let heaviestDayHours: Double
        let heaviestDayName: String
        let lightestDayHours: Double
        let lightestDayName: String
        let correlation: String?
    }

    struct CalendarCorrelation: Identifiable {
        let id = UUID()
        let message: String
        let impact: Impact
        enum Impact { case positive, negative, neutral }
    }

    struct TimeBlockMatch: Identifiable {
        let id = UUID()
        let eventTitle: String
        let trackerTitle: String
        let matchedDays: Int
        let totalDays: Int
        var adherenceRate: Double { totalDays > 0 ? Double(matchedDays) / Double(totalDays) : 0 }
    }

    // MARK: - Compute

    static func compute(
        events: [CalendarEvent],
        yearDays: [HeatmapDay],
        trackerNames: Set<String>
    ) -> CalendarIntelligence {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -29, to: today)!

        let recentEvents = events.filter { $0.startDate >= thirtyDaysAgo && $0.startDate <= today }

        let allocation = computeTimeAllocation(events: recentEvents)
        let load = computeMeetingLoad(events: recentEvents, yearDays: yearDays, calendar: calendar, today: today)
        let correlations = computeCorrelations(events: recentEvents, yearDays: yearDays, calendar: calendar, today: today)
        let matches = computeTimeBlockMatches(events: recentEvents, yearDays: yearDays, trackerNames: trackerNames, calendar: calendar)

        return CalendarIntelligence(
            timeAllocation: allocation,
            meetingLoad: load,
            correlations: correlations,
            timeBlockMatches: matches
        )
    }

    // MARK: - Time Allocation

    private static func computeTimeAllocation(events: [CalendarEvent]) -> [CalendarDomain] {
        var byCalendar: [String: (colorIndex: Int, hours: Double, count: Int)] = [:]

        for event in events {
            var entry = byCalendar[event.calendarName] ?? (colorIndex: event.calendarColorIndex, hours: 0, count: 0)
            entry.hours += event.durationHours
            entry.count += 1
            byCalendar[event.calendarName] = entry
        }

        let totalHours = max(byCalendar.values.reduce(0) { $0 + $1.hours }, 1)

        return byCalendar
            .map { name, info in
                CalendarDomain(
                    name: name,
                    colorIndex: info.colorIndex,
                    hoursThisPeriod: info.hours,
                    eventCount: info.count,
                    sharePercentage: info.hours / totalHours * 100
                )
            }
            .sorted { $0.hoursThisPeriod > $1.hoursThisPeriod }
    }

    // MARK: - Meeting Load

    private static func computeMeetingLoad(
        events: [CalendarEvent],
        yearDays: [HeatmapDay],
        calendar: Calendar,
        today: Date
    ) -> MeetingLoad {
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -29, to: today)!

        // Hours per day of week
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        var hoursByWeekday = [Int: Double]()
        var countByWeekday = [Int: Int]()

        for event in events {
            let wd = calendar.component(.weekday, from: event.startDate)
            hoursByWeekday[wd, default: 0] += event.durationHours
            countByWeekday[wd, default: 0] += 1
        }

        // Average across the 30-day window (roughly 4 of each weekday)
        var avgByWeekday = [Int: Double]()
        for wd in 1...7 {
            let weeks = max(countByWeekday[wd] ?? 0, 1)
            avgByWeekday[wd] = (hoursByWeekday[wd] ?? 0) / Double(min(weeks, 4))
        }

        let heaviest = avgByWeekday.max(by: { $0.value < $1.value })
        let lightest = avgByWeekday.filter({ $0.value > 0 }).min(by: { $0.value < $1.value })

        let totalHours = events.reduce(0.0) { $0 + $1.durationHours }
        let recentDays = yearDays.filter { $0.date >= thirtyDaysAgo && $0.date <= today }
        let numDays = max(recentDays.count, 1)
        let avgPerDay = totalHours / Double(numDays)

        // Correlation: on heavy vs light meeting days, how does completion change?
        var heavyDayCompletions = [Int]()
        var lightDayCompletions = [Int]()

        for day in recentDays {
            let dayStart = calendar.startOfDay(for: day.date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            let dayEventHours = events
                .filter { $0.startDate >= dayStart && $0.startDate < dayEnd }
                .reduce(0.0) { $0 + $1.durationHours }

            if dayEventHours > avgPerDay * 1.5 {
                heavyDayCompletions.append(day.count)
            } else if dayEventHours < avgPerDay * 0.5 {
                lightDayCompletions.append(day.count)
            }
        }

        let heavyAvg = heavyDayCompletions.isEmpty ? 0 : Double(heavyDayCompletions.reduce(0, +)) / Double(heavyDayCompletions.count)
        let lightAvg = lightDayCompletions.isEmpty ? 0 : Double(lightDayCompletions.reduce(0, +)) / Double(lightDayCompletions.count)

        var correlation: String?
        if heavyDayCompletions.count >= 3 && lightDayCompletions.count >= 3 && lightAvg > 0 {
            let diff = ((lightAvg - heavyAvg) / lightAvg) * 100
            if diff > 15 {
                correlation = "On heavy calendar days, you complete \(Int(diff))% fewer tasks"
            } else if diff < -15 {
                correlation = "Busy calendar days don't slow you down — you complete more"
            }
        }

        return MeetingLoad(
            avgHoursPerDay: avgPerDay,
            heaviestDayHours: heaviest?.value ?? 0,
            heaviestDayName: dayNames[(heaviest?.key ?? 1) - 1],
            lightestDayHours: lightest?.value ?? 0,
            lightestDayName: dayNames[(lightest?.key ?? 1) - 1],
            correlation: correlation
        )
    }

    // MARK: - Calendar ↔ Completion Correlations

    private static func computeCorrelations(
        events: [CalendarEvent],
        yearDays: [HeatmapDay],
        calendar: Calendar,
        today: Date
    ) -> [CalendarCorrelation] {
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -29, to: today)!
        let recentDays = yearDays.filter { $0.date >= thirtyDaysAgo && $0.date <= today }
        guard recentDays.count >= 14 else { return [] }

        var results: [CalendarCorrelation] = []

        // Event count buckets
        var fewEventsDays = [Int]()   // 0-1 events
        var manyEventsDays = [Int]()  // 4+ events

        for day in recentDays {
            let dayStart = calendar.startOfDay(for: day.date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            let eventCount = events.filter { $0.startDate >= dayStart && $0.startDate < dayEnd }.count

            if eventCount <= 1 { fewEventsDays.append(day.count) }
            if eventCount >= 4 { manyEventsDays.append(day.count) }
        }

        if fewEventsDays.count >= 3 && manyEventsDays.count >= 3 {
            let fewAvg = Double(fewEventsDays.reduce(0, +)) / Double(fewEventsDays.count)
            let manyAvg = Double(manyEventsDays.reduce(0, +)) / Double(manyEventsDays.count)

            if fewAvg > manyAvg * 1.2 {
                results.append(CalendarCorrelation(
                    message: "Quiet days (≤1 event) → \(String(format: "%.1f", fewAvg)) avg completions vs \(String(format: "%.1f", manyAvg)) on busy days",
                    impact: .neutral
                ))
            }
        }

        return results
    }

    // MARK: - Time Block Adherence

    private static func computeTimeBlockMatches(
        events: [CalendarEvent],
        yearDays: [HeatmapDay],
        trackerNames: Set<String>,
        calendar: Calendar
    ) -> [TimeBlockMatch] {
        guard !trackerNames.isEmpty else { return [] }

        // Find calendar events whose title fuzzy-matches a tracker name
        var matches: [String: (trackerTitle: String, matchedDays: Int, totalDays: Int)] = [:]

        for trackerName in trackerNames {
            let lower = trackerName.lowercased()
            let matchingEvents = events.filter { $0.title.lowercased().contains(lower) || lower.contains($0.title.lowercased()) }

            guard !matchingEvents.isEmpty else { continue }

            // For each day with a matching event, check if the tracker was completed
            var matched = 0
            var total = 0
            let eventDates = Set(matchingEvents.map { calendar.startOfDay(for: $0.startDate) })

            for date in eventDates {
                total += 1
                let dayData = yearDays.first(where: { calendar.isDate($0.date, inSameDayAs: date) })
                if let day = dayData, day.reminders.contains(where: { $0.title == trackerName }) {
                    matched += 1
                }
            }

            if total >= 3 {
                matches[trackerName] = (trackerTitle: trackerName, matchedDays: matched, totalDays: total)
            }
        }

        return matches.values
            .map { TimeBlockMatch(eventTitle: $0.trackerTitle, trackerTitle: $0.trackerTitle, matchedDays: $0.matchedDays, totalDays: $0.totalDays) }
            .sorted { $0.adherenceRate > $1.adherenceRate }
    }
}
