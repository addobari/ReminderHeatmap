import SwiftUI

struct DayDetailView: View {
    let day: HeatmapDay

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .full
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(Self.dateFormatter.string(from: day.date))
                        .font(.title3.bold())
                    Text("\(day.count) completed")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if day.reminders.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No completions this day")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    // Group by list
                    ForEach(groupedByList, id: \.listName) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(ListColorPalette.color(for: group.colorIndex))
                                    .frame(width: 8, height: 8)
                                Text(group.listName)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.secondary)
                                Text("(\(group.reminders.count))")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }

                            ForEach(group.reminders) { reminder in
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.caption)
                                    Text(reminder.title)
                                        .font(.body)
                                    Spacer()
                                    Text(Self.timeFormatter.string(from: reminder.completionTime))
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                        .monospacedDigit()
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Day Detail")
    }

    private struct ReminderGroup {
        let listName: String
        let colorIndex: Int
        let reminders: [CompletedReminder]
    }

    private var groupedByList: [ReminderGroup] {
        var groups: [String: (colorIndex: Int, reminders: [CompletedReminder])] = [:]
        for reminder in day.reminders {
            var entry = groups[reminder.listName] ?? (colorIndex: reminder.listColorIndex, reminders: [])
            entry.reminders.append(reminder)
            groups[reminder.listName] = entry
        }
        return groups
            .map { ReminderGroup(listName: $0.key, colorIndex: $0.value.colorIndex, reminders: $0.value.reminders.sorted { $0.completionTime < $1.completionTime }) }
            .sorted { $0.listName < $1.listName }
    }
}
