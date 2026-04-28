import SwiftUI

struct ContentView: View {
    @ObservedObject var manager: ReminderManager
    @State private var selectedDay: HeatmapDay?
    @State private var showYearReview = false
    @State private var showSettings = false
    @State private var showGoalCelebration = false
    @State private var showMilestoneCreate = false
    @State private var editingMilestone: Milestone?
    @State private var todayExpanded = false
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if !manager.isAuthorized {
                    permissionSection
                }

                if manager.isAuthorized {
                    // 1. Greeting + stats
                    greetingHeader
                        .padding(.horizontal)

                    // 2. Milestones
                    milestonesSection
                        .padding(.horizontal)

                    // 3. Heatmap — the hero
                    heatmapCard
                        .padding(.horizontal)

                    // 4. Today section
                    if manager.yearDays.isEmpty && manager.todayCount == 0 {
                        emptyStateCoaching
                            .padding(.horizontal)
                    } else {
                        todaySection
                            .padding(.horizontal)
                    }

                    // Last updated footer
                    HStack {
                        if let sync = manager.lastSyncDate {
                            Text("Updated \(sync.formatted(.relative(presentation: .named)))")
                                .font(.system(size: 10))
                                .foregroundStyle(.quaternary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Plotted")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(item: $selectedDay) { day in
            DayDetailView(day: day, allDays: manager.yearDays)
                .frame(minWidth: 360, minHeight: 400)
        }
        .sheet(isPresented: $showYearReview) {
            YearInReviewView(yearDays: manager.yearDays, year: manager.selectedYear, badges: manager.badges)
                .frame(minWidth: 400, minHeight: 500)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showMilestoneCreate) {
            MilestoneCreateView(
                trackerSummaries: manager.trackerSummaries,
                onSave: { manager.saveMilestone($0) }
            )
        }
        .sheet(item: $editingMilestone) { milestone in
            MilestoneCreateView(
                trackerSummaries: manager.trackerSummaries,
                existing: milestone,
                onSave: { manager.saveMilestone($0) },
                onDelete: { manager.deleteMilestone(milestone) }
            )
        }
        .overlay(alignment: .center) {
            if showGoalCelebration {
                GoalCelebrationView()
                    .transition(.scale.combined(with: .opacity))
                    .onTapGesture {
                        withAnimation { showGoalCelebration = false }
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation { showGoalCelebration = false }
                        }
                    }
            }
        }
        .onChange(of: manager.dailyGoalMet) { met in
            if met {
                withAnimation(.spring(response: 0.4)) {
                    showGoalCelebration = true
                }
            }
        }
    }

    // MARK: - Milestones Section

    @ViewBuilder
    private var milestonesSection: some View {
        let sorted = manager.milestones.sorted { a, b in
            if a.isExpired != b.isExpired { return !a.isExpired }
            return a.daysRemaining < b.daysRemaining
        }

        if sorted.isEmpty {
            // Inviting empty state
            Button { showMilestoneCreate = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "flag")
                        .font(.system(size: 16))
                        .foregroundStyle(HeatmapTheme.accentWarm(for: colorScheme).opacity(0.6))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Set a goal")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                        Text("Connect your daily habits to what you're building toward")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .background(HeatmapTheme.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        } else {
            let bi = manager.behaviorIntelligence
            VStack(spacing: 10) {
                ForEach(sorted) { milestone in
                    MilestoneCard(
                        milestone: milestone,
                        trackerSummaries: manager.trackerSummaries,
                        effort: bi.milestoneEfforts[milestone.id],
                        onEdit: { editingMilestone = milestone },
                        onReflect: { text in
                            manager.setReflection(text, for: milestone)
                        }
                    )
                }

                Button { showMilestoneCreate = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .medium))
                        Text("Add goal")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Greeting Header

    private var greetingHeader: some View {
        let bi = manager.behaviorIntelligence
        return HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(bi.identityStatement)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        if manager.streak > 0 {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(HeatmapTheme.accentWarm(for: colorScheme))
                        }
                        Text("\(manager.streak)")
                            .font(HeatmapTheme.statNumber)
                            .foregroundStyle(manager.streak > 0 ? HeatmapTheme.accentWarm(for: colorScheme) : .secondary)
                        Text("streak")
                            .font(HeatmapTheme.statLabel)
                            .foregroundStyle(.secondary)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(manager.weekCount)")
                            .font(HeatmapTheme.statNumber)
                        Text("this week")
                            .font(HeatmapTheme.statLabel)
                            .foregroundStyle(.secondary)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(manager.todayCount)")
                            .font(HeatmapTheme.statNumber)
                            .foregroundStyle(manager.dailyGoalMet ? HeatmapTheme.accentGreen(for: colorScheme) : .primary)
                        Text("of \(manager.dailyGoal) today")
                            .font(HeatmapTheme.statLabel)
                            .foregroundStyle(.secondary)
                        if manager.streakFreezeUsedToday {
                            Image(systemName: "snowflake")
                                .font(.system(size: 10))
                                .foregroundStyle(.cyan)
                        }
                    }
                }
            }
            Spacer()
        }
    }

    // MARK: - Empty State

    private var emptyStateCoaching: some View {
        VStack(spacing: 12) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 32))
                .foregroundStyle(HeatmapTheme.accentGreen(for: colorScheme).opacity(0.5))
            Text("Complete a reminder to plant your first green square")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("Every completed task lights up your heatmap")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(HeatmapTheme.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 12))
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
                    .font(HeatmapTheme.sectionTitle)
                    .foregroundStyle(.secondary)
                    .tracking(1)
                Spacer()
                if manager.todayCount > 0 {
                    Text("\(manager.todayCount) completed")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            if manager.currentDayReminders.isEmpty {
                Text("Your day is wide open")
                    .font(.callout)
                    .foregroundStyle(HeatmapTheme.mutedText(for: colorScheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                let limit = todayExpanded ? manager.currentDayReminders.count : 8
                let visible = Array(manager.currentDayReminders.prefix(limit))
                ForEach(Array(visible.enumerated()), id: \.element.id) { index, reminder in
                    if index > 0 {
                        Divider()
                            .background(.primary.opacity(0.08))
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
                if manager.currentDayReminders.count > 8 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            todayExpanded.toggle()
                        }
                    } label: {
                        Text(todayExpanded ? "Show less" : "…and \(manager.currentDayReminders.count - 8) more")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                }
            }
        }
        .background(HeatmapTheme.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Heatmap Card

    private var heatmapCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: year switcher + legend
            HStack {
                yearSwitcher
                Spacer()
                legendBar
            }

            // Full-year grid — the hero
            YearHeatmapGrid(
                days: manager.yearDays,
                year: manager.selectedYear,
                onDayTap: { day in selectedDay = day }
            )

            // Stats + actions row
            HStack(spacing: 0) {
                yearStat(title: "Best day", value: yearBestDay)
                yearStat(title: "Active days", value: yearActiveDays)
                yearStat(title: "Daily avg", value: yearDailyAvg)

                Spacer()

                HStack(spacing: 10) {
                    ShareHeatmapView(yearDays: manager.yearDays, year: manager.selectedYear)
                    Button {
                        showYearReview = true
                    } label: {
                        Image(systemName: "sparkles")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Year in Review")
                }
            }
        }
        .padding(18)
        .background(HeatmapTheme.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 14))
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
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(HeatmapTheme.levelColors(for: colorScheme)[i])
                    .frame(width: 9, height: 9)
            }
            Text("More")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)

            RoundedRectangle(cornerRadius: 2)
                .fill(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(HeatmapTheme.futureBorder(for: colorScheme), lineWidth: 1)
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
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .frame(width: 64)
    }

    // MARK: - Permission Section

    private var permissionSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text("Reminders Access Needed")
                .font(.headline)

            Text("Plotted reads your completed reminders to build the heatmap. No data leaves your Mac.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await manager.requestAccess()
                    if manager.isAuthorized {
                        await manager.refresh()
                    }
                }
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
        .background(HeatmapTheme.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    var accent: Bool = false

    @Environment(\.colorScheme) private var colorScheme

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
        .frame(height: 72)
        .background(HeatmapTheme.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Streak Stat Card (with freeze indicator)

private struct StreakStatCard: View {
    let streak: Int
    let freezeUsed: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 3) {
                Text("\(streak)d")
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(streak > 0 ? .green : .primary)
                if freezeUsed {
                    Image(systemName: "snowflake")
                        .font(.caption2)
                        .foregroundStyle(.cyan)
                }
            }
            Text("Streak")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 72)
        .background(HeatmapTheme.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Goal Stat Card (with progress ring)

private struct GoalStatCard: View {
    let todayCount: Int
    let goal: Int
    let progress: Double

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(HeatmapTheme.emptyColor(for: colorScheme), lineWidth: 3)
                    .frame(width: 30, height: 30)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        todayCount >= goal ? HeatmapTheme.accentGreen(for: colorScheme) : .orange,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 30, height: 30)
                    .rotationEffect(.degrees(-90))
                Text("\(todayCount)")
                    .font(.system(size: 12, weight: .bold).monospacedDigit())
            }
            Text("of \(goal) goal")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 72)
        .background(HeatmapTheme.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Goal Celebration

private struct GoalCelebrationView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            Text("🎉")
                .font(.system(size: 40))
            Text("Daily Goal Met!")
                .font(.system(size: 15, weight: .bold, design: .rounded))
            Text("Great work today")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 12, y: 6)
    }
}

// MARK: - Full-Year Heatmap Grid

struct YearHeatmapGrid: View {
    let days: [HeatmapDay]
    let year: Int
    var onDayTap: ((HeatmapDay) -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    private let rows = 7
    private let cellSize: CGFloat = 13
    private let cellSpacing: CGFloat = 3

    private static let dayLabels = ["", "Mon", "", "Wed", "", "Fri", ""]

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()

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

        ScrollViewReader { scrollProxy in
            ScrollView(.horizontal, showsIndicators: false) {
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
                                .id(col)
                            }
                        }
                    }
                }
            }
            .onAppear {
                let currentYear = Calendar.current.component(.year, from: Date())
                if year == currentYear, info.columns > 0 {
                    let targetCol = max(info.columns - 4, 0)
                    scrollProxy.scrollTo(targetCol, anchor: .trailing)
                }
            }
        }
    }

    @ViewBuilder
    private func cellView(for kind: CellKind) -> some View {
        switch kind {
        case .data(let day):
            HeatmapCellView(
                day: day,
                size: cellSize,
                color: HeatmapTheme.cellColor(for: day.count, scheme: colorScheme),
                onTap: { onDayTap?(day) }
            )
        case .future:
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(HeatmapTheme.futureBorder(for: colorScheme), lineWidth: 1)
                )
                .frame(width: cellSize, height: cellSize)
        case .invisible:
            Color.clear
                .frame(width: cellSize, height: cellSize)
        }
    }
}

// MARK: - Heatmap Cell with Hover Tooltip

private struct HeatmapCellView: View {
    let day: HeatmapDay
    let size: CGFloat
    let color: Color
    var onTap: (() -> Void)?

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
            .onTapGesture { onTap?() }
            .popover(isPresented: $showTooltip) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Self.dateFormatter.string(from: day.date))
                        .font(.caption.bold())
                    if day.count == 0 {
                        Text("No completions")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        let isToday = Calendar.current.isDateInToday(day.date)
                        Text(isToday ? "\(day.count) completed so far today" : "\(day.count) completed")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(8)
            }
    }
}
