import SwiftUI

/// Centralized typography tokens for Arterious.
/// Provides semantic Font values so screens stay typographically consistent.
enum AppTypography {

    /// Large navigation / page titles.
    static let largeTitle: Font = .largeTitle.weight(.bold)

    /// Card or section titles.
    static let title: Font = .title3.weight(.bold)

    /// Section headers and group labels.
    static let headline: Font = .headline

    /// Primary body content.
    static let body: Font = .body

    /// Card subheadings and labels.
    static let subheadline: Font = .subheadline

    /// Tags, badges, timestamps.
    static let caption: Font = .caption

    /// Smallest labels — e.g., comparison deltas.
    static let caption2: Font = .caption2

    // MARK: - Styled variants

    /// Rounded, bold metric value display (e.g., "72 BPM").
    static let metricValue: Font = .system(.title2, design: .rounded, weight: .bold)

    /// Semibold button label.
    static let buttonLabel: Font = .subheadline.weight(.semibold)
}
