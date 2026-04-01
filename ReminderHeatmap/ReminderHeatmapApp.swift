import SwiftUI
import Sparkle
import WidgetKit

@main
struct ReminderHeatmapApp: App {
    @StateObject private var manager = ReminderManager()
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

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
            .frame(minWidth: 520, minHeight: 400)
            .preferredColorScheme((AppearanceMode(rawValue: appearanceMode) ?? .system).colorScheme)
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
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
                // Trigger re-evaluation when system appearance changes
            }
        }
        .handlesExternalEvents(matching: ["*"])
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
        }
    }
}
