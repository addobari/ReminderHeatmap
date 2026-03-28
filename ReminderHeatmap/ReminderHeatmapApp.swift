import SwiftUI
import WidgetKit

@main
struct ReminderHeatmapApp: App {
    @StateObject private var manager = ReminderManager()

    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationStack {
                    ContentView(manager: manager)
                }
                .tabItem {
                    Label("Heatmap", systemImage: "square.grid.3x3.fill")
                }

                NavigationStack {
                    TrackersView(summaries: manager.trackerSummaries)
                        .navigationTitle("Trackers")
                }
                .tabItem {
                    Label("Trackers", systemImage: "repeat")
                }
            }
            .preferredColorScheme(.dark)
            .onOpenURL { _ in
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
            .task {
                await manager.requestAccess()
                if manager.isAuthorized {
                    await manager.refresh()
                }
                // Force widget to pick up latest code + data
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        .handlesExternalEvents(matching: ["*"])
    }
}
