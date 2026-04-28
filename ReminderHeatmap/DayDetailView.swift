import SwiftUI

struct DayDetailView: View {
    @State var day: HeatmapDay
    var allDays: [HeatmapDay] = []

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

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

    private var sortedDays: [HeatmapDay] {
        allDays.sorted { $0.date < $1.date }
    }

    private var currentIndex: Int? {
        sortedDays.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: day.date) })
    }

    private var canGoPrev: Bool {
        guard let idx = currentIndex else { return false }
        return idx > 0
    }

    private var canGoNext: Bool {
        guard let idx = currentIndex else { return false }
        return idx < sortedDays.count - 1
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with navigation + close
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Self.dateFormatter.string(from: day.date))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                        Text("\(day.count) completed")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()

                    if !allDays.isEmpty {
                        HStack(spacing: 4) {
                            Button {
                                if let idx = currentIndex, idx > 0 {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        day = sortedDays[idx - 1]
                                    }
                                }
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(canGoPrev ? .secondary : .quaternary)
                                    .frame(width: 24, height: 24)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(!canGoPrev)

                            Button {
                                if let idx = currentIndex, idx < sortedDays.count - 1 {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        day = sortedDays[idx + 1]
                                    }
                                }
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(canGoNext ? .secondary : .quaternary)
                                    .frame(width: 24, height: 24)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(!canGoNext)
                        }
                    }

                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                if day.reminders.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("A quiet day")
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
                                        .foregroundStyle(HeatmapTheme.accentGreen(for: colorScheme))
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
                        .background(HeatmapTheme.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 12))
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
