import WidgetKit
import SwiftUI
import EventKit

struct StreakEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let isAuthorized: Bool
}

struct StreakTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: .now, streak: 5, isAuthorized: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        Task {
            let entry = await makeEntry()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        Task {
            let entry = await makeEntry()
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }

    private func makeEntry() async -> StreakEntry {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        guard status == .fullAccess || status == .authorized else {
            return StreakEntry(date: .now, streak: 0, isAuthorized: false)
        }

        let widgetData = await HeatmapData.shared.fetchWidgetData(last: 91)
        return StreakEntry(
            date: .now,
            streak: widgetData.streak,
            isAuthorized: true
        )
    }
}

struct StreakWidget: Widget {
    let kind = "StreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakTimelineProvider()) { entry in
            StreakWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(.windowBackgroundColor)
                }
        }
        .configurationDisplayName("Streak")
        .description("Your current completion streak.")
        .supportedFamilies([.systemSmall])
    }
}
