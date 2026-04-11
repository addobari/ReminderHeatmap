import SwiftUI

struct InsightsView: View {
    let insights: InsightsData
    let streak: Int
    var timeIntelligence: TimeIntelligence?
    var badges: [Badge] = []
    var rollingDays: [HeatmapDay] = []

    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedList: InsightsData.ListRanking?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Nudges at the top
                nudgesSection

                // Achievements
                if !badges.isEmpty {
                    sectionHeader("Achievements")
                    badgesSection
                        .padding(.horizontal)
                }

                // Activity Patterns
                sectionHeader("Activity Patterns")
                hourlyChart
                    .padding(.horizontal)

                weekdayChart
                    .padding(.horizontal)

                // Trends
                sectionHeader("Trends")
                HStack(alignment: .top, spacing: 12) {
                    weeklyTrendChart
                    listRankingsCard
                }
                .padding(.horizontal)

                // Time Intelligence
                if let ti = timeIntelligence {
                    sectionHeader("Time Intelligence")
                    timeIntelligenceSection(ti)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Insights")
        .sheet(item: $selectedList) { list in
            ListHeatmapView(
                listName: list.name,
                colorIndex: list.colorIndex,
                days: rollingDays,
                allLists: insights.listRankings
            )
            .frame(minWidth: 480, minHeight: 420)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Nudges

    @ViewBuilder
    private var nudgesSection: some View {
        VStack(spacing: 8) {
            if insights.streakAtRisk, streak > 0 {
                nudgeCard(
                    icon: "flame.fill",
                    iconColor: .orange,
                    text: "Your \(streak)-day streak is at risk — you usually finish tasks by \(hourString(insights.medianCompletionHour ?? 12))"
                )
            }

            if let momentum = insights.momentum {
                if momentum.difference > 0 {
                    nudgeCard(
                        icon: "arrow.up.right",
                        iconColor: HeatmapTheme.accentGreen(for: colorScheme),
                        text: "Up \(Int(abs(momentum.percentChange)))% vs last week — \(momentum.thisWeek) completions so far"
                    )
                } else if momentum.difference < 0 && momentum.lastWeek > 0 {
                    let needed = momentum.lastWeek - momentum.thisWeek
                    nudgeCard(
                        icon: "arrow.down.right",
                        iconColor: .orange,
                        text: "\(needed) more to match last week's \(momentum.lastWeek) completions"
                    )
                }
            }

            if let best = insights.bestWeekday, best.average > 0 {
                nudgeCard(
                    icon: "calendar.badge.clock",
                    iconColor: .blue,
                    text: "\(best.shortName)s are your best day — avg \(String(format: "%.1f", best.average)) completions"
                )
            }

            if let peak = insights.peakHourRange {
                nudgeCard(
                    icon: "bolt.fill",
                    iconColor: .yellow,
                    text: "Peak productivity: \(hourString(peak.startHour))–\(hourString(peak.endHour))"
                )
            }
        }
        .padding(.horizontal)
    }

    private func nudgeCard(icon: String, iconColor: Color, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(iconColor)
                .frame(width: 24)
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(12)
        .background(HeatmapTheme.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Hourly Distribution

    private var hourlyChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("COMPLETION BY HOUR")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            let maxCount = max(insights.hourlyDistribution.max() ?? 1, 1)

            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<24, id: \.self) { hour in
                    let count = insights.hourlyDistribution[hour]
                    let height = count > 0 ? max(CGFloat(count) / CGFloat(maxCount), 0.04) : 0.02

                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(count > 0 ? barColor(fraction: CGFloat(count) / CGFloat(maxCount)) : HeatmapTheme.emptyColor(for: colorScheme))
                            .frame(height: 80 * height)

                        if hour % 4 == 0 {
                            Text(compactHour(hour))
                                .font(.system(size: 8))
                                .foregroundStyle(.tertiary)
                        } else {
                            Text("")
                                .font(.system(size: 8))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 100)
        }
        .padding(14)
        .background(HeatmapTheme.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Day of Week

    private var weekdayChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AVERAGE BY DAY")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            let maxAvg = max(insights.weekdayAverages.map(\.average).max() ?? 1, 1)

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(insights.weekdayAverages) { day in
                    let fraction = day.average / maxAvg
                    let height = day.average > 0 ? max(fraction, 0.06) : 0.03

                    VStack(spacing: 4) {
                        Text(String(format: "%.1f", day.average))
                            .font(.system(size: 9, weight: .medium).monospacedDigit())
                            .foregroundStyle(.secondary)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(day.average > 0 ? barColor(fraction: fraction) : HeatmapTheme.emptyColor(for: colorScheme))
                            .frame(height: 70 * height)

                        Text(day.shortName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 110)
        }
        .padding(14)
        .background(HeatmapTheme.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Weekly Trend

    private var weeklyTrendChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WEEKLY TREND")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            let maxCount = max(insights.weeklyTrend.map(\.count).max() ?? 1, 1)

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(insights.weeklyTrend) { week in
                    let fraction = CGFloat(week.count) / CGFloat(maxCount)
                    let height = week.count > 0 ? max(fraction, 0.06) : 0.03

                    RoundedRectangle(cornerRadius: 2)
                        .fill(week.count > 0 ? barColor(fraction: fraction) : HeatmapTheme.emptyColor(for: colorScheme))
                        .frame(height: 60 * height)
                }
            }
            .frame(height: 60)

            HStack {
                Text("12w ago")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("This week")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(HeatmapTheme.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - List Rankings

    private var listRankingsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TOP LISTS")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if insights.listRankings.isEmpty {
                Text("No data yet")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                let visible = Array(insights.listRankings.prefix(5))
                ForEach(visible) { list in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(ListColorPalette.color(for: list.colorIndex))
                            .frame(width: 7, height: 7)
                        Text(list.name)
                            .font(.callout)
                            .lineLimit(1)
                        Spacer()
                        Text("\(list.count)")
                            .font(.callout.monospacedDigit().weight(.medium))
                        Text("\(Int(list.percentage))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 30, alignment: .trailing)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.quaternary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { selectedList = list }
                }
            }
        }
        .padding(14)
        .background(HeatmapTheme.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func barColor(fraction: CGFloat) -> Color {
        let colors = HeatmapTheme.levelColors(for: colorScheme)
        switch fraction {
        case ..<0.25:  return colors[1]
        case ..<0.50:  return colors[2]
        case ..<0.75:  return colors[3]
        default:       return colors[4]
        }
    }

    private func hourString(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let suffix = hour < 12 ? "am" : "pm"
        return "\(h)\(suffix)"
    }

    private func compactHour(_ hour: Int) -> String {
        if hour == 0 { return "12a" }
        if hour == 12 { return "12p" }
        return hour < 12 ? "\(hour)a" : "\(hour - 12)p"
    }

    // MARK: - Badges

    private static let badgeDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ACHIEVEMENTS")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                let unlocked = badges.filter(\.isUnlocked).count
                Text("\(unlocked)/\(badges.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }

            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(badges) { badge in
                    badgeCell(badge)
                }
            }
        }
        .padding(14)
        .background(HeatmapTheme.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 12))
    }

    private func badgeCell(_ badge: Badge) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(badge.isUnlocked
                        ? HeatmapTheme.accentGreen(for: colorScheme).opacity(0.15)
                        : HeatmapTheme.emptyColor(for: colorScheme))
                    .frame(width: 40, height: 40)
                Image(systemName: badge.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(badge.isUnlocked
                        ? HeatmapTheme.accentGreen(for: colorScheme)
                        : .secondary.opacity(0.3))
            }
            Text(badge.name)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(badge.isUnlocked ? .primary : .tertiary)
                .lineLimit(1)
            if let date = badge.unlockedDate {
                Text(Self.badgeDateFormatter.string(from: date))
                    .font(.system(size: 7))
                    .foregroundStyle(.tertiary)
            } else {
                Text(badge.description)
                    .font(.system(size: 7))
                    .foregroundStyle(.quaternary)
                    .lineLimit(1)
            }
        }
        .help(badge.isUnlocked ? "\(badge.name) — unlocked" : "\(badge.name): \(badge.description)")
    }

    // MARK: - Time Intelligence

    private func timeIntelligenceSection(_ ti: TimeIntelligence) -> some View {
        VStack(spacing: 12) {
            if let velocity = ti.velocityStats {
                velocityCard(velocity)
            }
            if let onTime = ti.onTimeStats, onTime.onTimeCount + onTime.overdueCount > 0 {
                onTimeCard(onTime)
            }
        }
    }

    private func velocityCard(_ stats: TimeIntelligence.VelocityStats) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("COMPLETION VELOCITY")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                velocityStat(label: "Median", value: formatDuration(stats.medianHours))
                velocityStat(label: "Average", value: formatDuration(stats.averageHours))
                velocityStat(label: "Fastest", value: formatDuration(stats.fastestHours))
            }

            let maxCount = max(stats.distribution.map(\.count).max() ?? 1, 1)
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(stats.distribution) { bucket in
                    let fraction = CGFloat(bucket.count) / CGFloat(maxCount)
                    let height = bucket.count > 0 ? max(fraction, 0.06) : 0.03
                    VStack(spacing: 3) {
                        Text("\(bucket.count)")
                            .font(.system(size: 9, weight: .medium).monospacedDigit())
                            .foregroundStyle(.secondary)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(bucket.count > 0 ? barColor(fraction: fraction) : HeatmapTheme.emptyColor(for: colorScheme))
                            .frame(height: 50 * height)
                        Text(bucket.label)
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 80)

            Text("\(stats.totalTracked) tasks tracked")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(HeatmapTheme.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 12))
    }

    private func velocityStat(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.callout.bold().monospacedDigit())
                .foregroundStyle(HeatmapTheme.accentGreen(for: colorScheme))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func onTimeCard(_ stats: TimeIntelligence.OnTimeStats) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ON-TIME COMPLETION")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                let tracked = stats.onTimeCount + stats.overdueCount
                let onTimeFraction = tracked > 0 ? CGFloat(stats.onTimeCount) / CGFloat(tracked) : 0

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(colorScheme == .dark ? Color.red.opacity(0.3) : Color.red.opacity(0.15))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(HeatmapTheme.accentGreen(for: colorScheme))
                            .frame(width: geo.size.width * onTimeFraction)
                    }
                }
                .frame(height: 20)
            }

            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(HeatmapTheme.accentGreen(for: colorScheme))
                        .frame(width: 7, height: 7)
                    Text("\(stats.onTimeCount) on time (\(Int(stats.onTimePercentage))%)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(colorScheme == .dark ? Color.red.opacity(0.5) : Color.red.opacity(0.3))
                        .frame(width: 7, height: 7)
                    Text("\(stats.overdueCount) overdue")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if stats.noDueDateCount > 0 {
                    Spacer()
                    Text("\(stats.noDueDateCount) no date")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            if let avgOverdue = stats.averageOverdueDays, avgOverdue > 0 {
                Text("Avg \(String(format: "%.1f", avgOverdue)) days overdue")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(14)
        .background(HeatmapTheme.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 12))
    }

    private func formatDuration(_ hours: Double) -> String {
        if hours < 1 {
            return "\(Int(hours * 60))m"
        } else if hours < 24 {
            return String(format: "%.1fh", hours)
        } else {
            return String(format: "%.1fd", hours / 24)
        }
    }
}
