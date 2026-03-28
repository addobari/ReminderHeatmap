import SwiftUI

struct HeatmapGridView: View {
    let days: [HeatmapDay]
    let columns: Int
    var compact: Bool = false
    var enableTooltip: Bool = false
    var onDayTap: ((HeatmapDay) -> Void)?

    private let rows = 7

    private var cellSize: CGFloat { compact ? 9 : 12 }
    private var cellSpacing: CGFloat { compact ? 2 : 3 }

    private static let dayLabels = ["", "Mon", "", "Wed", "", "Fri", ""]
    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()

    // GitHub green palette
    private static let greenLevels: [Color] = [
        Color(red: 0.61, green: 0.91, blue: 0.66),
        Color(red: 0.25, green: 0.77, blue: 0.39),
        Color(red: 0.19, green: 0.63, blue: 0.31),
        Color(red: 0.13, green: 0.43, blue: 0.22),
    ]

    private static let emptyLight = Color(red: 0.92, green: 0.93, blue: 0.94)
    private static let emptyDark  = Color(red: 0.18, green: 0.20, blue: 0.23)

    @Environment(\.colorScheme) private var colorScheme

    private var emptyColor: Color {
        colorScheme == .dark ? Self.emptyDark : Self.emptyLight
    }

    private func color(for count: Int) -> Color {
        switch count {
        case 0: return emptyColor
        case 1...2: return Self.greenLevels[0]
        case 3...4: return Self.greenLevels[1]
        case 5...6: return Self.greenLevels[2]
        default: return Self.greenLevels[3]
        }
    }

    // MARK: - Grid Layout

    private var grid: [[HeatmapDay?]] {
        let calendar = Calendar.current
        guard let earliest = days.first?.date else {
            return Array(repeating: Array(repeating: nil, count: rows), count: columns)
        }

        let lookup: [Date: HeatmapDay] = Dictionary(
            days.map { (calendar.startOfDay(for: $0.date), $0) },
            uniquingKeysWith: { _, new in new }
        )

        let earliestWeekday = calendar.component(.weekday, from: earliest)
        let gridStart = calendar.date(byAdding: .day, value: -(earliestWeekday - 1), to: earliest)!

        var cols: [[HeatmapDay?]] = []
        for col in 0..<columns {
            var column: [HeatmapDay?] = []
            for row in 0..<rows {
                let dayOffset = col * 7 + row
                guard let date = calendar.date(byAdding: .day, value: dayOffset, to: gridStart) else {
                    column.append(nil)
                    continue
                }
                if date > Date() {
                    column.append(nil)
                } else {
                    let key = calendar.startOfDay(for: date)
                    column.append(lookup[key] ?? HeatmapDay(date: key, count: 0))
                }
            }
            cols.append(column)
        }
        return cols
    }

    private var monthLabels: [(String, Int)] {
        let calendar = Calendar.current
        guard let earliest = days.first?.date else { return [] }
        let earliestWeekday = calendar.component(.weekday, from: earliest)
        let gridStart = calendar.date(byAdding: .day, value: -(earliestWeekday - 1), to: earliest)!

        var labels: [(String, Int)] = []
        var lastMonth = -1
        var lastLabelCol = -3
        for col in 0..<columns {
            guard let date = calendar.date(byAdding: .day, value: col * 7, to: gridStart) else { continue }
            let month = calendar.component(.month, from: date)
            if month != lastMonth && (col - lastLabelCol) >= 2 {
                labels.append((Self.monthFormatter.string(from: date), col))
                lastMonth = month
                lastLabelCol = col
            }
        }
        return labels
    }

    // MARK: - Body

    var body: some View {
        let gridData = grid
        let labels = monthLabels
        let labelColumnWidth: CGFloat = compact ? 14 : 20
        let totalWidth = CGFloat(columns) * (cellSize + cellSpacing)
        let monthFontSize: CGFloat = compact ? 7 : 9
        let dayFontSize: CGFloat = compact ? 6 : 8

        VStack(alignment: .leading, spacing: compact ? 1 : 2) {
            // Month labels
            ZStack(alignment: .leading) {
                Color.clear.frame(height: compact ? 10 : 14)
                ForEach(labels, id: \.1) { label, col in
                    Text(label)
                        .font(.system(size: monthFontSize, weight: .medium))
                        .foregroundStyle(.secondary)
                        .offset(x: CGFloat(col) * (cellSize + cellSpacing) + labelColumnWidth)
                }
            }
            .frame(width: totalWidth + labelColumnWidth, alignment: .leading)

            // Grid with day labels
            HStack(alignment: .top, spacing: compact ? 1 : 2) {
                VStack(alignment: .trailing, spacing: cellSpacing) {
                    ForEach(0..<rows, id: \.self) { row in
                        Text(Self.dayLabels[row])
                            .font(.system(size: dayFontSize, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: labelColumnWidth - 2, height: cellSize, alignment: .trailing)
                    }
                }

                HStack(spacing: cellSpacing) {
                    ForEach(0..<gridData.count, id: \.self) { col in
                        VStack(spacing: cellSpacing) {
                            ForEach(0..<rows, id: \.self) { row in
                                if let day = gridData[col][row] {
                                    if enableTooltip {
                                        TooltipCell(day: day, size: cellSize, color: color(for: day.count), row: row, onTap: onDayTap)
                                    } else {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(color(for: day.count))
                                            .frame(width: cellSize, height: cellSize)
                                    }
                                } else {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.clear)
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

// MARK: - Tooltip Cell (App only)

private struct TooltipCell: View {
    let day: HeatmapDay
    let size: CGFloat
    let color: Color
    let row: Int
    var onTap: ((HeatmapDay) -> Void)?

    @State private var isHovering = false
    @State private var showTooltip = false
    @State private var hoverTask: Task<Void, Never>?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: size, height: size)
            .onHover { hovering in
                isHovering = hovering
                hoverTask?.cancel()
                if hovering {
                    hoverTask = Task {
                        try? await Task.sleep(nanoseconds: 80_000_000)
                        guard !Task.isCancelled else { return }
                        showTooltip = true
                    }
                } else {
                    showTooltip = false
                }
            }
            .onTapGesture {
                onTap?(day)
            }
            .popover(isPresented: $showTooltip, arrowEdge: row < 4 ? .top : .bottom) {
                tooltipContent
                    .padding(10)
                    .frame(minWidth: 160, maxWidth: 220)
            }
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(day.date)
    }

    @ViewBuilder
    private var tooltipContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Self.dateFormatter.string(from: day.date))
                .font(.caption.bold())

            if day.count == 0 {
                Text("No completions")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text(isToday ? "\(day.count) completed so far today" : "\(day.count) completed")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                let items = day.reminders.prefix(8)
                ForEach(Array(items.enumerated()), id: \.offset) { _, reminder in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(ListColorPalette.color(for: reminder.listColorIndex))
                            .frame(width: 6, height: 6)
                        Text(truncate(reminder.title, max: 32))
                            .font(.caption2)
                        Spacer()
                        Text(reminder.listName)
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                    }
                }

                if day.reminders.count > 8 {
                    Text("…and \(day.reminders.count - 8) more")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func truncate(_ text: String, max: Int) -> String {
        if text.count <= max { return text }
        return String(text.prefix(max - 1)) + "…"
    }
}
