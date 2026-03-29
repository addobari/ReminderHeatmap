import SwiftUI
import WidgetKit

struct HeatmapWidgetView: View {
    let entry: HeatmapEntry

    @Environment(\.colorScheme) private var colorScheme

    private static let appURL = URL(string: "reminderheatmap://open")!

    // MARK: - Display state

    private enum DisplayState {
        case noPermission, empty, loaded, stale, error
    }

    private var displayState: DisplayState {
        if !entry.isAuthorized { return .noPermission }
        if entry.isError { return .error }
        if entry.days.allSatisfy({ $0.count == 0 }) { return .empty }
        if Date().timeIntervalSince(entry.date) > 7200 { return .stale }
        return .loaded
    }

    // MARK: - Body

    var body: some View {
        Group {
            switch displayState {
            case .noPermission:
                messageView(
                    icon: "lock.shield",
                    iconColor: .orange,
                    text: "Open app to enable\nReminders access"
                )
            case .error:
                messageView(
                    icon: "exclamationmark.triangle",
                    iconColor: .red,
                    text: "Reminders access removed.\nOpen app to reconnect."
                )
            case .empty:
                emptyGridView
            case .loaded, .stale:
                heatmapView
            }
        }
        .widgetURL(Self.appURL)
    }

    // MARK: - Message states

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

    // MARK: - Empty state (shows grid skeleton + message)

    private var emptyGridView: some View {
        VStack(spacing: 4) {
            heatmapView
            Spacer(minLength: 0)
            Text("Complete your first reminder to get started")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Main heatmap layout

    private var heatmapView: some View {
        VStack(spacing: 0) {
            // Top area: two columns side-by-side
            HStack(alignment: .top, spacing: 0) {
                // LEFT COLUMN: title + big number
                leftColumn
                    .frame(width: 72)

                // RIGHT COLUMN: month labels + grid
                rightColumn
            }

            Spacer(minLength: 2)

            // FOOTER
            footer
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
    }

    // MARK: - Left column

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("REMINDERS")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(HeatmapTheme.mutedText(for: colorScheme))
                .lineLimit(1)
                .padding(.top, 4)

            Spacer(minLength: 0)

            Text("\(entry.weekCount)")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(HeatmapTheme.accentGreen(for: colorScheme))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text("this week")
                .font(.system(size: 9))
                .foregroundStyle(HeatmapTheme.mutedText(for: colorScheme))
                .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 4)
    }

    // MARK: - Right column (grid)

    private static let dayLabels = ["", "Mon", "", "Wed", "", "Fri", ""]
    private static let rows = 7
    private static let columns = 13

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()

    /// Grid cell kinds
    private enum CellKind {
        case data(Int)    // past/today with completion count
        case future       // after today
    }

    private var gridInfo: (cells: [[CellKind]], monthLabels: [(String, Int)]) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        let todayWeekday = cal.component(.weekday, from: today) // 1=Sun
        let daysFromMonday = (todayWeekday + 5) % 7
        let thisMonday = cal.date(byAdding: .day, value: -daysFromMonday, to: today)!
        let gridStart = cal.date(byAdding: .weekOfYear, value: -12, to: thisMonday)!

        let lookup: [Date: Int] = Dictionary(
            entry.days.map { (cal.startOfDay(for: $0.date), $0.count) },
            uniquingKeysWith: { _, new in new }
        )

        var cols: [[CellKind]] = []
        for col in 0..<Self.columns {
            var column: [CellKind] = []
            for row in 0..<Self.rows {
                let dayOffset = col * 7 + row
                guard let date = cal.date(byAdding: .day, value: dayOffset, to: gridStart) else {
                    column.append(.data(0))
                    continue
                }
                let key = cal.startOfDay(for: date)
                if key > today {
                    column.append(.future)
                } else {
                    column.append(.data(lookup[key] ?? 0))
                }
            }
            cols.append(column)
        }

        // Month labels with minimum 2-column gap to prevent collisions
        var labels: [(String, Int)] = []
        var lastMonth = -1
        var lastLabelCol = -3
        for col in 0..<Self.columns {
            guard let date = cal.date(byAdding: .day, value: col * 7, to: gridStart) else { continue }
            let month = cal.component(.month, from: date)
            if month != lastMonth && (col - lastLabelCol) >= 2 {
                labels.append((Self.monthFormatter.string(from: date), col))
                lastMonth = month
                lastLabelCol = col
            }
        }

        return (cols, labels)
    }

    private var rightColumn: some View {
        let info = gridInfo
        let dayLabelWidth: CGFloat = 22
        let gridSpacing: CGFloat = 2

        return GeometryReader { geo in
            // Compute cell size that fits both dimensions as a square
            let monthRowHeight: CGFloat = 12
            let availableWidth = geo.size.width - dayLabelWidth
            let availableHeight = geo.size.height - monthRowHeight - 1
            let cellFromWidth = (availableWidth - gridSpacing * CGFloat(Self.columns - 1)) / CGFloat(Self.columns)
            let cellFromHeight = (availableHeight - gridSpacing * CGFloat(Self.rows - 1)) / CGFloat(Self.rows)
            let cellSize = max(1, min(cellFromWidth, cellFromHeight))

            VStack(alignment: .leading, spacing: 1) {
                // Month labels row
                ZStack(alignment: .leading) {
                    Color.clear.frame(height: monthRowHeight)
                    ForEach(info.monthLabels, id: \.1) { label, col in
                        Text(label)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(HeatmapTheme.mutedText(for: colorScheme))
                            .offset(x: dayLabelWidth + CGFloat(col) * (cellSize + gridSpacing))
                    }
                }

                // Grid with day labels
                HStack(alignment: .top, spacing: 1) {
                    // Day labels
                    VStack(spacing: gridSpacing) {
                        ForEach(0..<Self.rows, id: \.self) { row in
                            Text(Self.dayLabels[row])
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(HeatmapTheme.mutedText(for: colorScheme))
                                .frame(width: dayLabelWidth - 2, height: cellSize, alignment: .trailing)
                        }
                    }

                    // Grid cells
                    HStack(spacing: gridSpacing) {
                        ForEach(0..<Self.columns, id: \.self) { col in
                            VStack(spacing: gridSpacing) {
                                ForEach(0..<Self.rows, id: \.self) { row in
                                    cellView(for: info.cells[col][row], size: cellSize)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cellView(for kind: CellKind, size: CGFloat) -> some View {
        switch kind {
        case .data(let count):
            RoundedRectangle(cornerRadius: 2)
                .fill(HeatmapTheme.cellColor(for: count, scheme: colorScheme))
                .frame(width: size, height: size)
        case .future:
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(HeatmapTheme.futureBorder(for: colorScheme), lineWidth: 1)
                )
                .frame(width: size, height: size)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 0) {
            HStack(spacing: 2) {
                Text("Less")
                    .font(.system(size: 7))
                    .foregroundStyle(HeatmapTheme.faintText(for: colorScheme))

                ForEach(0..<HeatmapTheme.levelColors(for: colorScheme).count, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(HeatmapTheme.levelColors(for: colorScheme)[i])
                        .frame(width: 7, height: 7)
                }

                Text("More")
                    .font(.system(size: 7))
                    .foregroundStyle(HeatmapTheme.faintText(for: colorScheme))

                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 1.5)
                            .strokeBorder(HeatmapTheme.futureBorder(for: colorScheme), lineWidth: 1)
                    )
                    .frame(width: 7, height: 7)
                    .padding(.leading, 2)

                Text("Future")
                    .font(.system(size: 7))
                    .foregroundStyle(HeatmapTheme.faintText(for: colorScheme))
            }

            Spacer()

            Text("Last 3 months")
                .font(.system(size: 8))
                .foregroundStyle(displayState == .stale ? .orange : HeatmapTheme.faintText(for: colorScheme))
        }
        .padding(.horizontal, 4)
    }
}
