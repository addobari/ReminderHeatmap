import SwiftUI

// MARK: - Narrative Card
//
// A reusable, "story-shaped" card used by features like Daily Brief,
// Dormant Nudge, Streak Recovery, Weekly Digest, and Habit DNA. The
// shape is: header (icon + title + optional subtitle) → optional body
// (bulleted facts or a small timeline) → optional footer.
//
// It collapses by default when `expandable == true`, in which case a
// short `summary` line is shown. Tapping the card toggles the body.

struct NarrativeBullet: Identifiable, Hashable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let text: String
}

struct NarrativeCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    var subtitle: String? = nil
    var summary: String? = nil
    var bullets: [NarrativeBullet] = []
    var footer: String? = nil
    var expandable: Bool = false
    var initiallyExpanded: Bool = true
    var accentColor: Color? = nil

    @State private var expanded: Bool
    @Environment(\.colorScheme) private var colorScheme

    init(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String? = nil,
        summary: String? = nil,
        bullets: [NarrativeBullet] = [],
        footer: String? = nil,
        expandable: Bool = false,
        initiallyExpanded: Bool = true,
        accentColor: Color? = nil
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.summary = summary
        self.bullets = bullets
        self.footer = footer
        self.expandable = expandable
        self.initiallyExpanded = initiallyExpanded
        self.accentColor = accentColor
        _expanded = State(initialValue: expandable ? initiallyExpanded : true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: expanded ? 10 : 6) {
            header
            if expanded {
                if !bullets.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(bullets) { bullet in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: bullet.icon)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(bullet.iconColor)
                                    .frame(width: 14, alignment: .center)
                                    .padding(.top, 1)
                                Text(bullet.text)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.primary)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
                if let footer {
                    Text(footer)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            } else if let summary {
                Text(summary)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .background(HeatmapTheme.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .leading) {
            if let accentColor {
                Rectangle()
                    .fill(accentColor.opacity(0.6))
                    .frame(width: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 1.5))
                    .padding(.vertical, 8)
                    .padding(.leading, 0)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard expandable else { return }
            withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 26, height: 26)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
            if expandable {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(expanded ? 0 : -90))
            }
        }
    }
}
