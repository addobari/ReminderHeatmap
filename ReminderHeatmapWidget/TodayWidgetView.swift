import SwiftUI
import WidgetKit

struct TodayWidgetView: View {
    let entry: TodayEntry

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
            } else {
                progressView
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

    // MARK: - Progress ring

    private var fillFraction: Double {
        guard entry.dailyAverage > 0 else { return 0 }
        return min(Double(entry.todayCount) / entry.dailyAverage, 1.0)
    }

    private var progressView: some View {
        VStack(spacing: 6) {
            ZStack {
                // Track
                Circle()
                    .stroke(HeatmapTheme.emptyColor(for: colorScheme), lineWidth: 8)

                // Fill
                Circle()
                    .trim(from: 0, to: fillFraction)
                    .stroke(
                        HeatmapTheme.accentGreen(for: colorScheme),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                // Center number
                Text("\(entry.todayCount)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            .frame(width: 80, height: 80)

            // Average label
            Text("of \(String(format: "%.1f", entry.dailyAverage)) avg")
                .font(.system(size: 11))
                .foregroundStyle(HeatmapTheme.mutedText(for: colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
