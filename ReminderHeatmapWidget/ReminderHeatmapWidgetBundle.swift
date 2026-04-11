import WidgetKit
import SwiftUI

@main
struct ReminderHeatmapWidgetBundle: WidgetBundle {
    var body: some Widget {
        ReminderHeatmapWidget()
        TrackerWidget()
        StreakWidget()
        TodayWidget()
        WeekCompareWidget()
    }
}
