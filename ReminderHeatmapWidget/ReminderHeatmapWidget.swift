import WidgetKit
import SwiftUI
import EventKit

struct HeatmapEntry: TimelineEntry {
    let date: Date
    let days: [HeatmapDay]
    let weekCount: Int
    let isAuthorized: Bool
    let isError: Bool

    init(date: Date, days: [HeatmapDay], weekCount: Int, isAuthorized: Bool, isError: Bool = false) {
        self.date = date
        self.days = days
        self.weekCount = weekCount
        self.isAuthorized = isAuthorized
        self.isError = isError
    }
}

struct HeatmapTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> HeatmapEntry {
        HeatmapEntry(date: .now, days: [], weekCount: 0, isAuthorized: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (HeatmapEntry) -> Void) {
        Task {
            let entry = await makeEntry()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HeatmapEntry>) -> Void) {
        Task {
            let entry = await makeEntry()
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }

    private func makeEntry() async -> HeatmapEntry {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        guard status == .fullAccess || status == .authorized else {
            return HeatmapEntry(date: .now, days: [], weekCount: 0, isAuthorized: false)
        }

        let widgetData = await HeatmapData.shared.fetchWidgetData(last: 91)

        if widgetData.isError {
            return HeatmapEntry(date: .now, days: [], weekCount: 0, isAuthorized: true, isError: true)
        }

        return HeatmapEntry(
            date: .now,
            days: widgetData.days,
            weekCount: widgetData.weekCount,
            isAuthorized: true
        )
    }
}

struct ReminderHeatmapWidget: Widget {
    let kind = "ReminderHeatmapWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HeatmapTimelineProvider()) { entry in
            HeatmapWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(.windowBackgroundColor)
                }
        }
        .configurationDisplayName("Plotted")
        .description("See your completed reminders as a contribution heatmap.")
        .supportedFamilies([.systemMedium])
    }
}
