import WidgetKit
import SwiftUI
import EventKit

struct TrackerEntry: TimelineEntry {
    let date: Date
    let summaries: [TrackerSummary]
    let isAuthorized: Bool
}

struct TrackerTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> TrackerEntry {
        TrackerEntry(date: .now, summaries: [], isAuthorized: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (TrackerEntry) -> Void) {
        Task {
            let entry = await makeEntry()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TrackerEntry>) -> Void) {
        Task {
            let entry = await makeEntry()
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }

    private func makeEntry() async -> TrackerEntry {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        guard status == .fullAccess || status == .authorized else {
            return TrackerEntry(date: .now, summaries: [], isAuthorized: false)
        }

        let data = await HeatmapData.shared.fetchTrackerData(last: 30)
        return TrackerEntry(
            date: .now,
            summaries: data.summaries,
            isAuthorized: true
        )
    }
}

struct TrackerWidget: Widget {
    let kind = "TrackerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TrackerTimelineProvider()) { entry in
            TrackerWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(.windowBackgroundColor)
                }
        }
        .configurationDisplayName("Habit Trackers")
        .description("Track your recurring reminders as daily habits.")
        .supportedFamilies([.systemMedium])
    }
}
