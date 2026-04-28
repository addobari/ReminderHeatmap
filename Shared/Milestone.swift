import Foundation

struct Milestone: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var targetDate: Date
    var why: String
    var linkedReminders: [LinkedReminder]
    var reflection: String?
    var createdAt: Date

    struct LinkedReminder: Codable, Hashable, Identifiable {
        var id: String { calendarIdentifier + ":" + reminderTitle }
        let calendarIdentifier: String
        let reminderTitle: String
        let calendarTitle: String
    }

    init(
        id: UUID = UUID(),
        name: String,
        targetDate: Date,
        why: String = "",
        linkedReminders: [LinkedReminder] = [],
        reflection: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.targetDate = targetDate
        self.why = why
        self.linkedReminders = linkedReminders
        self.reflection = reflection
        self.createdAt = createdAt
    }

    var daysRemaining: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let target = cal.startOfDay(for: targetDate)
        return cal.dateComponents([.day], from: today, to: target).day ?? 0
    }

    var isExpired: Bool { daysRemaining < 0 }
    var isToday: Bool { daysRemaining == 0 }

    var daysSinceCreation: Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: createdAt), to: cal.startOfDay(for: Date())).day ?? 0
    }

    var totalDuration: Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: createdAt)
        let target = cal.startOfDay(for: targetDate)
        return cal.dateComponents([.day], from: start, to: target).day ?? 1
    }

    var timeElapsedFraction: Double {
        let total = max(totalDuration, 1)
        let elapsed = daysSinceCreation
        return min(max(Double(elapsed) / Double(total), 0), 1)
    }
}

// MARK: - Persistence

enum MilestoneStore {
    private static let key = "com.addobari.plotted.milestones"

    static func load() -> [Milestone] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let milestones = try? JSONDecoder().decode([Milestone].self, from: data) else {
            return []
        }
        return milestones
    }

    static func save(_ milestones: [Milestone]) {
        if let data = try? JSONEncoder().encode(milestones) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
