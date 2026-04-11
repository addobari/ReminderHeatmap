import Foundation

struct Badge: Identifiable, Hashable {
    let id: String
    let icon: String
    let name: String
    let description: String
    let category: Category
    var unlockedDate: Date?

    var isUnlocked: Bool { unlockedDate != nil }

    enum Category: String, CaseIterable {
        case completions = "Completions"
        case streaks = "Streaks"
        case special = "Special"
    }
}

enum BadgeChecker {

    // MARK: - All badge definitions

    static let allBadgeIDs: [String] = [
        // Completions
        "first_completion", "completions_10", "completions_25", "completions_50",
        "completions_100", "completions_250", "completions_500", "completions_1000",
        // Streaks
        "streak_3", "streak_7", "streak_14", "streak_30", "streak_60", "streak_90",
        // Special
        "perfect_week", "early_bird", "night_owl", "marathon_day", "list_juggler",
        "weekend_warrior",
    ]

    static func template(for id: String) -> Badge {
        switch id {
        // Completions
        case "first_completion":
            return Badge(id: id, icon: "checkmark.circle", name: "First Step", description: "Complete your first reminder", category: .completions)
        case "completions_10":
            return Badge(id: id, icon: "star", name: "Getting Started", description: "Complete 10 reminders", category: .completions)
        case "completions_25":
            return Badge(id: id, icon: "star.fill", name: "Quarter Century", description: "Complete 25 reminders", category: .completions)
        case "completions_50":
            return Badge(id: id, icon: "trophy", name: "Half Century", description: "Complete 50 reminders", category: .completions)
        case "completions_100":
            return Badge(id: id, icon: "trophy.fill", name: "Centurion", description: "Complete 100 reminders", category: .completions)
        case "completions_250":
            return Badge(id: id, icon: "medal", name: "Powerhouse", description: "Complete 250 reminders", category: .completions)
        case "completions_500":
            return Badge(id: id, icon: "medal.fill", name: "Unstoppable", description: "Complete 500 reminders", category: .completions)
        case "completions_1000":
            return Badge(id: id, icon: "crown", name: "Legend", description: "Complete 1,000 reminders", category: .completions)
        // Streaks
        case "streak_3":
            return Badge(id: id, icon: "flame", name: "Warm Up", description: "3-day streak", category: .streaks)
        case "streak_7":
            return Badge(id: id, icon: "flame.fill", name: "On Fire", description: "7-day streak", category: .streaks)
        case "streak_14":
            return Badge(id: id, icon: "bolt.fill", name: "Two Weeks Strong", description: "14-day streak", category: .streaks)
        case "streak_30":
            return Badge(id: id, icon: "bolt.circle.fill", name: "Monthly Machine", description: "30-day streak", category: .streaks)
        case "streak_60":
            return Badge(id: id, icon: "sparkles", name: "Relentless", description: "60-day streak", category: .streaks)
        case "streak_90":
            return Badge(id: id, icon: "star.circle.fill", name: "Legendary Streak", description: "90-day streak", category: .streaks)
        // Special
        case "perfect_week":
            return Badge(id: id, icon: "calendar.badge.checkmark", name: "Perfect Week", description: "Complete at least 1 task every day for 7 days", category: .special)
        case "early_bird":
            return Badge(id: id, icon: "sunrise.fill", name: "Early Bird", description: "Complete a task before 8am", category: .special)
        case "night_owl":
            return Badge(id: id, icon: "moon.stars.fill", name: "Night Owl", description: "Complete a task after 10pm", category: .special)
        case "marathon_day":
            return Badge(id: id, icon: "figure.run", name: "Marathon Day", description: "Complete 10+ tasks in a single day", category: .special)
        case "list_juggler":
            return Badge(id: id, icon: "list.bullet.rectangle", name: "List Juggler", description: "Complete from 3+ lists in one day", category: .special)
        case "weekend_warrior":
            return Badge(id: id, icon: "hand.raised.fill", name: "Weekend Warrior", description: "Complete tasks on both Sat & Sun", category: .special)
        default:
            return Badge(id: id, icon: "questionmark.circle", name: id, description: "", category: .special)
        }
    }

    // MARK: - Evaluate badges from data

    static func evaluate(days: [HeatmapDay], currentStreak: Int) -> [Badge] {
        let calendar = Calendar.current
        let allReminders = days.flatMap(\.reminders)
        let totalCompletions = allReminders.count

        // Load previously unlocked dates
        let saved = loadUnlockedDates()

        var badges = allBadgeIDs.map { id -> Badge in
            var badge = template(for: id)
            badge.unlockedDate = saved[id]
            return badge
        }

        let now = Date()

        func unlock(_ id: String) {
            guard let idx = badges.firstIndex(where: { $0.id == id }) else { return }
            if badges[idx].unlockedDate == nil {
                badges[idx].unlockedDate = now
            }
        }

        // Completion milestones
        let thresholds: [(Int, String)] = [
            (1, "first_completion"), (10, "completions_10"), (25, "completions_25"),
            (50, "completions_50"), (100, "completions_100"), (250, "completions_250"),
            (500, "completions_500"), (1000, "completions_1000"),
        ]
        for (threshold, id) in thresholds {
            if totalCompletions >= threshold { unlock(id) }
        }

        // Streak milestones (based on best streak in the data, not just current)
        let bestStreak = computeBestStreak(days: days)
        let streakToCheck = max(currentStreak, bestStreak)
        let streakThresholds: [(Int, String)] = [
            (3, "streak_3"), (7, "streak_7"), (14, "streak_14"),
            (30, "streak_30"), (60, "streak_60"), (90, "streak_90"),
        ]
        for (threshold, id) in streakThresholds {
            if streakToCheck >= threshold { unlock(id) }
        }

        // Perfect week: any 7 consecutive days all with count > 0
        let sortedDays = days.sorted { $0.date < $1.date }
        var consecutive = 0
        for day in sortedDays {
            if day.count > 0 {
                consecutive += 1
                if consecutive >= 7 { unlock("perfect_week"); break }
            } else {
                consecutive = 0
            }
        }

        // Early bird: any completion before 8am
        if allReminders.contains(where: { calendar.component(.hour, from: $0.completionTime) < 8 }) {
            unlock("early_bird")
        }

        // Night owl: any completion after 10pm
        if allReminders.contains(where: { calendar.component(.hour, from: $0.completionTime) >= 22 }) {
            unlock("night_owl")
        }

        // Marathon day: 10+ in one day
        if days.contains(where: { $0.count >= 10 }) {
            unlock("marathon_day")
        }

        // List juggler: 3+ different lists in one day
        for day in days where day.reminders.count >= 3 {
            let uniqueLists = Set(day.reminders.map(\.listName))
            if uniqueLists.count >= 3 { unlock("list_juggler"); break }
        }

        // Weekend warrior: tasks on both Sat and Sun in the same week
        let saturdayDays = Set(days.filter { calendar.component(.weekday, from: $0.date) == 7 && $0.count > 0 }
            .map { calendar.dateInterval(of: .weekOfYear, for: $0.date)?.start })
        let sundayDays = Set(days.filter { calendar.component(.weekday, from: $0.date) == 1 && $0.count > 0 }
            .map { calendar.dateInterval(of: .weekOfYear, for: $0.date)?.start })
        if !saturdayDays.intersection(sundayDays).isEmpty {
            unlock("weekend_warrior")
        }

        // Persist newly unlocked badges
        saveUnlockedDates(badges)

        return badges
    }

    // MARK: - Best streak

    private static func computeBestStreak(days: [HeatmapDay]) -> Int {
        let sorted = days.sorted { $0.date < $1.date }
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

    // MARK: - Persistence

    private static let storageKey = "com.addobari.plotted.unlockedBadges"

    private static func loadUnlockedDates() -> [String: Date] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let dict = try? JSONDecoder().decode([String: Date].self, from: data) else {
            return [:]
        }
        return dict
    }

    private static func saveUnlockedDates(_ badges: [Badge]) {
        var dict: [String: Date] = [:]
        for badge in badges {
            if let date = badge.unlockedDate {
                dict[badge.id] = date
            }
        }
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
