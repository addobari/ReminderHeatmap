import SwiftUI

struct MenuBarView: View {
    @ObservedObject var manager: ReminderManager

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(HeatmapTheme.greeting)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)
                    Text("PLOTTED")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .tracking(1.5)
                }
                Spacer()
                if manager.streak > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .foregroundStyle(HeatmapTheme.accentWarm(for: colorScheme))
                        Text("\(manager.streak)d")
                            .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                    }
                }
            }

            // Daily progress
            VStack(spacing: 6) {
                HStack {
                    Text("Today")
                        .font(.callout.weight(.medium))
                    Spacer()
                    Text("\(manager.todayCount) of \(manager.dailyGoal)")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(HeatmapTheme.emptyColor(for: colorScheme))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(manager.dailyGoalMet
                                ? HeatmapTheme.accentGreen(for: colorScheme)
                                : HeatmapTheme.accentWarm(for: colorScheme))
                            .frame(width: geo.size.width * manager.dailyGoalProgress)
                    }
                }
                .frame(height: 6)
            }

            // Stats
            HStack(spacing: 16) {
                menuStat(label: "This Week", value: "\(manager.weekCount)")
                if manager.streakFreezeUsedToday {
                    menuStat(label: "Freeze", value: "❄️")
                }
            }

            // Nearest milestone
            if let nearest = manager.milestones
                .filter({ !$0.isExpired })
                .min(by: { $0.daysRemaining < $1.daysRemaining }) {
                HStack(spacing: 6) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(HeatmapTheme.accentWarm(for: colorScheme))
                    Text(nearest.name)
                        .font(.system(size: 11))
                        .lineLimit(1)
                    Spacer()
                    Text("\(nearest.daysRemaining)d")
                        .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Actions
            Button {
                NSApplication.shared.activate(ignoringOtherApps: true)
                if let window = NSApplication.shared.windows.first(where: { $0.canBecomeMain }) {
                    window.makeKeyAndOrderFront(nil)
                }
            } label: {
                HStack {
                    Text("Open Plotted")
                    Spacer()
                    Text("⌘O")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Button {
                manager.markNeedsRefresh()
                Task { await manager.refresh() }
            } label: {
                HStack {
                    Text("Refresh")
                    Spacer()
                    Text("⌘R")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(12)
        .frame(width: 220)
    }

    private func menuStat(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.callout.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Menu bar label helpers

extension MenuBarView {
    static func menuBarIcon(streak: Int) -> String {
        streak > 0 ? "flame.fill" : "checkmark.circle"
    }

    static func menuBarCount(streak: Int, todayCount: Int) -> Int {
        streak > 0 ? streak : todayCount
    }
}
