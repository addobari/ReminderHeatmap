import SwiftUI

struct MilestoneCard: View {
    let milestone: Milestone
    let trackerSummaries: [TrackerSummary]
    var effort: BehaviorIntelligence.MilestoneEffort?
    var onEdit: () -> Void
    var onReflect: ((String) -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @State private var reflectionText: String = ""
    @State private var isReflecting = false
    @State private var isHovering = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: name + countdown
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(milestone.name)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))

                    if !milestone.why.isEmpty {
                        Text(milestone.why)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 12)

                if milestone.isExpired {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("Done")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(HeatmapTheme.accentGreen(for: colorScheme))
                        Text(Self.dateFormatter.string(from: milestone.targetDate))
                            .font(.system(size: 10))
                            .foregroundStyle(.quaternary)
                    }
                } else if milestone.isToday {
                    Text("Today")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(HeatmapTheme.accentWarm(for: colorScheme))
                } else {
                    VStack(alignment: .trailing, spacing: 1) {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("\(milestone.daysRemaining)")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                            Text("days")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        Text(Self.dateFormatter.string(from: milestone.targetDate))
                            .font(.system(size: 10))
                            .foregroundStyle(.quaternary)
                    }
                }
            }

            // Timeline progress bar
            if !milestone.isExpired {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(HeatmapTheme.emptyColor(for: colorScheme))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(HeatmapTheme.accentGreen(for: colorScheme).opacity(0.6))
                            .frame(width: geo.size.width * milestone.timeElapsedFraction)
                    }
                }
                .frame(height: 3)
            }

            // Linked reminders with consistency
            if !milestone.linkedReminders.isEmpty {
                linkedRemindersSection

                // Accumulated effort
                if let effort, effort.totalSessions > 0 {
                    HStack(spacing: 12) {
                        effortStat(value: "\(effort.totalSessions)", label: "sessions")
                        effortStat(value: "\(effort.activeDays)/\(effort.totalDays)d", label: "active")
                        effortStat(value: "\(Int(effort.consistencyRate * 100))%", label: "consistency")
                    }
                }

                // Projection
                if !milestone.isExpired {
                    projectionLine
                }
            }

            // Reflection (for expired milestones)
            if milestone.isExpired {
                reflectionSection
            }

            // Edit hint on hover
            if isHovering {
                HStack {
                    Spacer()
                    Text("Click to edit")
                        .font(.system(size: 9))
                        .foregroundStyle(.quaternary)
                }
                .transition(.opacity)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(HeatmapTheme.cardBackground(for: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(.primary.opacity(isHovering ? 0.08 : 0), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onTapGesture { onEdit() }
    }

    // MARK: - Linked Reminders

    private var linkedRemindersSection: some View {
        VStack(spacing: 5) {
            ForEach(milestone.linkedReminders) { linked in
                let summary = trackerSummaries.first(where: {
                    $0.calendarIdentifier == linked.calendarIdentifier && $0.reminderTitle == linked.reminderTitle
                })
                let activeDays = summary?.days.filter { $0.count > 0 }.count ?? 0
                let totalDays = summary?.days.count ?? 30
                let rate = totalDays > 0 ? Double(activeDays) / Double(totalDays) : 0

                HStack(spacing: 8) {
                    Circle()
                        .fill(rate > 0.7 ? HeatmapTheme.accentGreen(for: colorScheme) : rate > 0.3 ? HeatmapTheme.accentWarm(for: colorScheme) : .secondary.opacity(0.3))
                        .frame(width: 5, height: 5)
                    Text(linked.reminderTitle)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    Spacer()
                    Text("\(activeDays)/\(totalDays)d")
                        .font(.system(size: 10, weight: .medium, design: .rounded).monospacedDigit())
                        .foregroundStyle(.tertiary)
                    consistencyBar(active: activeDays, total: totalDays)
                }
            }
        }
    }

    private func effortStat(value: String, label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.quaternary)
        }
    }

    private func consistencyBar(active: Int, total: Int) -> some View {
        let fraction = total > 0 ? CGFloat(active) / CGFloat(total) : 0
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(HeatmapTheme.emptyColor(for: colorScheme))
                RoundedRectangle(cornerRadius: 2)
                    .fill(fraction > 0.7
                        ? HeatmapTheme.accentGreen(for: colorScheme)
                        : fraction > 0.3
                            ? HeatmapTheme.accentWarm(for: colorScheme)
                            : .secondary.opacity(0.4))
                    .frame(width: geo.size.width * fraction)
            }
        }
        .frame(width: 56, height: 4)
    }

    // MARK: - Projection

    private var projectionLine: some View {
        let totalSessionsPerDay = milestone.linkedReminders.reduce(0.0) { total, linked in
            guard let summary = trackerSummaries.first(where: {
                $0.calendarIdentifier == linked.calendarIdentifier && $0.reminderTitle == linked.reminderTitle
            }) else { return total }
            let active = summary.days.filter { $0.count > 0 }.count
            let rate = Double(active) / max(Double(summary.days.count), 1)
            return total + rate
        }
        let projected = Int(totalSessionsPerDay * Double(milestone.daysRemaining))

        return Group {
            if projected > 0 {
                Text("≈ \(projected) more sessions by \(Self.dateFormatter.string(from: milestone.targetDate))")
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
            }
        }
    }

    // MARK: - Reflection

    private var reflectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let reflection = milestone.reflection, !reflection.isEmpty {
                Divider().background(.primary.opacity(0.05))
                VStack(alignment: .leading, spacing: 3) {
                    Text("REFLECTION")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.quaternary)
                        .tracking(0.5)
                    Text(reflection)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            } else if !isReflecting {
                Divider().background(.primary.opacity(0.05))
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isReflecting = true }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 10))
                        Text("How did it go?")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(HeatmapTheme.accentGreen(for: colorScheme))
                }
                .buttonStyle(.plain)
            } else {
                Divider().background(.primary.opacity(0.05))
                VStack(alignment: .leading, spacing: 8) {
                    Text("How did it go?")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("Reflect on this goal…", text: $reflectionText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .lineLimit(2...4)
                    HStack(spacing: 8) {
                        Spacer()
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { isReflecting = false }
                            reflectionText = ""
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        Button {
                            onReflect?(reflectionText)
                            withAnimation(.easeInOut(duration: 0.2)) { isReflecting = false }
                        } label: {
                            Text("Save")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 5)
                                .background(
                                    reflectionText.isEmpty
                                        ? Color.gray.opacity(0.4)
                                        : HeatmapTheme.accentGreen(for: colorScheme),
                                    in: RoundedRectangle(cornerRadius: 6)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(reflectionText.isEmpty)
                    }
                }
            }
        }
    }
}
