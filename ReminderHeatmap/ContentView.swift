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
    @State private var showNewReminder = false
    @State private var editingReminder: ReminderManager.EditableReminder?
    @State private var deleteConfirmation: ReminderManager.EditableReminder?
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                if !manager.isAuthorized {
                    permissionSection
                }

                if manager.isAuthorized {
                    // 1. Page header — serif date + stats + weekday rhythm
                    pageHeader
                        .padding(.horizontal, 20)

                    Divider()
                        .opacity(0.4)
                        .padding(.horizontal, 20)

                    // 2. Keystone Habit (only when present)
                    if let keystone = manager.behaviorIntelligence.keystoneHabit {
                        keystoneCard(keystone)
                            .padding(.horizontal, 20)
                    }

                    // 3. Today task list with progress bar
                    todayCard
                        .padding(.horizontal, 20)

                    // 4. Active goal(s)
                    activeGoalsSection
                        .padding(.horizontal, 20)

                    // 5. Heatmap (kept per request)
                    heatmapCard
                        .padding(.horizontal, 20)

                    // 6. Footer
                    footer
                        .padding(.horizontal, 20)
                }
            }
            .padding(.top, 76)
            .padding(.bottom, 18)
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    showNewReminder = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(!manager.isAuthorized)
                .help("New reminder")
                .keyboardShortcut("n", modifiers: .command)
            }
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
            SettingsView(manager: manager)
        }
        .sheet(isPresented: $showNewReminder) {
            NewReminderView(manager: manager)
        }
        .sheet(item: $editingReminder) { editing in
            NewReminderView(manager: manager, editing: editing)
        }
        .alert(item: $deleteConfirmation) { target in
            Alert(
                title: Text("Delete \"\(target.title)\"?"),
                message: Text("This removes it from Apple Reminders everywhere it syncs."),
                primaryButton: .destructive(Text("Delete")) {
                    Task { await manager.deleteReminder(reminderID: target.id) }
                },
                secondaryButton: .cancel()
            )
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

    // MARK: - Page Header (serif date + stats + weekday rhythm)

    private var pageHeader: some View {
        let chips = WeekRhythm.currentWeekChips(rollingDays: manager.days)
        let activeThisWeek = chips.filter { !$0.isFuture && $0.count > 0 }.count
        let yearActiveDays = pastDays.filter { $0.count > 0 }.count

        return VStack(alignment: .leading, spacing: 14) {
            // Big serif date
            Text(longDateString)
                .font(.system(size: 30, weight: .regular, design: .serif))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            // Stats triplet
            HStack(spacing: 18) {
                statTriplet(value: "\(manager.weekCount)", label: "this week")
                statTriplet(value: "\(manager.todayCount)", label: "of \(manager.dailyGoal) today",
                            valueColor: manager.dailyGoalMet ? HeatmapTheme.accentGreen(for: colorScheme) : .primary)
                statTriplet(value: "\(yearActiveDays)", label: "active days")
                Spacer(minLength: 0)
            }

            // Day-of-week chips + summary line
            HStack(alignment: .center, spacing: 12) {
                HStack(spacing: 6) {
                    ForEach(chips) { chip in
                        weekdayChip(chip)
                    }
                }

                Text("\(activeThisWeek)/7 this week")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                + Text(" · ")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                + Text("\(manager.streak)-day streak")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(manager.streak > 0 ? HeatmapTheme.accentWarm(for: colorScheme) : .secondary)

                Spacer(minLength: 0)

                Text("Week \(weeksOfTracking) of tracking")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func statTriplet(value: String, label: String, valueColor: Color = .primary) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(valueColor)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private func weekdayChip(_ chip: WeekdayChipState) -> some View {
        let green = HeatmapTheme.accentGreen(for: colorScheme)
        let size: CGFloat = 22

        return ZStack {
            if chip.isFuture {
                Circle()
                    .strokeBorder(HeatmapTheme.emptyColor(for: colorScheme), lineWidth: 1)
                    .frame(width: size, height: size)
                Text(chip.letter)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
            } else if chip.isToday {
                Circle()
                    .strokeBorder(green, lineWidth: 2)
                    .frame(width: size, height: size)
                if chip.count > 0 {
                    Circle()
                        .fill(green.opacity(0.18))
                        .frame(width: size - 4, height: size - 4)
                }
                Text(chip.letter)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(green)
            } else if chip.count > 0 {
                Circle()
                    .fill(green)
                    .frame(width: size, height: size)
                Text(chip.letter)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white)
            } else {
                Circle()
                    .fill(HeatmapTheme.emptyColor(for: colorScheme))
                    .frame(width: size, height: size)
                Text(chip.letter)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var longDateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: Date())
    }

    /// Approximate weeks of tracking based on earliest known year.
    private var weeksOfTracking: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let janFirst = calendar.date(from: DateComponents(year: manager.earliestYear, month: 1, day: 1)) else {
            return 1
        }
        // Use earliest non-zero day in yearDays as a more accurate start when available.
        let firstActive = manager.yearDays.first(where: { $0.count > 0 })?.date ?? janFirst
        let startDate = max(firstActive, janFirst)
        let days = calendar.dateComponents([.day], from: startDate, to: today).day ?? 0
        return max(1, (days / 7) + 1)
    }

    // MARK: - Keystone Habit Card

    private func keystoneCard(_ keystone: BehaviorIntelligence.KeystoneHabit) -> some View {
        let green = HeatmapTheme.accentGreen(for: colorScheme)
        let message = KeystoneMessageBuilder.build(
            keystone: keystone,
            insights: manager.insights,
            currentDayReminders: manager.currentDayReminders
        )

        let bg: Color = colorScheme == .dark
            ? Color(red: 0.075, green: 0.18, blue: 0.11)
            : Color(red: 0.91, green: 0.97, blue: 0.93)

        return HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(green)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(green)
                    Text("KEYSTONE HABIT")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(green)
                }
                styledKeystoneText(message, trackerName: keystone.trackerName, accent: green)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
            Spacer(minLength: 0)
        }
        .background(bg, in: RoundedRectangle(cornerRadius: 12))
    }

    /// Render the keystone message with the tracker name bolded.
    private func styledKeystoneText(_ message: String, trackerName: String, accent: Color) -> Text {
        // Rough heuristic: split on the tracker name to bold it.
        let parts = message.components(separatedBy: trackerName)
        guard parts.count >= 2 else {
            return Text(message)
        }
        var result = Text(parts[0])
        for i in 1..<parts.count {
            result = result + Text(trackerName).fontWeight(.semibold).foregroundStyle(accent)
            result = result + Text(parts[i])
        }
        return result
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        if let sync = manager.lastSyncDate {
            HStack {
                Text("Updated \(sync.formatted(.relative(presentation: .named)))")
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
                Spacer()
            }
        }
    }

    // MARK: - Active Goals Section

    @ViewBuilder
    private var activeGoalsSection: some View {
        let sorted = manager.milestones.sorted { a, b in
            if a.isExpired != b.isExpired { return !a.isExpired }
            return a.daysRemaining < b.daysRemaining
        }
        let activeCount = sorted.filter { !$0.isExpired }.count

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(activeCount == 1 ? "ACTIVE GOAL" : "ACTIVE GOALS")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(.tertiary)
                Spacer()
                if !sorted.isEmpty {
                    Button {
                        showMilestoneCreate = true
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "plus")
                                .font(.system(size: 9, weight: .semibold))
                            Text("Add")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }

            milestonesSection
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

    // MARK: - Today Card (new design: progress bar header + checkbox list)

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private var todayCard: some View {
        let goal = max(manager.dailyGoal, 1)
        let progress = min(Double(manager.todayCount) / Double(goal), 1.0)
        let keystoneName = manager.behaviorIntelligence.keystoneHabit?.trackerName

        // Build the unified task list: completed reminders first, then today's
        // recurring habits that haven't been done yet.
        let completed = manager.currentDayReminders
        let completedTitles = Set(completed.map(\.title))
        let openHabits: [TrackerSummary] = manager.trackerSummaries.filter { summary in
            // not done yet today (today is summary.days.last when ascending) and
            // it's an actually-active habit (not a long-dormant or one-off).
            let todayDone = summary.days.last?.count ?? 0
            guard todayDone == 0 else { return false }
            // Has had any completion in last 14 days → likely current habit
            let recent14 = summary.days.suffix(14).reduce(0) { $0 + $1.count }
            return recent14 >= 1 || !completedTitles.contains(summary.reminderTitle)
                && summary.totalCount >= 1
        }
        // Cap each list to keep card visually tight unless expanded.
        let completedLimit = todayExpanded ? completed.count : 5
        let openLimit = todayExpanded ? openHabits.count : 6
        let extraCount = (completed.count - completedLimit) + (openHabits.count - openLimit)

        return VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(alignment: .firstTextBaseline) {
                Text("TODAY")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(manager.todayCount) / \(manager.dailyGoal)")
                    .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(HeatmapTheme.emptyColor(for: colorScheme))
                    Rectangle()
                        .fill(manager.dailyGoalMet
                              ? HeatmapTheme.accentGreen(for: colorScheme)
                              : HeatmapTheme.accentGreen(for: colorScheme).opacity(0.7))
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 2)

            // Body
            if completed.isEmpty && openHabits.isEmpty {
                VStack(spacing: 6) {
                    Text("Your day is wide open")
                        .font(.callout)
                        .foregroundStyle(HeatmapTheme.mutedText(for: colorScheme))
                    Text("Every completed task lights up your heatmap.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 26)
            } else {
                VStack(spacing: 0) {
                    // Completed (checkmark + strikethrough)
                    ForEach(Array(completed.prefix(completedLimit).enumerated()), id: \.element.id) { idx, reminder in
                        if idx > 0 { taskDivider }
                        completedRow(reminder)
                    }

                    if !completed.isEmpty && !openHabits.isEmpty {
                        taskDivider
                    }

                    // Open habits (empty circle, optional keystone tag)
                    ForEach(Array(openHabits.prefix(openLimit).enumerated()), id: \.offset) { idx, habit in
                        if idx > 0 { taskDivider }
                        openHabitRow(habit, isKeystone: habit.reminderTitle == keystoneName)
                    }

                    if extraCount > 0 || todayExpanded {
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) { todayExpanded.toggle() }
                        } label: {
                            Text(todayExpanded ? "Show less" : "…and \(extraCount) more")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .background(HeatmapTheme.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 12))
    }

    private var taskDivider: some View {
        Divider()
            .background(.primary.opacity(0.06))
            .padding(.leading, 38)
    }

    private func completedRow(_ reminder: CompletedReminder) -> some View {
        let green = HeatmapTheme.accentGreen(for: colorScheme)
        return Button {
            guard !reminder.reminderIdentifier.isEmpty else { return }
            Task { await manager.uncompleteReminder(reminderID: reminder.reminderIdentifier) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(green)
                Text(reminder.title)
                    .font(.system(size: 13))
                    .strikethrough(true, color: .secondary.opacity(0.6))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Text(Self.timeFormatter.string(from: reminder.completionTime))
                    .font(.system(size: 11, design: .rounded).monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Tap to uncomplete")
        .contextMenu {
            Button("Uncomplete") {
                guard !reminder.reminderIdentifier.isEmpty else { return }
                Task { await manager.uncompleteReminder(reminderID: reminder.reminderIdentifier) }
            }
            Button("Edit…") {
                guard !reminder.reminderIdentifier.isEmpty else { return }
                Task {
                    if let editable = await manager.loadEditableReminder(reminderID: reminder.reminderIdentifier) {
                        editingReminder = editable
                    }
                }
            }
            Divider()
            Button("Delete…", role: .destructive) {
                guard !reminder.reminderIdentifier.isEmpty else { return }
                Task {
                    if let editable = await manager.loadEditableReminder(reminderID: reminder.reminderIdentifier) {
                        deleteConfirmation = editable
                    }
                }
            }
        }
    }

    private func openHabitRow(_ habit: TrackerSummary, isKeystone: Bool) -> some View {
        let green = HeatmapTheme.accentGreen(for: colorScheme)
        return Button {
            Task {
                await manager.completeReminder(
                    title: habit.reminderTitle,
                    calendarIdentifier: habit.calendarIdentifier
                )
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary.opacity(0.5))
                Text(habit.reminderTitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
                if isKeystone {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9, weight: .semibold))
                        Text("keystone")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                    }
                    .foregroundStyle(green)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
            .overlay(alignment: .leading) {
                if isKeystone {
                    Rectangle()
                        .fill(green)
                        .frame(width: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .help("Tap to mark done")
        .contextMenu {
            Button("Mark done") {
                Task {
                    await manager.completeReminder(
                        title: habit.reminderTitle,
                        calendarIdentifier: habit.calendarIdentifier
                    )
                }
            }
            Button("Edit…") {
                Task {
                    if let editable = await manager.loadEditableReminder(
                        title: habit.reminderTitle,
                        calendarIdentifier: habit.calendarIdentifier
                    ) {
                        editingReminder = editable
                    }
                }
            }
            Divider()
            Button("Delete…", role: .destructive) {
                Task {
                    if let editable = await manager.loadEditableReminder(
                        title: habit.reminderTitle,
                        calendarIdentifier: habit.calendarIdentifier
                    ) {
                        deleteConfirmation = editable
                    }
                }
            }
        }
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
