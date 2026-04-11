import WidgetKit
import SwiftUI
import EventKit

struct TodayEntry: TimelineEntry {
    let date: Date
    let todayCount: Int
    let dailyAverage: Double
    let isAuthorized: Bool
}

struct TodayTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: .now, todayCount: 3, dailyAverage: 4.2, isAuthorized: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        Task {
            let entry = await makeEntry()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        Task {
            let entry = await makeEntry()
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }

    private func makeEntry() async -> TodayEntry {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        guard status == .fullAccess || status == .authorized else {
            return TodayEntry(date: .now, todayCount: 0, dailyAverage: 0, isAuthorized: false)
        }

        let widgetData = await HeatmapData.shared.fetchWidgetData(last: 91)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Compute daily average from past days (exclude today)
        let pastDays = widgetData.days.filter { calendar.startOfDay(for: $0.date) < today }
        let daysWithData = pastDays.filter { $0.count > 0 }
        let dailyAverage: Double
        if daysWithData.isEmpty {
            dailyAverage = 0
        } else {
            let totalCompletions = pastDays.reduce(0) { $0 + $1.count }
            dailyAverage = Double(totalCompletions) / Double(pastDays.count)
        }

        return TodayEntry(
            date: .now,
            todayCount: widgetData.todayCount,
            dailyAverage: dailyAverage,
            isAuthorized: true
        )
    }
}

struct TodayWidget: Widget {
    let kind = "TodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayTimelineProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(.windowBackgroundColor)
                }
        }
        .configurationDisplayName("Today's Progress")
        .description("Today's completions vs your daily average.")
        .supportedFamilies([.systemSmall])
    }
}
