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
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("Trackers")
                    .font(.callout.bold())
                    .foregroundStyle(.primary)
                Spacer()
                Text("Last 30 days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            let visible = Array(entry.summaries.prefix(4))
            ForEach(visible) { summary in
                trackerRow(summary)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
    }

    // MARK: - Row

    private func trackerRow(_ summary: TrackerSummary) -> some View {
        HStack(spacing: 6) {
            Text(summary.reminderTitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 76, alignment: .leading)
                .lineLimit(1)

            HStack(spacing: 1.5) {
                ForEach(summary.days) { day in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(cellColor(for: day.count))
                        .frame(width: 6, height: 6)
                }
            }

            Text("\(summary.totalCount)")
                .font(.system(size: 10, weight: .bold).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
        }
    }

    // MARK: - Colors

    private func cellColor(for count: Int) -> Color {
        HeatmapTheme.cellColor(for: count, scheme: colorScheme)
    }
}
