import SwiftUI
import WidgetKit

struct TrackerWidgetView: View {
    let entry: TrackerEntry

    @Environment(\.colorScheme) private var colorScheme

    private static let appURL = URL(string: "reminderheatmap://trackers")!

    var body: some View {
        Group {
            if !entry.isAuthorized {
                permissionView
            } else if entry.summaries.isEmpty {
                emptyView
            } else {
                mediumView
            }
        }
        .widgetURL(Self.appURL)
    }

    // MARK: - States

    private var permissionView: some View {
        VStack(spacing: 8) {
            Image(systemName: "checklist")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Open app to grant\nReminders access")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "repeat")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No recurring reminders found.\nSet a reminder to repeat daily\nto track it here.")
                .font(.system(size: 11))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Medium

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                Text("Trackers")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("Last 30 days")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 10)

            // Rows
            let visible = Array(entry.summaries.prefix(4))
            VStack(spacing: 8) {
                ForEach(visible) { summary in
                    trackerRow(summary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
    }

    // MARK: - Row

    private func trackerRow(_ summary: TrackerSummary) -> some View {
        let activeDays = summary.days.filter { $0.count > 0 }.count
        let totalDays = summary.days.count
        let ratio = totalDays > 0 ? CGFloat(activeDays) / CGFloat(totalDays) : 0

        return VStack(alignment: .leading, spacing: 4) {
            // Top line: name + count
            HStack(alignment: .firstTextBaseline) {
                Text(summary.reminderTitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("\(activeDays)/\(totalDays)")
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(HeatmapTheme.cellColor(for: 0, scheme: colorScheme))
                        .frame(height: 5)

                    // Fill
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(barColor(for: ratio))
                        .frame(width: geo.size.width * ratio, height: 5)
                }
            }
            .frame(height: 5)
        }
    }

    // MARK: - Colors

    private func barColor(for ratio: CGFloat) -> Color {
        // Map completion ratio to the green scale
        switch ratio {
        case ..<0.15:  return HeatmapTheme.levelColors(for: colorScheme)[1]
        case ..<0.35:  return HeatmapTheme.levelColors(for: colorScheme)[2]
        case ..<0.65:  return HeatmapTheme.levelColors(for: colorScheme)[3]
        default:       return HeatmapTheme.levelColors(for: colorScheme)[4]
        }
    }
}
