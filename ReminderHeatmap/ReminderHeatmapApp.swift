import SwiftUI
import Sparkle
import WidgetKit

@main
struct ReminderHeatmapApp: App {
    @StateObject private var manager = ReminderManager()
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @State private var showWelcome = false
    @State private var showBadgeToast = false
    @State private var toastBadge: Badge?
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
                .keyboardShortcut("1", modifiers: .command)

                NavigationStack {
                    TrackersView(summaries: manager.trackerSummaries)
                        .navigationTitle("Trackers")
                }
                .tabItem {
                    Label("Trackers", systemImage: "repeat")
                }
                .keyboardShortcut("2", modifiers: .command)

                NavigationStack {
                    if let insights = manager.insights {
                        InsightsView(insights: insights, streak: manager.streak, timeIntelligence: manager.timeIntelligence, badges: manager.badges, rollingDays: manager.days)
                    } else {
                        ProgressView("Loading insights…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .tabItem {
                    Label("Insights", systemImage: "chart.bar.fill")
                }
                .keyboardShortcut("3", modifiers: .command)
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
            .onAppear {
                if !hasSeenWelcome {
                    showWelcome = true
                }
            }
            .sheet(isPresented: $showWelcome) {
                WelcomeView()
                    .frame(width: 420, height: 400)
            }
            .overlay(alignment: .top) {
                if showBadgeToast, let badge = toastBadge {
                    BadgeToast(badge: badge)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation { showBadgeToast = false }
                            }
                        }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                manager.markNeedsRefresh()
                Task { await manager.refreshIfNeeded() }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            }
            .onChange(of: manager.newlyUnlockedBadge) { newBadge in
                if let badge = newBadge {
                    toastBadge = badge
                    withAnimation(.spring(response: 0.4)) {
                        showBadgeToast = true
                    }
                }
            }
        }
        .handlesExternalEvents(matching: ["*"])
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
            CommandGroup(replacing: .newItem) {
                Button("Refresh") {
                    manager.markNeedsRefresh()
                    Task { await manager.refreshIfNeeded() }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }

        MenuBarExtra {
            MenuBarView(manager: manager)
        } label: {
            let icon = MenuBarView.menuBarIcon(streak: manager.streak)
            let count = MenuBarView.menuBarCount(streak: manager.streak, todayCount: manager.todayCount)
            Label("\(count)", systemImage: icon)
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Badge Toast

private struct BadgeToast: View {
    let badge: Badge
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: badge.icon)
                .font(.title3)
                .foregroundStyle(HeatmapTheme.accentGreen(for: colorScheme))
            VStack(alignment: .leading, spacing: 1) {
                Text("🏆 Badge Unlocked!")
                    .font(.caption.bold())
                Text(badge.name)
                    .font(.callout.weight(.semibold))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 8, y: 4)
    }
}
