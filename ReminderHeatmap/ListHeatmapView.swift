import SwiftUI

struct ListHeatmapView: View {
    let listName: String
    let colorIndex: Int
    let days: [HeatmapDay]
    let allLists: [InsightsData.ListRanking]

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var compareList: String?

    private let cellSize: CGFloat = 12
    private let cellSpacing: CGFloat = 2
    private let rows = 7

    private static let dayLabels = ["", "Mon", "", "Wed", "", "Fri", ""]

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()

    // MARK: - Filtered days

    private func filteredDays(for name: String) -> [HeatmapDay] {
        days.map { day in
            let filtered = day.reminders.filter { $0.listName == name }
            return HeatmapDay(date: day.date, count: filtered.count, reminders: filtered)
        }
    }

    private var primaryDays: [HeatmapDay] { filteredDays(for: listName) }

    private var compareDays: [HeatmapDay]? {
        guard let name = compareList else { return nil }
        return filteredDays(for: name)
    }

    // MARK: - Stats

    private func stats(for heatmapDays: [HeatmapDay]) -> (total: Int, activeDays: Int, bestDay: Int, avg: Double) {
        let total = heatmapDays.reduce(0) { $0 + $1.count }
        let active = heatmapDays.filter { $0.count > 0 }.count
        let best = heatmapDays.map(\.count).max() ?? 0
        let avg = active > 0 ? Double(total) / Double(active) : 0
        return (total, active, best, avg)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                comparePicker
                heatmapSection(title: listName, colorIdx: colorIndex, heatmapDays: primaryDays)

                if let name = compareList, let cDays = compareDays {
                    let cIdx = allLists.first(where: { $0.name == name })?.colorIndex ?? 0
                    Divider()
                    heatmapSection(title: name, colorIdx: cIdx, heatmapDays: cDays)
                }
            }
            .padding()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            HStack(spacing: 8) {
                Circle()
                    .fill(ListColorPalette.color(for: colorIndex))
                    .frame(width: 10, height: 10)
                Text(listName)
                    .font(.title3.bold())
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Compare Picker

    private var comparePicker: some View {
        HStack(spacing: 8) {
            Text("Compare with:")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("", selection: $compareList) {
                Text("None").tag(String?.none)
                ForEach(allLists.filter { $0.name != listName }) { list in
                    HStack {
                        Text(list.name)
                    }
                    .tag(Optional(list.name))
                }
            }
            .labelsHidden()
            .frame(maxWidth: 200)
        }
    }

    // MARK: - Heatmap Section

    private func heatmapSection(title: String, colorIdx: Int, heatmapDays: [HeatmapDay]) -> some View {
        let s = stats(for: heatmapDays)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(ListColorPalette.color(for: colorIdx))
                        .frame(width: 7, height: 7)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                }
                Spacer()
                Text("\(s.total) completions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Stats row
            HStack(spacing: 16) {
                miniStat(label: "Active days", value: "\(s.activeDays)")
                miniStat(label: "Best day", value: "\(s.bestDay)")
                miniStat(label: "Daily avg", value: String(format: "%.1f", s.avg))
            }

            // Grid
            listGrid(heatmapDays: heatmapDays)
        }
        .padding(14)
        .background(HeatmapTheme.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 12))
    }

    private func miniStat(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.callout.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Grid

    private func listGrid(heatmapDays: [HeatmapDay]) -> some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let sorted = heatmapDays.sorted { $0.date < $1.date }
        guard let firstDate = sorted.first?.date else {
            return AnyView(Text("No data").font(.caption).foregroundStyle(.tertiary))
        }

        let firstWeekday = calendar.component(.weekday, from: firstDate)
        let gridStart = calendar.date(byAdding: .day, value: -(firstWeekday - 1), to: firstDate)!
        let lastDate = sorted.last?.date ?? firstDate
        let totalSpan = calendar.dateComponents([.day], from: gridStart, to: lastDate).day! + 1
        let numColumns = (totalSpan + 6) / 7

        let lookup: [Date: Int] = Dictionary(
            sorted.map { (calendar.startOfDay(for: $0.date), $0.count) },
            uniquingKeysWith: { _, new in new }
        )

        // Month labels
        var monthLabels: [(String, Int)] = []
        var lastMonth = -1
        for col in 0..<numColumns {
            guard let date = calendar.date(byAdding: .day, value: col * 7, to: gridStart) else { continue }
            let month = calendar.component(.month, from: date)
            if month != lastMonth {
                monthLabels.append((Self.monthFormatter.string(from: date), col))
                lastMonth = month
            }
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 2) {
                // Month labels
                ZStack(alignment: .leading) {
                    Color.clear.frame(height: 12)
                    ForEach(monthLabels, id: \.1) { label, col in
                        Text(label)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.secondary)
                            .offset(x: 20 + CGFloat(col) * (cellSize + cellSpacing))
                    }
                }

                HStack(alignment: .top, spacing: 2) {
                    // Day labels
                    VStack(spacing: cellSpacing) {
                        ForEach(0..<rows, id: \.self) { row in
                            Text(Self.dayLabels[row])
                                .font(.system(size: 7, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 18, height: cellSize, alignment: .trailing)
                        }
                    }

                    // Cells
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: cellSpacing) {
                            ForEach(0..<numColumns, id: \.self) { col in
                                VStack(spacing: cellSpacing) {
                                    ForEach(0..<rows, id: \.self) { row in
                                        let dayOffset = col * 7 + row
                                        let date = calendar.date(byAdding: .day, value: dayOffset, to: gridStart)
                                        let key = date.map { calendar.startOfDay(for: $0) }
                                        let count = key.flatMap { lookup[$0] } ?? 0
                                        let isFuture = key.map { $0 > today } ?? true

                                        if isFuture {
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(Color.clear)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 2)
                                                        .strokeBorder(HeatmapTheme.futureBorder(for: colorScheme), lineWidth: 1)
                                                )
                                                .frame(width: cellSize, height: cellSize)
                                        } else {
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(HeatmapTheme.cellColor(for: count, scheme: colorScheme))
                                                .frame(width: cellSize, height: cellSize)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        )
    }
}
