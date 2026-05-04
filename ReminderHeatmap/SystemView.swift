import SwiftUI

struct SystemView: View {
    let system: SystemIntelligence
    let behavior: BehaviorIntelligence
    let milestones: [Milestone]

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                // 1. Page header — serif identity statement + balance ring
                pageHeader
                    .padding(.horizontal, 20)

                Divider()
                    .opacity(0.4)
                    .padding(.horizontal, 20)

                // 2. Domains
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("DOMAINS")
                    domainsCard
                }
                .padding(.horizontal, 20)

                // 3. Capacity
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("CAPACITY")
                    capacityCard
                }
                .padding(.horizontal, 20)

                // 4. Compounding curves
                let activeMilestones = milestones.filter { !$0.isExpired && system.compoundingCurves[$0.id] != nil }
                if !activeMilestones.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("GROWTH")
                        VStack(spacing: 12) {
                            ForEach(activeMilestones) { milestone in
                                if let curve = system.compoundingCurves[milestone.id] {
                                    compoundingCard(milestone: milestone, curve: curve)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // 5. Connections — narrative card
                if let connections = connectionsNarrative {
                    NarrativeCard(
                        icon: "link.circle.fill",
                        iconColor: HeatmapTheme.accentGreen(for: colorScheme),
                        title: "Your system at a glance",
                        subtitle: connections.subtitle,
                        bullets: connections.bullets,
                        accentColor: HeatmapTheme.accentGreen(for: colorScheme)
                    )
                    .padding(.horizontal, 20)
                }
            }
            .padding(.top, 18)
            .padding(.bottom, 18)
        }
        .navigationTitle("System")
    }

    // MARK: - Section Label

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(HeatmapTheme.sectionTitle)
            .foregroundStyle(.secondary)
            .tracking(1)
    }

    // MARK: - Page Header (serif identity + balance ring)

    private var pageHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(behavior.identityStatement)
                    .font(.system(size: 26, weight: .regular, design: .serif))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)

                Text(system.health.message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            balanceRing
        }
    }

    private var balanceRing: some View {
        ZStack {
            Circle()
                .stroke(HeatmapTheme.emptyColor(for: colorScheme), lineWidth: 5)
                .frame(width: 54, height: 54)
            Circle()
                .trim(from: 0, to: system.health.balanceScore)
                .stroke(
                    balanceColor,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .frame(width: 54, height: 54)
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int(system.health.balanceScore * 100))")
                    .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.primary)
                Text("balance")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .tracking(0.4)
            }
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
        .background(HeatmapTheme.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 12))
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
        .background(HeatmapTheme.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 12))
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
        .background(HeatmapTheme.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Connections (narrative)

    private var connectionsNarrative: (subtitle: String, bullets: [NarrativeBullet])? {
        var bullets: [NarrativeBullet] = []

        if let keystone = behavior.keystoneHabit {
            bullets.append(
                NarrativeBullet(
                    icon: "key.fill",
                    iconColor: HeatmapTheme.accentWarm(for: colorScheme),
                    text: keystone.message
                )
            )
        }

        for corr in behavior.correlations.prefix(3) {
            bullets.append(
                NarrativeBullet(
                    icon: "link",
                    iconColor: HeatmapTheme.accentGreen(for: colorScheme),
                    text: corr.message
                )
            )
        }

        if let signal = behavior.sustainability {
            bullets.append(
                NarrativeBullet(
                    icon: signal.trend == .spiking ? "exclamationmark.triangle" : "arrow.down.right",
                    iconColor: signal.trend == .spiking ? .orange : .blue,
                    text: signal.message
                )
            )
        }

        guard !bullets.isEmpty else { return nil }

        let subtitle: String
        if behavior.keystoneHabit != nil {
            subtitle = "Patterns linking your habits together"
        } else if !behavior.correlations.isEmpty {
            subtitle = "How your behaviors reinforce each other"
        } else {
            subtitle = "Signals from your recent activity"
        }

        return (subtitle, bullets)
    }
}
