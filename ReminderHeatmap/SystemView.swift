import SwiftUI

struct SystemView: View {
    let system: SystemIntelligence
    let behavior: BehaviorIntelligence
    let milestones: [Milestone]

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Health header
                healthHeader

                // Domains
                sectionLabel("DOMAINS")
                domainsCard
                    .padding(.horizontal)

                // Capacity
                sectionLabel("CAPACITY")
                capacityCard
                    .padding(.horizontal)

                // Compounding curves
                let activeMilestones = milestones.filter { !$0.isExpired && system.compoundingCurves[$0.id] != nil }
                if !activeMilestones.isEmpty {
                    sectionLabel("GROWTH")
                    ForEach(activeMilestones) { milestone in
                        if let curve = system.compoundingCurves[milestone.id] {
                            compoundingCard(milestone: milestone, curve: curve)
                                .padding(.horizontal)
                        }
                    }
                }

                // Connections
                if behavior.keystoneHabit != nil || !behavior.correlations.isEmpty {
                    sectionLabel("CONNECTIONS")
                    connectionsCard
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("System")
    }

    // MARK: - Section Label

    private func sectionLabel(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(HeatmapTheme.sectionTitle)
                .foregroundStyle(.secondary)
                .tracking(1)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }

    // MARK: - Health Header

    private var healthHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(behavior.identityStatement)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                Text(system.health.message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            balanceRing
        }
        .padding(.horizontal)
    }

    private var balanceRing: some View {
        ZStack {
            Circle()
                .stroke(HeatmapTheme.emptyColor(for: colorScheme), lineWidth: 4)
                .frame(width: 40, height: 40)
            Circle()
                .trim(from: 0, to: system.health.balanceScore)
                .stroke(
                    balanceColor,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(-90))
            Text("\(Int(system.health.balanceScore * 100))")
                .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var balanceColor: Color {
        let s = system.health.balanceScore
        if s > 0.7 { return HeatmapTheme.accentGreen(for: colorScheme) }
        if s > 0.4 { return HeatmapTheme.accentWarm(for: colorScheme) }
        return .secondary
    }

    // MARK: - Domains Card

    private var domainsCard: some View {
        VStack(spacing: 8) {
            ForEach(system.domains.prefix(6)) { domain in
                HStack(spacing: 10) {
                    Circle()
                        .fill(ListColorPalette.color(for: domain.colorIndex))
                        .frame(width: 7, height: 7)
                    Text(domain.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .frame(width: 80, alignment: .leading)

                    // Bar
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(ListColorPalette.color(for: domain.colorIndex).opacity(0.7))
                            .frame(width: max(geo.size.width * (domain.sharePercentage / 100), 4))
                    }
                    .frame(height: 8)

                    Text("\(Int(domain.sharePercentage))%")
                        .font(.system(size: 10, weight: .medium, design: .rounded).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 28, alignment: .trailing)

                    // Trend
                    trendBadge(domain.trendPercentage)
                        .frame(width: 36, alignment: .trailing)
                }
            }
        }
        .padding(14)
        .background(HeatmapTheme.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func trendBadge(_ pct: Double) -> some View {
        if abs(pct) < 5 {
            Text("→")
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)
        } else if pct > 0 {
            Text("↑\(Int(pct))%")
                .font(.system(size: 9, weight: .medium).monospacedDigit())
                .foregroundStyle(HeatmapTheme.accentGreen(for: colorScheme))
        } else {
            Text("↓\(Int(abs(pct)))%")
                .font(.system(size: 9, weight: .medium).monospacedDigit())
                .foregroundStyle(.orange)
        }
    }

    // MARK: - Capacity Card

    private var capacityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 12) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(system.capacity.activeGoals)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        Text(system.capacity.activeGoals == 1 ? "goal" : "goals")
                            .font(HeatmapTheme.statLabel)
                            .foregroundStyle(.secondary)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(system.capacity.activeTrackers)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        Text(system.capacity.activeTrackers == 1 ? "habit" : "habits")
                            .font(HeatmapTheme.statLabel)
                            .foregroundStyle(.secondary)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(String(format: "%.1f", system.capacity.avgDailyCompletions))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        Text("/day")
                            .font(HeatmapTheme.statLabel)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            // Load bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(HeatmapTheme.emptyColor(for: colorScheme))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(loadColor)
                        .frame(width: geo.size.width * min(system.capacity.loadRatio, 1.3))
                }
            }
            .frame(height: 6)

            Text(system.capacity.message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(HeatmapTheme.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 14))
    }

    private var loadColor: Color {
        let r = system.capacity.loadRatio
        if r <= 0.7 { return HeatmapTheme.accentGreen(for: colorScheme) }
        if r <= 1.0 { return HeatmapTheme.accentWarm(for: colorScheme) }
        return .orange
    }

    // MARK: - Compounding Curve

    private static let weekFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private func compoundingCard(milestone: Milestone, curve: [SystemIntelligence.CurvePoint]) -> some View {
        let maxVal = max(curve.map(\.cumulativeSessions).max() ?? 1, 1)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(milestone.name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Spacer()
                Text("\(curve.last?.cumulativeSessions ?? 0) sessions")
                    .font(.system(size: 11, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle(HeatmapTheme.accentGreen(for: colorScheme))
            }

            // Mini curve
            GeometryReader { geo in
                Path { path in
                    guard curve.count >= 2 else { return }
                    let stepX = geo.size.width / CGFloat(curve.count - 1)
                    let height = geo.size.height

                    for (i, point) in curve.enumerated() {
                        let x = CGFloat(i) * stepX
                        let y = height - (CGFloat(point.cumulativeSessions) / CGFloat(maxVal) * height)
                        if i == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(
                    HeatmapTheme.accentGreen(for: colorScheme),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )

                // Fill under curve
                Path { path in
                    guard curve.count >= 2 else { return }
                    let stepX = geo.size.width / CGFloat(curve.count - 1)
                    let height = geo.size.height

                    path.move(to: CGPoint(x: 0, y: height))
                    for (i, point) in curve.enumerated() {
                        let x = CGFloat(i) * stepX
                        let y = height - (CGFloat(point.cumulativeSessions) / CGFloat(maxVal) * height)
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    path.addLine(to: CGPoint(x: geo.size.width, y: height))
                    path.closeSubpath()
                }
                .fill(HeatmapTheme.accentGreen(for: colorScheme).opacity(0.1))
            }
            .frame(height: 64)

            // Date labels
            if let first = curve.first, let last = curve.last {
                HStack {
                    Text(Self.weekFormatter.string(from: first.weekStart))
                        .font(.system(size: 9))
                        .foregroundStyle(.quaternary)
                    Spacer()
                    Text(Self.weekFormatter.string(from: last.weekStart))
                        .font(.system(size: 9))
                        .foregroundStyle(.quaternary)
                }
            }
        }
        .padding(14)
        .background(HeatmapTheme.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Connections Card

    private var connectionsCard: some View {
        VStack(spacing: 8) {
            if let keystone = behavior.keystoneHabit {
                connectionRow(
                    icon: "key.fill",
                    color: HeatmapTheme.accentWarm(for: colorScheme),
                    text: keystone.message
                )
            }

            ForEach(behavior.correlations.prefix(3)) { corr in
                connectionRow(
                    icon: "link",
                    color: HeatmapTheme.accentGreen(for: colorScheme),
                    text: corr.message
                )
            }

            if let signal = behavior.sustainability {
                connectionRow(
                    icon: signal.trend == .spiking ? "exclamationmark.triangle" : "arrow.down.right",
                    color: signal.trend == .spiking ? .orange : .blue,
                    text: signal.message
                )
            }
        }
        .padding(14)
        .background(HeatmapTheme.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 14))
    }

    private func connectionRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
                .frame(width: 18)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
            Spacer()
        }
    }
}
