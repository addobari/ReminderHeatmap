import SwiftUI
import WidgetKit

struct StreakWidgetView: View {
    let entry: StreakEntry

    @Environment(\.colorScheme) private var colorScheme

    private static let appURL = URL(string: "reminderheatmap://open")!

    var body: some View {
        Group {
            if !entry.isAuthorized {
                messageView(
                    icon: "lock.shield",
                    iconColor: .orange,
                    text: "Open app to enable\nReminders access"
                )
            } else if entry.streak == 0 {
                noStreakView
            } else {
                streakView
            }
        }
        .widgetURL(Self.appURL)
    }

    // MARK: - Message state

    private func messageView(icon: String, iconColor: Color, text: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
            Text(text)
                .font(.system(size: 11))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - No active streak

    private var noStreakView: some View {
        VStack(spacing: 6) {
            Image(systemName: "flame")
                .font(.title2)
                .foregroundStyle(HeatmapTheme.mutedText(for: colorScheme))
            Text("No active streak")
                .font(.system(size: 12))
                .foregroundStyle(HeatmapTheme.mutedText(for: colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Active streak

    private var streakView: some View {
        VStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 32))
                .foregroundStyle(.orange)

            Text("\(entry.streak)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(HeatmapTheme.accentGreen(for: colorScheme))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text("day streak")
                .font(.system(size: 11))
                .foregroundStyle(HeatmapTheme.mutedText(for: colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
