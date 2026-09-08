import SwiftUI

/// Centralized color tokens for Arterious.
/// Use these instead of inline Color literals throughout the app.
enum AppColor {

    // MARK: - Brand

    /// Primary brand accent. Used for buttons, active states, and icons.
    static let accent = Color.accentColor

    /// Wellness caution indicator color.
    static let caution = Color.orange

    /// Positive / healthy status color.
    static let healthy = Color.green

    /// Neutral / informational status color.
    static let info = Color.blue

    // MARK: - Backgrounds

    /// Primary grouped screen background (matches iOS grouped table style).
    static let backgroundPrimary = Color(.systemGroupedBackground)

    /// Elevated card / secondary surface background.
    static let backgroundSecondary = Color(.secondarySystemGroupedBackground)

    /// Tertiary fill for inner elements (badges, pills).
    static let backgroundTertiary = Color(.tertiarySystemFill)

    // MARK: - Text

    /// Main body text color.
    static let textPrimary = Color.primary

    /// Labels, metadata, subtitles.
    static let textSecondary = Color.secondary

    // MARK: - Borders & Fills

    /// Subtle fill used for tag/chip backgrounds.
    static let fillSecondary = Color(.secondarySystemFill)

    /// Caution card tinted background.
    static let cautionBackground = Color.orange.opacity(0.12)

    /// Caution card border.
    static let cautionBorder = Color.orange.opacity(0.30)
}
