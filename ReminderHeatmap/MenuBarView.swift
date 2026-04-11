import SwiftUI

struct MenuBarView: View {
    @ObservedObject var manager: ReminderManager

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("PLOTTED")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                if manager.streak > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        Text("\(manager.streak)d")
                            .font(.caption.bold().monospacedDigit())
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
                                : .orange)
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
