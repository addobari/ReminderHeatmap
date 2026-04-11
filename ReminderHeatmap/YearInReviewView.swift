import SwiftUI

struct YearInReviewView: View {
    let yearDays: [HeatmapDay]
    let year: Int
    let badges: [Badge]

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private var totalCompletions: Int {
        yearDays.reduce(0) { $0 + $1.count }
    }

    private var longestStreak: Int {
        let sorted = yearDays.sorted { $0.date < $1.date }
        var best = 0
        var current = 0
        for day in sorted {
            if day.count > 0 {
                current += 1
                best = max(best, current)
            } else {
                current = 0
            }
        }
        return best
    }

    private var mostProductiveMonth: String {
        let calendar = Calendar.current
        var monthTotals: [Int: Int] = [:]
        for day in yearDays {
            let month = calendar.component(.month, from: day.date)
            monthTotals[month, default: 0] += day.count
        }
        guard let best = monthTotals.max(by: { $0.value < $1.value }), best.value > 0 else {
            return "—"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        var components = DateComponents()
        components.month = best.key
        components.day = 1
        components.year = year
        guard let date = calendar.date(from: components) else { return "—" }
        return formatter.string(from: date)
    }

    private var mostProductiveDayOfWeek: String {
        let calendar = Calendar.current
        var weekdayTotals: [Int: Int] = [:]
        for day in yearDays {
            let weekday = calendar.component(.weekday, from: day.date)
            weekdayTotals[weekday, default: 0] += day.count
        }
        guard let best = weekdayTotals.max(by: { $0.value < $1.value }), best.value > 0 else {
            return "—"
        }
        let formatter = DateFormatter()
        return formatter.weekdaySymbols[best.key - 1]
    }

    private var activeDays: Int {
        yearDays.filter { $0.count > 0 }.count
    }

    private var totalDays: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let currentYear = calendar.component(.year, from: today)
        if year < currentYear {
            return yearDays.count
        }
        return yearDays.filter { $0.date <= today }.count
    }

    private var badgesEarnedThisYear: Int {
        let calendar = Calendar.current
        return badges.filter { badge in
            guard let date = badge.unlockedDate else { return false }
            return calendar.component(.year, from: date) == year
        }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack(alignment: .top) {
                    Text("Year in Review — \(year, format: .number.grouping(.never))")
                        .font(.title3.bold())
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

                // Big stat
                VStack(spacing: 4) {
                    Text("\(totalCompletions)")
                        .font(.system(size: 48, weight: .bold).monospacedDigit())
                        .foregroundStyle(HeatmapTheme.accentGreen(for: colorScheme))
                    Text("total completions")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)

                // Stat rows
                VStack(spacing: 10) {
                    statRow(icon: "flame.fill", label: "Longest Streak", value: "\(longestStreak) days")
                    statRow(icon: "calendar", label: "Most Productive Month", value: mostProductiveMonth)
                    statRow(icon: "calendar.day.timeline.left", label: "Most Productive Day", value: mostProductiveDayOfWeek)
                    statRow(icon: "checkmark.circle", label: "Active Days", value: "\(activeDays) / \(totalDays)")
                    statRow(icon: "medal.fill", label: "Badges Earned", value: "\(badgesEarnedThisYear)")
                }
            }
            .padding()
        }
        .frame(minWidth: 360, minHeight: 400)
    }

    private func statRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(HeatmapTheme.accentGreen(for: colorScheme))
                .frame(width: 24)
            Text(label)
                .font(.callout)
            Spacer()
            Text(value)
                .font(.callout.weight(.medium).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(HeatmapTheme.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 10))
    }
}
