import SwiftUI

struct ContentView: View {
    @ObservedObject var manager: ReminderManager
    @State private var selectedDay: HeatmapDay?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !manager.isAuthorized {
                    permissionSection
                }

                if manager.isAuthorized {
                    // 1. Stat cards row
                    HStack(spacing: 12) {
                        StatCard(title: "Streak", value: "\(manager.streak)d", accent: manager.streak > 0)
                        StatCard(title: "This Week", value: "\(manager.weekCount)")
                        StatCard(title: "Today", value: "\(manager.todayCount)")
                    }
                    .padding(.horizontal)

                    // 2. Today section
                    todaySection
                        .padding(.horizontal)

                    // 3. Heatmap card
                    heatmapCard
                        .padding(.horizontal)

                    // Last updated footer
                    HStack {
                        Text("Last updated: now")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Reminder Heatmap")
        .navigationDestination(item: $selectedDay) { day in
            DayDetailView(day: day)
        }
    }

    // MARK: - Today Section

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("TODAY")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(manager.todayCount) completed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            if manager.todayReminders.isEmpty {
                Text("Nothing completed yet today")
                    .font(.callout)
                    .foregroundStyle(Color.white.opacity(0.35))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(Array(manager.todayReminders.enumerated()), id: \.element.id) { index, reminder in
                    if index > 0 {
                        Divider()
                            .background(Color.white.opacity(0.06))
                            .padding(.leading, 14)
                    }
                    HStack(spacing: 8) {
                        Circle()
                            .fill(ListColorPalette.color(for: reminder.listColorIndex))
                            .frame(width: 7, height: 7)
                        Text(reminder.title)
                            .font(.callout)
                            .lineLimit(1)
                        Spacer()
                        Text(reminder.listName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(Self.timeFormatter.string(from: reminder.completionTime))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                }
            }
        }
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Heatmap Card

    private var heatmapCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: year switcher + legend
            HStack {
                yearSwitcher
                Spacer()
                legendBar
            }

            // Full-year grid
            YearHeatmapGrid(
                days: manager.yearDays,
                year: manager.selectedYear,
                onDayTap: { day in selectedDay = day }
            )

            // Stats row
            Divider()
                .background(Color.white.opacity(0.08))

            HStack(spacing: 0) {
                yearStat(title: "Best day", value: yearBestDay)
                yearStat(title: "Active days", value: yearActiveDays)
                yearStat(title: "Daily avg", value: yearDailyAvg)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Year Switcher

    private var yearSwitcher: some View {
        HStack(spacing: 8) {
            Button {
                Task { await manager.switchYear(to: manager.selectedYear - 1) }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(canGoBack ? .secondary : .quaternary)
            }
            .buttonStyle(.plain)
            .disabled(!canGoBack)

            Text("\(manager.selectedYear, format: .number.grouping(.never))")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()

            Button {
                Task { await manager.switchYear(to: manager.selectedYear + 1) }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(canGoForward ? .secondary : .quaternary)
            }
            .buttonStyle(.plain)
            .disabled(!canGoForward)
        }
    }

    private var canGoBack: Bool { manager.selectedYear > manager.earliestYear }
    private var canGoForward: Bool { manager.selectedYear < manager.currentYear }

    // MARK: - Legend

    private var legendBar: some View {
        HStack(spacing: 3) {
            Text("Less")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
            ForEach(Array(YearHeatmapGrid.levelColors.enumerated()), id: \.offset) { _, color in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 9, height: 9)
            }
            Text("More")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)

            RoundedRectangle(cornerRadius: 2)
                .fill(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
                .frame(width: 9, height: 9)
                .padding(.leading, 4)
            Text("Future")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Year Stats

    private var pastDays: [HeatmapDay] {
        let today = Calendar.current.startOfDay(for: Date())
        return manager.yearDays.filter { $0.date <= today }
    }

    private var yearBestDay: String {
        let best = pastDays.map(\.count).max() ?? 0
        return best > 0 ? "\(best)" : "—"
    }

    private var yearActiveDays: String {
        let active = pastDays.filter { $0.count > 0 }.count
        return active > 0 ? "\(active)" : "—"
    }

    private var yearDailyAvg: String {
        let active = pastDays.filter { $0.count > 0 }
        guard !active.isEmpty else { return "—" }
        let avg = Double(active.reduce(0) { $0 + $1.count }) / Double(active.count)
        return String(format: "%.1f", avg)
    }

    private func yearStat(title: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.callout.bold().monospacedDigit())
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Permission Section

    private var permissionSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text("Reminders Access Needed")
                .font(.headline)

            Text("ReminderHeatmap reads your completed reminders to build the heatmap. No data leaves your Mac.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task { await manager.requestAccess() }
            } label: {
                Text("Grant Access")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
                    .fontWeight(.semibold)
            }

            Button {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Text("Open System Settings")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    var accent: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(accent ? .green : .primary)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Full-Year Heatmap Grid

struct YearHeatmapGrid: View {
    let days: [HeatmapDay]
    let year: Int
    var onDayTap: ((HeatmapDay) -> Void)?

    private let rows = 7
    private let cellSize: CGFloat = 11
    private let cellSpacing: CGFloat = 3

    static let levelColors: [Color] = [
        Color(red: 0.13, green: 0.15, blue: 0.18),  // 0: #21262d
        Color(red: 0.055, green: 0.267, blue: 0.161), // 1-2: #0e4429
        Color(red: 0.0, green: 0.427, blue: 0.196),   // 3-4: #006d32
        Color(red: 0.149, green: 0.651, blue: 0.255),  // 5-6: #26a641
        Color(red: 0.224, green: 0.827, blue: 0.325),   // 7+: #39d353
    ]

    private static let dayLabels = ["", "Mon", "", "Wed", "", "Fri", ""]

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()

    private func cellColor(for count: Int) -> Color {
        switch count {
        case 0: return Self.levelColors[0]
        case 1...2: return Self.levelColors[1]
        case 3...4: return Self.levelColors[2]
        case 5...6: return Self.levelColors[3]
        default: return Self.levelColors[4]
        }
    }

    // MARK: - Grid computation

    /// Each cell is one of: .data(HeatmapDay), .future(Date), .invisible
    private enum CellKind {
        case data(HeatmapDay)
        case future(Date)
        case invisible
    }

    private var gridInfo: (columns: Int, cells: [[CellKind]], monthLabels: [(String, Int)]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let janFirst = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let decThirtyFirst = calendar.date(from: DateComponents(year: year, month: 12, day: 31)) else {
            return (0, [], [])
        }

        // Grid starts on the Sunday of the week containing Jan 1
        let janFirstWeekday = calendar.component(.weekday, from: janFirst) // 1=Sun
        let gridStart = calendar.date(byAdding: .day, value: -(janFirstWeekday - 1), to: janFirst)!

        // Grid ends on the Saturday of the week containing Dec 31
        let decWeekday = calendar.component(.weekday, from: decThirtyFirst) // 1=Sun
        let gridEnd = calendar.date(byAdding: .day, value: 7 - decWeekday, to: decThirtyFirst)!

        let totalDays = calendar.dateComponents([.day], from: gridStart, to: gridEnd).day! + 1
        let numColumns = (totalDays + 6) / 7

        // Build lookup
        let lookup: [Date: HeatmapDay] = Dictionary(
            days.map { (calendar.startOfDay(for: $0.date), $0) },
            uniquingKeysWith: { _, new in new }
        )

        var cols: [[CellKind]] = []
        for col in 0..<numColumns {
            var column: [CellKind] = []
            for row in 0..<rows {
                let dayOffset = col * 7 + row
                guard let date = calendar.date(byAdding: .day, value: dayOffset, to: gridStart) else {
                    column.append(.invisible)
                    continue
                }
                let key = calendar.startOfDay(for: date)

                if key < janFirst || key > decThirtyFirst {
                    // Outside the year boundary
                    column.append(.invisible)
                } else if key > today {
                    // Future cell
                    column.append(.future(key))
                } else {
                    // Data cell (past or today)
                    let day = lookup[key] ?? HeatmapDay(date: key, count: 0)
                    column.append(.data(day))
                }
            }
            cols.append(column)
        }

        // Month labels
        var labels: [(String, Int)] = []
        var lastMonth = -1
        for col in 0..<numColumns {
            guard let date = calendar.date(byAdding: .day, value: col * 7, to: gridStart) else { continue }
            let dateMonth = calendar.component(.month, from: date)
            let dateYear = calendar.component(.year, from: date)
            if dateYear == year && dateMonth != lastMonth {
                labels.append((Self.monthFormatter.string(from: date), col))
                lastMonth = dateMonth
            }
        }

        return (numColumns, cols, labels)
    }

    // MARK: - Body

    var body: some View {
        let info = gridInfo
        let labelColumnWidth: CGFloat = 22

        VStack(alignment: .leading, spacing: 2) {
            // Month labels
            ZStack(alignment: .leading) {
                Color.clear.frame(height: 14)
                ForEach(info.monthLabels, id: \.1) { label, col in
                    Text(label)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .offset(x: CGFloat(col) * (cellSize + cellSpacing) + labelColumnWidth)
                }
            }
            .frame(width: CGFloat(info.columns) * (cellSize + cellSpacing) + labelColumnWidth, alignment: .leading)

            // Grid with day labels
            HStack(alignment: .top, spacing: 2) {
                // Day labels column
                VStack(alignment: .trailing, spacing: cellSpacing) {
                    ForEach(0..<rows, id: \.self) { row in
                        Text(Self.dayLabels[row])
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: labelColumnWidth - 2, height: cellSize, alignment: .trailing)
                    }
                }

                // Cells
                HStack(spacing: cellSpacing) {
                    ForEach(0..<info.columns, id: \.self) { col in
                        VStack(spacing: cellSpacing) {
                            ForEach(0..<rows, id: \.self) { row in
                                cellView(for: info.cells[col][row])
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cellView(for kind: CellKind) -> some View {
        switch kind {
        case .data(let day):
            RoundedRectangle(cornerRadius: 2)
                .fill(cellColor(for: day.count))
                .frame(width: cellSize, height: cellSize)
                .onTapGesture { onDayTap?(day) }
        case .future:
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
                .frame(width: cellSize, height: cellSize)
        case .invisible:
            Color.clear
                .frame(width: cellSize, height: cellSize)
        }
    }
}
