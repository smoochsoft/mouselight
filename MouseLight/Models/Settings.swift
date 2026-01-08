import Foundation
import SwiftUI

enum SpotlightShape: String, CaseIterable {
    case circle = "circle"
    case square = "square"
    case triangle = "triangle"
    case star = "star"
    case trapezoid = "trapezoid"
    case cloud = "cloud"

    var displayName: String {
        switch self {
        case .circle: return "Circle"
        case .square: return "Square"
        case .triangle: return "Triangle"
        case .star: return "Star"
        case .trapezoid: return "Trapezoid"
        case .cloud: return "Cloud"
        }
    }

    var iconName: String {
        switch self {
        case .circle: return "circle"
        case .square: return "square"
        case .triangle: return "triangle"
        case .star: return "star"
        case .trapezoid: return "trapezoid.and.line.horizontal"
        case .cloud: return "cloud"
        }
    }
}

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // MARK: - Spotlight Settings
    @AppStorage("spotlightEnabled") var spotlightEnabled: Bool = true
    @AppStorage("spotlightRadius") var spotlightRadius: Double = 100
    @AppStorage("spotlightShape") var spotlightShapeRaw: String = SpotlightShape.circle.rawValue

    var spotlightShape: SpotlightShape {
        get { SpotlightShape(rawValue: spotlightShapeRaw) ?? .circle }
        set { spotlightShapeRaw = newValue.rawValue }
    }
    @AppStorage("spotlightDimOpacity") var spotlightDimOpacity: Double = 0.7
    @AppStorage("spotlightAnimationDuration") var spotlightAnimationDuration: Double = 0.3
    @AppStorage("spotlightBlur") var spotlightBlur: Double = 20 // percentage for edge blur
    @AppStorage("animateZoom") var animateZoom: Bool = true
    @AppStorage("autoDeactivate") var autoDeactivate: Bool = false
    @AppStorage("autoDeactivateSeconds") var autoDeactivateSeconds: Double = 10.0

    // MARK: - Click Indicator Settings
    @AppStorage("clicksEnabled") var clicksEnabled: Bool = true
    @AppStorage("clicksStandalone") var clicksStandalone: Bool = false // only works with spotlight by default
    @AppStorage("clickRadius") var clickRadius: Double = 30
    @AppStorage("clickColor") var clickColorHex: String = "#FF3B30" // single color for all clicks
    @AppStorage("clickAnimationDuration") var clickAnimationDuration: Double = 0.3

    // MARK: - Hotkey Settings
    // NSEvent.ModifierFlags: .command = 0x100000, .shift = 0x20000, .option = 0x80000, .control = 0x40000
    @AppStorage("spotlightHotkeyModifiers") var spotlightHotkeyModifiers: Int = 0x120000 // Command + Shift (0x100000 + 0x20000)
    @AppStorage("spotlightHotkeyKeyCode") var spotlightHotkeyKeyCode: Int = 46 // M key
    @AppStorage("clicksHotkeyModifiers") var clicksHotkeyModifiers: Int = 0
    @AppStorage("clicksHotkeyKeyCode") var clicksHotkeyKeyCode: Int = 0

    // MARK: - General Settings
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("showInDock") var showInDock: Bool = false
    @AppStorage("showInMenuBar") var showInMenuBar: Bool = true
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false

    // MARK: - Computed Colors
    var clickColor: NSColor {
        NSColor(hex: clickColorHex) ?? .systemRed
    }

    // MARK: - Validated Getters (for use in drawing/animation code)

    var validatedSpotlightRadius: CGFloat {
        max(10, min(500, CGFloat(spotlightRadius)))
    }

    var validatedDimOpacity: CGFloat {
        max(0.1, min(1.0, CGFloat(spotlightDimOpacity)))
    }

    var validatedClickRadius: CGFloat {
        max(5, min(100, CGFloat(clickRadius)))
    }

    var validatedAnimationDuration: Double {
        max(0.1, min(2.0, spotlightAnimationDuration))
    }

    var validatedClickAnimationDuration: Double {
        max(0.1, min(2.0, clickAnimationDuration))
    }

    var validatedAutoDeactivateSeconds: Double {
        max(1.0, min(300.0, autoDeactivateSeconds))
    }

    private init() {}

    // MARK: - Hotkey Helpers
    func spotlightHotkeyString() -> String {
        return formatHotkey(modifiers: spotlightHotkeyModifiers, keyCode: spotlightHotkeyKeyCode)
    }

    func clicksHotkeyString() -> String {
        if clicksHotkeyKeyCode == 0 { return "Not Set" }
        return formatHotkey(modifiers: clicksHotkeyModifiers, keyCode: clicksHotkeyKeyCode)
    }

    private func formatHotkey(modifiers: Int, keyCode: Int) -> String {
        var parts: [String] = []
        let flags = NSEvent.ModifierFlags(rawValue: UInt(modifiers))

        if flags.contains(.control) { parts.append("\u{2303}") }
        if flags.contains(.option) { parts.append("\u{2325}") }
        if flags.contains(.shift) { parts.append("\u{21E7}") }
        if flags.contains(.command) { parts.append("\u{2318}") }

        if let keyName = keyCodeToString(keyCode) {
            parts.append(keyName)
        }

        return parts.joined()
    }

    private func keyCodeToString(_ keyCode: Int) -> String? {
        let keyMap: [Int: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: ".", 50: "`",
            36: "\u{21A9}", 48: "\u{21E5}", 49: "Space", 51: "\u{232B}",
            53: "Esc", 123: "\u{2190}", 124: "\u{2192}", 125: "\u{2193}", 126: "\u{2191}"
        ]
        return keyMap[keyCode]
    }
}

// MARK: - Color Hex Extension
extension NSColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }

    var hexString: String {
        guard let rgbColor = usingColorSpace(.sRGB) else { return "#000000" }
        let r = Int(rgbColor.redComponent * 255)
        let g = Int(rgbColor.greenComponent * 255)
        let b = Int(rgbColor.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
