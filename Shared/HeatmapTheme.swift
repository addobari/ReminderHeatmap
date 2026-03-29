import SwiftUI

// MARK: - Appearance Setting

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// MARK: - GitHub-style Heatmap Colors (adaptive)

/// GitHub contribution graph colors that adapt to light/dark mode.
/// Light: #ebedf0, #9be9a8, #40c463, #30a14e, #216e39
/// Dark:  white@0.09, #0e4429, #006d32, #26a641, #39d353
enum HeatmapTheme {

    // MARK: Cell colors

    static func emptyColor(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.09)
            : Color(red: 0.92, green: 0.93, blue: 0.94) // #ebedf0
    }

    static func levelColors(for scheme: ColorScheme) -> [Color] {
        if scheme == .dark {
            return [
                Color.white.opacity(0.09),                      // 0
                Color(red: 0.055, green: 0.267, blue: 0.161),   // 1-2: #0e4429
                Color(red: 0.0,   green: 0.427, blue: 0.196),   // 3-4: #006d32
                Color(red: 0.149, green: 0.651, blue: 0.255),    // 5-6: #26a641
                Color(red: 0.224, green: 0.827, blue: 0.325),    // 7+:  #39d353
            ]
        } else {
            return [
                Color(red: 0.92, green: 0.93, blue: 0.94),       // 0:   #ebedf0
                Color(red: 0.608, green: 0.914, blue: 0.659),    // 1-2: #9be9a8
                Color(red: 0.251, green: 0.769, blue: 0.388),    // 3-4: #40c463
                Color(red: 0.188, green: 0.631, blue: 0.306),    // 5-6: #30a14e
                Color(red: 0.129, green: 0.431, blue: 0.224),    // 7+:  #216e39
            ]
        }
    }

    static func cellColor(for count: Int, scheme: ColorScheme) -> Color {
        let colors = levelColors(for: scheme)
        switch count {
        case 0:    return colors[0]
        case 1...2: return colors[1]
        case 3...4: return colors[2]
        case 5...6: return colors[3]
        default:   return colors[4]
        }
    }

    // MARK: Accent green

    static func accentGreen(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.224, green: 0.827, blue: 0.325)  // #39d353
            : Color(red: 0.188, green: 0.631, blue: 0.306)  // #30a14e
    }

    // MARK: Future cell border

    static func futureBorder(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.18)
            : Color.black.opacity(0.12)
    }

    // MARK: Card / surface backgrounds

    static func cardBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.05)
            : Color.black.opacity(0.04)
    }

    // MARK: Muted text

    static func mutedText(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.4)
            : Color.black.opacity(0.45)
    }

    static func faintText(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.35)
            : Color.black.opacity(0.3)
    }
}
