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
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Medium

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("Trackers")
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                Spacer()
                Text("last 30d")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            let visible = Array(entry.summaries.prefix(5))
            ForEach(visible) { summary in
                trackerRow(summary)
            }

            Spacer(minLength: 0)
        }
        .padding(4)
    }

    // MARK: - Row

    private func trackerRow(_ summary: TrackerSummary) -> some View {
        HStack(spacing: 4) {
            Text(truncate(summary.reminderTitle, max: 20))
                .font(.system(size: 7))
                .foregroundStyle(.primary)
                .frame(width: 62, alignment: .leading)
                .lineLimit(1)

            HStack(spacing: 1) {
                ForEach(summary.days) { day in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(cellColor(for: day.count))
                        .frame(width: 4, height: 4)
                }
            }

            Text("\(summary.totalCount)×")
                .font(.system(size: 7, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .trailing)
        }
    }

    // MARK: - Colors (delegated to HeatmapTheme)

    private func cellColor(for count: Int) -> Color {
        HeatmapTheme.cellColor(for: count, scheme: colorScheme)
    }

    private func truncate(_ text: String, max: Int) -> String {
        if text.count <= max { return text }
        return String(text.prefix(max - 1)) + "…"
    }
}
