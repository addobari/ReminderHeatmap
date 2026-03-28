import SwiftUI

struct TrackersView: View {
    let summaries: [TrackerSummary]

    var body: some View {
        if summaries.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "repeat")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No recurring reminders found")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("Set a reminder to repeat daily to track it here.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(summaries) { summary in
                        TrackerCard(summary: summary)
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Tracker Card

private struct TrackerCard: View {
    let summary: TrackerSummary
    @State private var selectedDay: TrackerDay?

    private static let levelColors: [Color] = [
        Color.white.opacity(0.07),                      // 0
        Color(red: 0.055, green: 0.267, blue: 0.161),   // 1-2
        Color(red: 0.0,   green: 0.427, blue: 0.196),   // 3-4
        Color(red: 0.149, green: 0.651, blue: 0.255),    // 5-6
        Color(red: 0.224, green: 0.827, blue: 0.325),    // 7+
    ]

    private func cellColor(for count: Int) -> Color {
        switch count {
        case 0:    return Self.levelColors[0]
        case 1...2: return Self.levelColors[1]
        case 3...4: return Self.levelColors[2]
        case 5...6: return Self.levelColors[3]
        default:   return Self.levelColors[4]
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.reminderTitle)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        Circle()
                            .fill(ListColorPalette.color(for: summary.calendarColorIndex))
                            .frame(width: 7, height: 7)
                        Text(summary.calendarTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text("\(summary.totalCount)")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(Color(red: 0.224, green: 0.827, blue: 0.325))
                Text("completions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // 30-day heatmap grid
            TrackerHeatmapGrid(
                days: summary.days,
                cellColor: cellColor,
                selectedDay: $selectedDay
            )

            // Inline day detail
            if let day = selectedDay {
                dayDetail(day)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func dayDetail(_ day: TrackerDay) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
                .background(Color.white.opacity(0.08))

            HStack {
                Text(Self.dateFormatter.string(from: day.date))
                    .font(.caption.bold())
                Spacer()
                Text("\(day.count) completed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if day.completions.isEmpty {
                Text("No completions")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(day.completions) { completion in
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption2)
                        Text(Self.timeFormatter.string(from: completion.completionTime))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - 30-Day Heatmap Grid

private struct TrackerHeatmapGrid: View {
    let days: [TrackerDay]
    let cellColor: (Int) -> Color
    @Binding var selectedDay: TrackerDay?

    private let rows = 7
    private let cellSize: CGFloat = 14
    private let cellSpacing: CGFloat = 3

    private static let dayLabels = ["", "M", "", "W", "", "F", ""]

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()

    // Build a grid: columns of 7 rows, Monday-aligned
    private var gridInfo: (columns: [[TrackerDay?]], monthLabels: [(String, Int)]) {
        let cal = Calendar.current
        guard let firstDate = days.first?.date else { return ([], []) }

        // Find the Monday on or before the first date
        let firstWeekday = cal.component(.weekday, from: firstDate) // 1=Sun
        let daysFromMonday = (firstWeekday + 5) % 7
        let gridStart = cal.date(byAdding: .day, value: -daysFromMonday, to: firstDate)!

        // Build lookup
        let lookup: [Date: TrackerDay] = Dictionary(
            days.map { (cal.startOfDay(for: $0.date), $0) },
            uniquingKeysWith: { _, new in new }
        )

        // Figure out how many columns we need
        let lastDate = days.last?.date ?? firstDate
        let totalSpan = cal.dateComponents([.day], from: gridStart, to: lastDate).day! + 1
        let numColumns = (totalSpan + 6) / 7

        var cols: [[TrackerDay?]] = []
        for col in 0..<numColumns {
            var column: [TrackerDay?] = []
            for row in 0..<rows {
                let dayOffset = col * 7 + row
                guard let date = cal.date(byAdding: .day, value: dayOffset, to: gridStart) else {
                    column.append(nil)
                    continue
                }
                let key = cal.startOfDay(for: date)
                column.append(lookup[key])
            }
            cols.append(column)
        }

        // Month labels
        var labels: [(String, Int)] = []
        var lastMonth = -1
        for col in 0..<numColumns {
            guard let date = cal.date(byAdding: .day, value: col * 7, to: gridStart) else { continue }
            let month = cal.component(.month, from: date)
            if month != lastMonth {
                labels.append((Self.monthFormatter.string(from: date), col))
                lastMonth = month
            }
        }

        return (cols, labels)
    }

    var body: some View {
        let info = gridInfo
        let dayLabelWidth: CGFloat = 16
        let numCols = info.columns.count

        VStack(alignment: .leading, spacing: 2) {
            // Month labels
            ZStack(alignment: .leading) {
                Color.clear.frame(height: 12)
                ForEach(info.monthLabels, id: \.1) { label, col in
                    Text(label)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .offset(x: dayLabelWidth + CGFloat(col) * (cellSize + cellSpacing))
                }
            }

            // Grid + day labels
            HStack(alignment: .top, spacing: 2) {
                // Day labels
                VStack(spacing: cellSpacing) {
                    ForEach(0..<rows, id: \.self) { row in
                        Text(Self.dayLabels[row])
                            .font(.system(size: 7, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: dayLabelWidth - 2, height: cellSize, alignment: .trailing)
                    }
                }

                // Cells
                HStack(spacing: cellSpacing) {
                    ForEach(0..<numCols, id: \.self) { col in
                        VStack(spacing: cellSpacing) {
                            ForEach(0..<rows, id: \.self) { row in
                                if let day = info.columns[col][row] {
                                    let isSelected = selectedDay?.date == day.date
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(cellColor(day.count))
                                        .frame(width: cellSize, height: cellSize)
                                        .overlay(
                                            isSelected
                                                ? RoundedRectangle(cornerRadius: 2)
                                                    .strokeBorder(Color.white.opacity(0.6), lineWidth: 1.5)
                                                : nil
                                        )
                                        .onTapGesture {
                                            withAnimation(.easeInOut(duration: 0.15)) {
                                                selectedDay = isSelected ? nil : day
                                            }
                                        }
                                } else {
                                    Color.clear
                                        .frame(width: cellSize, height: cellSize)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
