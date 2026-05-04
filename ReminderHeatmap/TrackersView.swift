import SwiftUI

struct TrackersView: View {
    let summaries: [TrackerSummary]
    var milestones: [Milestone] = []
    var manager: ReminderManager? = nil

    @AppStorage("trackerSortMode") private var trackerSortModeRaw: String = TrackerSortMode.count.rawValue
    @Environment(\.colorScheme) private var colorScheme
    @State private var editingReminder: ReminderManager.EditableReminder?
    @State private var deleteConfirmation: ReminderManager.EditableReminder?

    private var sortMode: TrackerSortMode {
        TrackerSortMode(rawValue: trackerSortModeRaw) ?? .count
    }

    private var sortedSummaries: [TrackerSummary] {
        summaries.sorted(by: sortMode)
    }

    private var dormantTrackers: [DormantTracker] {
        DormantDetector.detect(summaries: summaries)
    }

    private func linkedGoals(for summary: TrackerSummary) -> [Milestone] {
        milestones.filter { milestone in
            milestone.linkedReminders.contains(where: {
                $0.calendarIdentifier == summary.calendarIdentifier && $0.reminderTitle == summary.reminderTitle
            })
        }
    }

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
                    sortHeader
                    dormantNudgesSection
                    ForEach(sortedSummaries) { summary in
                        TrackerCard(
                            summary: summary,
                            linkedGoals: linkedGoals(for: summary),
                            onMarkTodayDone: manager.map { mgr -> () -> Void in
                                {
                                    Task {
                                        await mgr.completeReminder(
                                            title: summary.reminderTitle,
                                            calendarIdentifier: summary.calendarIdentifier
                                        )
                                    }
                                }
                            },
                            onEdit: manager.map { mgr -> () -> Void in
                                {
                                    Task {
                                        if let editable = await mgr.loadEditableReminder(
                                            title: summary.reminderTitle,
                                            calendarIdentifier: summary.calendarIdentifier
                                        ) {
                                            editingReminder = editable
                                        }
                                    }
                                }
                            },
                            onDelete: manager.map { mgr -> () -> Void in
                                {
                                    Task {
                                        if let editable = await mgr.loadEditableReminder(
                                            title: summary.reminderTitle,
                                            calendarIdentifier: summary.calendarIdentifier
                                        ) {
                                            deleteConfirmation = editable
                                        }
                                    }
                                }
                            }
                        )
                    }
                }
                .padding()
            }
            .sheet(item: $editingReminder) { editing in
                if let mgr = manager {
                    NewReminderView(manager: mgr, editing: editing)
                }
            }
            .alert(item: $deleteConfirmation) { target in
                Alert(
                    title: Text("Delete \"\(target.title)\"?"),
                    message: Text("This removes it from Apple Reminders everywhere it syncs."),
                    primaryButton: .destructive(Text("Delete")) {
                        if let mgr = manager {
                            Task { await mgr.deleteReminder(reminderID: target.id) }
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }

    // MARK: - Sort header

    private var dateWindowString: String {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let start = cal.date(byAdding: .day, value: -29, to: today) else { return "" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "\(f.string(from: start)) – \(f.string(from: today))"
    }

    private var sortHeader: some View {
        HStack(spacing: 10) {
            Text("\(summaries.count) tracker\(summaries.count == 1 ? "" : "s")")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
                .tracking(0.5)

            Text(dateWindowString)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(
                    HeatmapTheme.cardBackground(for: colorScheme),
                    in: Capsule()
                )

            Spacer()
            Menu {
                ForEach(TrackerSortMode.allCases) { mode in
                    Button {
                        trackerSortModeRaw = mode.rawValue
                    } label: {
                        Label(mode.label, systemImage: mode.icon)
                        if mode == sortMode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 9, weight: .medium))
                    Text(sortMode.label)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    // MARK: - Dormant nudges

    @ViewBuilder
    private var dormantNudgesSection: some View {
        let dormants = dormantTrackers.prefix(2)
        if !dormants.isEmpty {
            VStack(spacing: 10) {
                ForEach(Array(dormants), id: \.id) { dormant in
                    NarrativeCard(
                        icon: "moon.zzz.fill",
                        iconColor: HeatmapTheme.accentWarm(for: colorScheme),
                        title: "Why did you stop \(dormant.summary.reminderTitle)?",
                        subtitle: "\(dormant.daysSilent) days silent · was active \(dormant.priorActiveDays) of last 30",
                        bullets: [
                            NarrativeBullet(
                                icon: "clock.arrow.circlepath",
                                iconColor: .orange,
                                text: "You built \(dormant.priorActiveDays) days of momentum here"
                            ),
                            NarrativeBullet(
                                icon: "arrow.right",
                                iconColor: HeatmapTheme.accentGreen(for: colorScheme),
                                text: "One small completion today restarts the streak"
                            )
                        ],
                        accentColor: HeatmapTheme.accentWarm(for: colorScheme)
                    )
                }
            }
        }
    }
}

// MARK: - Tracker Card

private struct TrackerCard: View {
    let summary: TrackerSummary
    var linkedGoals: [Milestone] = []
    var onMarkTodayDone: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    @State private var selectedDay: TrackerDay?
    @State private var target: TrackerTarget = .unset
    @State private var showTargetPicker: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    private var doneToday: Bool {
        (summary.days.last?.count ?? 0) > 0
    }

    /// Expected sessions across the tracker's window for the current target.
    private var expectedSessions: Double {
        target.expectedSessions(over: summary.days.count)
    }

    /// 0...1+ rate of completion against target.
    private var rate: Double {
        guard expectedSessions > 0 else { return 0 }
        return Double(summary.totalCount) / expectedSessions
    }

    private var rateColor: Color {
        if rate >= 0.85 { return HeatmapTheme.accentGreen(for: colorScheme) }
        if rate >= 0.5  { return HeatmapTheme.accentWarm(for: colorScheme) }
        return .secondary
    }

    private func cellColor(for count: Int) -> Color {
        HeatmapTheme.cellColor(for: count, scheme: colorScheme)
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
        VStack(alignment: .leading, spacing: 12) {
            nameRow

            // Side-by-side: calendar on left, stats column on right.
            HStack(alignment: .top, spacing: 18) {
                TrackerHeatmapGrid(
                    days: summary.days,
                    selectedDay: $selectedDay
                )
                .layoutPriority(0)

                statsColumn
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)
            }

            if let warn = warningMessage {
                warningRow(warn)
            }

            // Frequency-target picker (collapses by default)
            if showTargetPicker {
                targetPicker
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Inline day detail
            if let day = selectedDay {
                dayDetail(day)
            }
        }
        .padding(14)
        .background(HeatmapTheme.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 12))
        .onAppear {
            target = TrackerTargetsStore.target(for: summary.id)
        }
        .onReceive(NotificationCenter.default.publisher(for: TrackerTargetsStore.didChange)) { _ in
            target = TrackerTargetsStore.target(for: summary.id)
        }
        .contextMenu {
            if let onMarkTodayDone, !doneToday {
                Button("Mark today done", action: onMarkTodayDone)
            }
            if let onEdit {
                Button("Edit reminder…", action: onEdit)
            }
            if onEdit != nil || onDelete != nil { Divider() }
            if let onDelete {
                Button("Delete reminder…", role: .destructive, action: onDelete)
            }
        }
    }

    // MARK: - Header / stats helpers

    private var nameRow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(ListColorPalette.color(for: summary.calendarColorIndex))
                .frame(width: 8, height: 8)
            Text(summary.reminderTitle)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
            Text(summary.calendarTitle)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            ForEach(linkedGoals) { goal in
                HStack(spacing: 3) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 8))
                    Text(goal.name)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(HeatmapTheme.accentWarm(for: colorScheme))
            }
            Spacer()
            if let action = onMarkTodayDone {
                Button(action: action) {
                    Image(systemName: doneToday ? "checkmark.circle.fill" : "plus.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(doneToday
                                         ? HeatmapTheme.accentGreen(for: colorScheme)
                                         : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(doneToday)
                .help(doneToday ? "Done today" : "Mark today done")
            }
        }
    }

    private var statsColumn: some View {
        let activeDays = summary.days.filter { $0.count > 0 }.count
        let streak = computeStreak(summary.days)
        let pattern = patternGap(summary.days)
        let hasTarget = target != .unset

        return VStack(alignment: .leading, spacing: 10) {
            // Big number — rate % when target is set, else session count.
            if hasTarget {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(Int((rate * 100).rounded()))%")
                        .font(.system(size: 26, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(rateColor)
                    Text("of target")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Text("\(summary.totalCount) of \(Int(expectedSessions.rounded())) expected")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.top, -8)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(summary.totalCount)")
                        .font(.system(size: 26, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(summary.totalCount > 0
                                         ? HeatmapTheme.accentGreen(for: colorScheme)
                                         : .secondary)
                    Text(summary.totalCount == 1 ? "session" : "sessions")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Text("in last 30 days")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.top, -8)
            }

            // Meta rows
            VStack(spacing: 5) {
                metaRow(label: "Active",
                        value: "\(activeDays)/\(summary.days.count) days",
                        valueColor: nil)
                metaRow(label: "Streak",
                        value: streak > 0 ? "\(streak)d ✓" : "—",
                        valueColor: streak > 0 ? HeatmapTheme.accentGreen(for: colorScheme) : nil)
                if let pattern {
                    metaRow(label: "Pattern",
                            value: pattern,
                            valueColor: HeatmapTheme.accentWarm(for: colorScheme))
                }
            }

            // Target CTA
            targetCTA
                .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var targetCTA: some View {
        let green = HeatmapTheme.accentGreen(for: colorScheme)
        let hasTarget = target != .unset

        Button {
            withAnimation(.easeInOut(duration: 0.18)) { showTargetPicker.toggle() }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: hasTarget ? "target" : "plus")
                    .font(.system(size: 10, weight: .semibold))
                Text(hasTarget ? "Edit target: \(target.label)" : "Set frequency target")
                    .font(.system(size: 11, weight: .medium))
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .rotationEffect(.degrees(showTargetPicker ? 180 : 0))
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(hasTarget ? green : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                hasTarget
                    ? green.opacity(0.10)
                    : HeatmapTheme.cardBackground(for: colorScheme),
                in: RoundedRectangle(cornerRadius: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        hasTarget ? green.opacity(0.4) : .secondary.opacity(0.2),
                        style: StrokeStyle(lineWidth: 1, dash: hasTarget ? [] : [3, 2])
                    )
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var targetPicker: some View {
        let columns = [GridItem(.adaptive(minimum: 78, maximum: 120), spacing: 6)]
        let green = HeatmapTheme.accentGreen(for: colorScheme)

        VStack(alignment: .leading, spacing: 8) {
            Text("FREQUENCY TARGET")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                ForEach(TrackerTarget.pickerOptions) { opt in
                    let selected = opt == target
                    Button {
                        applyTarget(selected ? .unset : opt)
                    } label: {
                        Text(opt.label)
                            .font(.system(size: 11, weight: selected ? .semibold : .medium))
                            .foregroundStyle(selected ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(
                                selected
                                    ? green
                                    : HeatmapTheme.cardBackground(for: colorScheme),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }

                if target != .unset {
                    Button {
                        applyTarget(.unset)
                    } label: {
                        Text("Clear")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(
                                HeatmapTheme.cardBackground(for: colorScheme),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .background(
            HeatmapTheme.cardBackground(for: colorScheme).opacity(0.6),
            in: RoundedRectangle(cornerRadius: 8)
        )
    }

    private func applyTarget(_ new: TrackerTarget) {
        target = new
        TrackerTargetsStore.set(new, for: summary.id)
    }

    private func metaRow(label: String, value: String, valueColor: Color?) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(valueColor ?? .primary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
    }

    private var warningMessage: String? {
        guard let lastActiveIdx = summary.days.lastIndex(where: { $0.count > 0 }) else {
            // Nothing logged yet — only warn if we have multi-week data
            return summary.days.count >= 14 ? "No sessions logged yet" : nil
        }
        let gap = (summary.days.count - 1) - lastActiveIdx
        guard gap >= 3 else { return nil }
        return "\(gap) days since last session — streak at risk"
    }

    @ViewBuilder
    private func warningRow(_ message: String) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(HeatmapTheme.accentWarm(for: colorScheme))
                .frame(width: 2)
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            HeatmapTheme.accentWarm(for: colorScheme).opacity(0.12),
            in: RoundedRectangle(cornerRadius: 6)
        )
    }

    /// Find a weekday with zero completions over the window when other weekdays
    /// have at least 3 hits — reveals patterns like "Never on Thu".
    private func patternGap(_ days: [TrackerDay]) -> String? {
        let cal = Calendar.current
        var hitsByWeekday: [Int: Int] = [:]
        var occurrencesByWeekday: [Int: Int] = [:]
        for d in days {
            let w = cal.component(.weekday, from: d.date)
            occurrencesByWeekday[w, default: 0] += 1
            hitsByWeekday[w, default: 0] += d.count
        }
        // Need at least 3 occurrences of every weekday for a meaningful read.
        guard occurrencesByWeekday.values.allSatisfy({ $0 >= 3 }) else { return nil }
        let totalHits = hitsByWeekday.values.reduce(0, +)
        guard totalHits >= 3 else { return nil }

        let zeroWeekdays = (1...7).filter { (hitsByWeekday[$0] ?? 0) == 0 }
        guard let pick = zeroWeekdays.first else { return nil }

        let symbols = cal.shortStandaloneWeekdaySymbols // ["Sun","Mon",...]
        let name = symbols[pick - 1]
        return "Never on \(name)"
    }

    private func computeStreak(_ days: [TrackerDay]) -> Int {
        // Walk backwards from the most recent day
        var streak = 0
        for day in days.reversed() {
            if day.count > 0 {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    @ViewBuilder
    private func dayDetail(_ day: TrackerDay) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
                .background(.primary.opacity(0.08))

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
    @Binding var selectedDay: TrackerDay?
    @Environment(\.colorScheme) private var colorScheme

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

        // Month labels — skip a label if it would crowd the previous one.
        // "Mar" rendered at 9pt is wider than a single column, so we require
        // at least 3 columns of separation between consecutive labels.
        let minColSpacing = 3
        var labels: [(String, Int)] = []
        var lastMonth = -1
        for col in 0..<numColumns {
            guard let date = cal.date(byAdding: .day, value: col * 7, to: gridStart) else { continue }
            let month = cal.component(.month, from: date)
            if month != lastMonth {
                if let last = labels.last, col - last.1 < minColSpacing {
                    // Drop the prior label — the current (longer-spanning) month wins.
                    labels.removeLast()
                }
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
                                    let isToday = Calendar.current.isDateInToday(day.date)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(HeatmapTheme.cellColor(for: day.count, scheme: colorScheme))
                                        .frame(width: cellSize, height: cellSize)
                                        .overlay {
                                            if isSelected {
                                                RoundedRectangle(cornerRadius: 2)
                                                    .strokeBorder(.primary.opacity(0.6), lineWidth: 1.5)
                                            } else if isToday {
                                                RoundedRectangle(cornerRadius: 2)
                                                    .strokeBorder(
                                                        HeatmapTheme.accentGreen(for: colorScheme),
                                                        lineWidth: 1.5
                                                    )
                                            }
                                        }
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
