import SwiftUI

/// Centralized color tokens for Arterious derived from the Figma Color Naming Convention.
enum AppColor {

    // MARK: - Figma: Brand Color

    enum Brand {
        /// BrandColor/Primary/Blue — HEX: #0088FF (100%)
        static let primaryBlue = Color(hex: "0088FF")
    }

    // MARK: - Figma: Background

    enum Background {
        /// Background/Primary/Gray25 — HEX: #F2F2F7 (100%)
        static let primaryGray25 = Color(hex: "F2F2F7")

        /// Background/Secondary/White — HEX: #FFFFFF (100%)
        static let secondaryWhite = Color(hex: "FFFFFF")
    }

    // MARK: - Figma: AccentColor (Semantic)

    enum Accent {
        /// AccentColor/Semantic/Red — HEX: #FF383C (100%)
        static let red = Color(hex: "FF383C")

        /// AccentColor/Semantic/Green — HEX: #34C759 (100%)
        static let green = Color(hex: "34C759")

        /// AccentColor/Semantic/Blue12 — HEX: #0088FF (12%)
        static let blue12 = Color(hex: "0088FF", opacity: 0.12)

        /// AccentColor/Semantic/Red12 — HEX: #FF383C (12%)
        static let red12 = Color(hex: "FF383C", opacity: 0.12)

        /// AccentColor/Semantic/Green12 — HEX: #34C759 (12%)
        static let green12 = Color(hex: "34C759", opacity: 0.12)
    }

    // MARK: - Figma: Gray

    enum Gray {
        /// Gray/Main/Gray100 — HEX: #000000 (100%)
        static let gray100 = Color(hex: "000000")

        /// Gray/Main/Gray50 — HEX: #3C3C43 (100%)
        static let gray50 = Color(hex: "3C3C43")
    }

    // MARK: - Figma: Separator

    enum Separator {
        /// Separator/Main/Gray12 — HEX: #000000 (12%)
        static let gray12 = Color(hex: "000000", opacity: 0.12)
    }

    // MARK: - Semantic Aliases (For Codebase Usability & Compatibility)

    /// Primary brand blue (BrandColor/Primary/Blue)
    static let primaryBlue = Brand.primaryBlue

    /// Primary action accent (BrandColor/Primary/Blue)
    static let accent = Brand.primaryBlue

    /// Primary action CTA blue (BrandColor/Primary/Blue)
    static let actionBlue = Brand.primaryBlue

    /// Primary grouped background (Background/Primary/Gray25)
    static let backgroundPrimary = Background.primaryGray25

    /// Secondary card background (Background/Secondary/White)
    static let backgroundSecondary = Background.secondaryWhite

    /// Primary text color (Gray/Main/Gray100)
    static let textPrimary = Gray.gray100

    /// Secondary / caption text color (Gray/Main/Gray50)
    static let textSecondary = Gray.gray50

    /// Subtle separator line (Separator/Main/Gray12)
    static let separator = Separator.gray12

    /// Semantic Red (AccentColor/Semantic/Red)
    static let semanticRed = Accent.red

    /// Semantic Green (AccentColor/Semantic/Green)
    static let semanticGreen = Accent.green

    /// Tinted 12% Blue (AccentColor/Semantic/Blue12)
    static let semanticBlue12 = Accent.blue12

    /// Tinted 12% Red (AccentColor/Semantic/Red12)
    static let semanticRed12 = Accent.red12

    /// Tinted 12% Green (AccentColor/Semantic/Green12)
    static let semanticGreen12 = Accent.green12

    // MARK: - Feature / Status Convenience Tokens

    /// Caution / alert indicator
    static let caution = Accent.red

    /// Caution card tinted background
    static let cautionBackground = Accent.red12

    /// Caution card border
    static let cautionBorder = Accent.red.opacity(0.30)

    /// Healthy status green
    static let healthy = Accent.green

    /// Informational blue
    static let info = Brand.primaryBlue

    /// Role parent tint
    static let roleParent = Brand.primaryBlue

    /// Role child tint
    static let roleChild = Accent.green

    /// Tertiary fill for inner elements
    static let backgroundTertiary = Separator.gray12

    /// Subtle fill used for tag/chip backgrounds
    static let fillSecondary = Separator.gray12
}

// MARK: - Color Hex Initializer Helper

extension Color {
    /// Initializes a Color from a 6-character hex string (e.g. "0088FF" or "#0088FF") with optional opacity.
    init(hex: String, opacity: Double = 1.0) {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var intVal: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&intVal)

        let r, g, b: UInt64
        switch cleanHex.count {
        case 6:
            r = (intVal >> 16) & 0xFF
            g = (intVal >> 8) & 0xFF
            b = intVal & 0xFF
        default:
            r = 0
            g = 0
            b = 0
        }

        self.init(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: opacity
        )
    }
}
