import SwiftUI
import WidgetKit

@main
struct ReminderHeatmapApp: App {
    @StateObject private var manager = ReminderManager()
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue

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
            .preferredColorScheme(AppearanceMode(rawValue: appearanceMode)?.colorScheme)
            .onOpenURL { _ in
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
            .task {
                await manager.requestAccess()
                WidgetCenter.shared.reloadAllTimelines()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                manager.markNeedsRefresh()
                Task { await manager.refreshIfNeeded() }
            }
        }
        .handlesExternalEvents(matching: ["*"])
    }
}
