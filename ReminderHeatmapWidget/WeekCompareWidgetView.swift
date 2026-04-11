import SwiftUI
import WidgetKit

struct WeekCompareWidgetView: View {
    let entry: WeekCompareEntry

    @Environment(\.colorScheme) private var colorScheme

    private static let appURL = URL(string: "reminderheatmap://open")!
    private static let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        Group {
            if !entry.isAuthorized {
                messageView(
                    icon: "lock.shield",
                    iconColor: .orange,
                    text: "Open app to enable\nReminders access"
                )
            } else {
                chartView
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

    // MARK: - Chart

    private var maxValue: Int {
        max((entry.thisWeek + entry.lastWeek).max() ?? 1, 1)
    }

    private var chartView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                Text("WEEKLY")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : Color.black.opacity(0.5))
                Spacer()
                Text("This vs last week")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 10)

            // Bar chart
            GeometryReader { geo in
                let barGroupWidth = geo.size.width / 7
                let barWidth = max(barGroupWidth * 0.3, 4)
                let spacing: CGFloat = 2
                let chartHeight = geo.size.height - 16 // reserve space for day labels

                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { day in
                        VStack(spacing: 2) {
                            // Bars
                            HStack(alignment: .bottom, spacing: spacing) {
                                // Last week bar
                                barView(
                                    value: entry.lastWeek[day],
                                    maxValue: maxValue,
                                    height: chartHeight,
                                    width: barWidth,
                                    color: HeatmapTheme.emptyColor(for: colorScheme)
                                )

                                // This week bar
                                barView(
                                    value: entry.thisWeek[day],
                                    maxValue: maxValue,
                                    height: chartHeight,
                                    width: barWidth,
                                    color: HeatmapTheme.accentGreen(for: colorScheme)
                                )
                            }
                            .frame(height: chartHeight)

                            // Day label
                            Text(Self.dayLabels[day])
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(HeatmapTheme.mutedText(for: colorScheme))
                                .frame(height: 14)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
    }

    // MARK: - Bar

    private func barView(value: Int, maxValue: Int, height: CGFloat, width: CGFloat, color: Color) -> some View {
        let fraction = CGFloat(value) / CGFloat(maxValue)
        let barHeight = max(fraction * height, value > 0 ? 3 : 0)

        return RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: width, height: barHeight)
    }
}
