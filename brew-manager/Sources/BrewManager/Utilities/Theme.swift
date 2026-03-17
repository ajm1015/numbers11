import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case midnight = "Midnight"
    case nord = "Nord"
    case synthwave = "Synthwave"
    case dracula = "Dracula"
    case solarized = "Solarized"
    case monochrome = "Monochrome"

    var id: String { rawValue }

    var colors: ThemeColors {
        switch self {
        case .midnight:
            return ThemeColors(
                accent: Color(hex: "6E9EFF"),
                accentSecondary: Color(hex: "4ECDC4"),
                background: Color(hex: "0D1117"),
                surface: Color(hex: "161B22"),
                surfaceHover: Color(hex: "1C2333"),
                sidebar: Color(hex: "0D1117"),
                text: Color(hex: "E6EDF3"),
                textSecondary: Color(hex: "8B949E"),
                border: Color(hex: "30363D"),
                success: Color(hex: "3FB950"),
                warning: Color(hex: "D29922"),
                danger: Color(hex: "F85149"),
                formula: Color(hex: "6E9EFF"),
                cask: Color(hex: "BC8CFF")
            )
        case .nord:
            return ThemeColors(
                accent: Color(hex: "88C0D0"),
                accentSecondary: Color(hex: "81A1C1"),
                background: Color(hex: "2E3440"),
                surface: Color(hex: "3B4252"),
                surfaceHover: Color(hex: "434C5E"),
                sidebar: Color(hex: "2E3440"),
                text: Color(hex: "ECEFF4"),
                textSecondary: Color(hex: "D8DEE9"),
                border: Color(hex: "4C566A"),
                success: Color(hex: "A3BE8C"),
                warning: Color(hex: "EBCB8B"),
                danger: Color(hex: "BF616A"),
                formula: Color(hex: "88C0D0"),
                cask: Color(hex: "B48EAD")
            )
        case .synthwave:
            return ThemeColors(
                accent: Color(hex: "FF6AD5"),
                accentSecondary: Color(hex: "C774E8"),
                background: Color(hex: "1A1025"),
                surface: Color(hex: "241734"),
                surfaceHover: Color(hex: "2D1F42"),
                sidebar: Color(hex: "150D1E"),
                text: Color(hex: "F0E6FF"),
                textSecondary: Color(hex: "AD8CCD"),
                border: Color(hex: "3D2957"),
                success: Color(hex: "72F1B8"),
                warning: Color(hex: "FEDE5D"),
                danger: Color(hex: "FE4450"),
                formula: Color(hex: "36F9F6"),
                cask: Color(hex: "FF6AD5")
            )
        case .dracula:
            return ThemeColors(
                accent: Color(hex: "BD93F9"),
                accentSecondary: Color(hex: "FF79C6"),
                background: Color(hex: "282A36"),
                surface: Color(hex: "343746"),
                surfaceHover: Color(hex: "3E4155"),
                sidebar: Color(hex: "21222C"),
                text: Color(hex: "F8F8F2"),
                textSecondary: Color(hex: "6272A4"),
                border: Color(hex: "44475A"),
                success: Color(hex: "50FA7B"),
                warning: Color(hex: "F1FA8C"),
                danger: Color(hex: "FF5555"),
                formula: Color(hex: "8BE9FD"),
                cask: Color(hex: "BD93F9")
            )
        case .solarized:
            return ThemeColors(
                accent: Color(hex: "268BD2"),
                accentSecondary: Color(hex: "2AA198"),
                background: Color(hex: "002B36"),
                surface: Color(hex: "073642"),
                surfaceHover: Color(hex: "0A4050"),
                sidebar: Color(hex: "002B36"),
                text: Color(hex: "FDF6E3"),
                textSecondary: Color(hex: "839496"),
                border: Color(hex: "586E75"),
                success: Color(hex: "859900"),
                warning: Color(hex: "B58900"),
                danger: Color(hex: "DC322F"),
                formula: Color(hex: "268BD2"),
                cask: Color(hex: "6C71C4")
            )
        case .monochrome:
            return ThemeColors(
                accent: Color(hex: "CCCCCC"),
                accentSecondary: Color(hex: "999999"),
                background: Color(hex: "111111"),
                surface: Color(hex: "1A1A1A"),
                surfaceHover: Color(hex: "242424"),
                sidebar: Color(hex: "0E0E0E"),
                text: Color(hex: "E8E8E8"),
                textSecondary: Color(hex: "777777"),
                border: Color(hex: "333333"),
                success: Color(hex: "88CC88"),
                warning: Color(hex: "CCAA55"),
                danger: Color(hex: "CC5555"),
                formula: Color(hex: "AAAAAA"),
                cask: Color(hex: "888888")
            )
        }
    }
}

struct ThemeColors {
    let accent: Color
    let accentSecondary: Color
    let background: Color
    let surface: Color
    let surfaceHover: Color
    let sidebar: Color
    let text: Color
    let textSecondary: Color
    let border: Color
    let success: Color
    let warning: Color
    let danger: Color
    let formula: Color
    let cask: Color
}

// MARK: - Theme Manager

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @AppStorage("selectedTheme") private var storedTheme: String = AppTheme.midnight.rawValue

    @Published var current: AppTheme {
        didSet { storedTheme = current.rawValue }
    }

    var colors: ThemeColors { current.colors }

    private init() {
        self.current = AppTheme(rawValue: UserDefaults.standard.string(forKey: "selectedTheme") ?? "") ?? .midnight
    }
}

// MARK: - Color hex init

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
        default:
            r = 1; g = 1; b = 1
        }
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Environment key

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = ThemeColors(
        accent: .blue, accentSecondary: .purple,
        background: .black, surface: .gray, surfaceHover: .gray,
        sidebar: .black, text: .white, textSecondary: .gray,
        border: .gray, success: .green, warning: .orange, danger: .red,
        formula: .blue, cask: .purple
    )
}

extension EnvironmentValues {
    var theme: ThemeColors {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
