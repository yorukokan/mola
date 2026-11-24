import SwiftUI
import UIKit

// MARK: - Renk yardımcıları

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }

    /// Açık ve koyu görünüm için ayrı renk.
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { trait in
            let hex = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                           green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255,
                           alpha: 1)
        })
    }
}

// MARK: - Plaka renkleri (olimpik bumper plakalarından)

enum Plate: Int, Codable, CaseIterable, Hashable {
    case red, blue, yellow, green

    var color: Color {
        switch self {
        case .red: return Color(hex: 0xE5484D)
        case .blue: return Color(hex: 0x3D6FE6)
        case .yellow: return Color(hex: 0xEFAE2B)
        case .green: return Color(hex: 0x2E9E6A)
        }
    }

    /// Plaka üzerindeki yazı rengi
    var onColor: Color {
        self == .yellow ? Color(hex: 0x2A1F05) : .white
    }

    var kg: Int {
        switch self {
        case .red: return 25
        case .blue: return 20
        case .yellow: return 15
        case .green: return 10
        }
    }

    /// Çizimde plakanın yüksekliği (0-1)
    var heightRatio: CGFloat {
        switch self {
        case .red: return 1.0
        case .blue: return 0.92
        case .yellow: return 0.84
        case .green: return 0.76
        }
    }
}

// MARK: - Arayüz renkleri

enum Ink {
    static let canvas = Color.dynamic(light: 0xEEF0F2, dark: 0x0C0E11)
    static let surface = Color.dynamic(light: 0xFFFFFF, dark: 0x171A1F)
    static let surface2 = Color.dynamic(light: 0xF5F6F8, dark: 0x21252B)
    static let line = Color.dynamic(light: 0xE0E3E8, dark: 0x2C3138)
    static let primary = Color.dynamic(light: 0x0F1216, dark: 0xF2F4F7)
    static let secondary = Color.dynamic(light: 0x5D6570, dark: 0x9EA6B2)
    static let tertiary = Color.dynamic(light: 0x9AA1AB, dark: 0x5F6772)
    static let steel = Color.dynamic(light: 0xB9BFC7, dark: 0x4A515B)
    static let steelDark = Color.dynamic(light: 0x8A919B, dark: 0x6B737E)
    static let positive = Color(hex: 0x2E9E6A)
}

// MARK: - Yazı stilleri

enum PFont {
    /// Rutin adları: geniş, ağır, spor hissi
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .default)
    }
    /// Kilo, tekrar, süre: yuvarlak, sabit genişlikli rakamlar
    static func number(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }
    static func label(_ size: CGFloat = 13, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight)
    }
}
