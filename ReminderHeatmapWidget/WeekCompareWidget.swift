import WidgetKit
import SwiftUI
import EventKit

struct WeekCompareEntry: TimelineEntry {
    let date: Date
    let thisWeek: [Int]  // 7 values, Mon-Sun
    let lastWeek: [Int]  // 7 values, Mon-Sun
    let isAuthorized: Bool
}

struct WeekCompareTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeekCompareEntry {
        WeekCompareEntry(
            date: .now,
            thisWeek: [3, 5, 2, 4, 1, 0, 0],
            lastWeek: [2, 3, 4, 1, 5, 2, 1],
            isAuthorized: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WeekCompareEntry) -> Void) {
        Task {
            let entry = await makeEntry()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeekCompareEntry>) -> Void) {
        Task {
            let entry = await makeEntry()
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }

    private func makeEntry() async -> WeekCompareEntry {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        guard status == .fullAccess || status == .authorized else {
            return WeekCompareEntry(date: .now, thisWeek: Array(repeating: 0, count: 7), lastWeek: Array(repeating: 0, count: 7), isAuthorized: false)
        }

        let widgetData = await HeatmapData.shared.fetchWidgetData(last: 91)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Build date → count lookup
        let countByDate: [Date: Int] = Dictionary(
            widgetData.days.map { (calendar.startOfDay(for: $0.date), $0.count) },
            uniquingKeysWith: { _, new in new }
        )

        // Find this Monday (ISO 8601: Monday = weekday 2 in Apple's calendar where Sunday = 1)
        let weekday = calendar.component(.weekday, from: today) // 1=Sun, 2=Mon, ...
        let daysFromMonday = (weekday + 5) % 7 // Mon=0, Tue=1, ..., Sun=6
        guard let thisMonday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today),
              let lastMonday = calendar.date(byAdding: .day, value: -7, to: thisMonday) else {
            return WeekCompareEntry(date: .now, thisWeek: Array(repeating: 0, count: 7), lastWeek: Array(repeating: 0, count: 7), isAuthorized: true)
        }

        var thisWeek: [Int] = []
        var lastWeek: [Int] = []

        for dayOffset in 0..<7 {
            // This week
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: thisMonday) {
                let key = calendar.startOfDay(for: date)
                if key > today {
                    thisWeek.append(0) // future day
                } else {
                    thisWeek.append(countByDate[key] ?? 0)
                }
            } else {
                thisWeek.append(0)
            }

            // Last week
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: lastMonday) {
                let key = calendar.startOfDay(for: date)
                lastWeek.append(countByDate[key] ?? 0)
            } else {
                lastWeek.append(0)
            }
        }

        return WeekCompareEntry(
            date: .now,
            thisWeek: thisWeek,
            lastWeek: lastWeek,
            isAuthorized: true
        )
    }
}

struct WeekCompareWidget: Widget {
    let kind = "WeekCompareWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeekCompareTimelineProvider()) { entry in
            WeekCompareWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(.windowBackgroundColor)
                }
        }
        .configurationDisplayName("Weekly Compare")
        .description("This week vs last week.")
        .supportedFamilies([.systemMedium])
    }
}
