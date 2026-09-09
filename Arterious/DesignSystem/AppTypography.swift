import SwiftUI

/// Centralized typography tokens for Arterious derived from the Figma Typography Naming Convention.
enum AppTypography {

    // MARK: - Figma: LargeTitle

    /// LargeTitle/Bold — Size: 34, Weight: Bold, Line Height: 41
    static let largeTitleBold: Font = .system(size: 34, weight: .bold)

    /// LargeTitle/Regular — Size: 34, Weight: Regular, Line Height: 41
    static let largeTitleRegular: Font = .system(size: 34, weight: .regular)

    // MARK: - Figma: Title 1

    /// Title1/Regular — Size: 28, Weight: Regular, Line Height: 34
    static let title1Regular: Font = .system(size: 28, weight: .regular)

    // MARK: - Figma: Title 2

    /// Title2/Bold — Size: 22, Weight: Bold, Line Height: 26
    static let title2Bold: Font = .system(size: 22, weight: .bold)

    /// Title2/Regular — Size: 22, Weight: Regular, Line Height: 26
    static let title2Regular: Font = .system(size: 22, weight: .regular)

    // MARK: - Figma: Title 3

    /// Title3/Bold — Size: 20, Weight: Bold, Line Height: 25
    static let title3Bold: Font = .system(size: 20, weight: .bold)

    /// Title3/Regular — Size: 20, Weight: Regular, Line Height: 25
    static let title3Regular: Font = .system(size: 20, weight: .regular)

    // MARK: - Figma: Body

    /// Body/Semibold — Size: 17, Weight: Semibold, Line Height: 22
    static let bodySemibold: Font = .system(size: 17, weight: .semibold)

    /// Body/Medium — Size: 17, Weight: Medium, Line Height: 22
    static let bodyMedium: Font = .system(size: 17, weight: .medium)

    /// Body/Regular — Size: 17, Weight: Regular, Line Height: 22
    static let bodyRegular: Font = .system(size: 17, weight: .regular)

    // MARK: - Figma: Callout

    /// Callout/Bold — Size: 16, Weight: Bold, Line Height: 21
    static let calloutBold: Font = .system(size: 16, weight: .bold)

    // MARK: - Figma: Subheadline

    /// Subheadline/Bold — Size: 15, Weight: Bold, Line Height: 20
    static let subheadlineBold: Font = .system(size: 15, weight: .bold)

    /// Subheadline/Regular — Size: 15, Weight: Regular, Line Height: 20
    static let subheadlineRegular: Font = .system(size: 15, weight: .regular)

    // MARK: - Figma: Footnote

    /// Footnote/Regular — Size: 13, Weight: Regular, Line Height: 18
    static let footnoteRegular: Font = .system(size: 13, weight: .regular)

    // MARK: - Figma: Caption

    /// Caption/Regular — Size: 12, Weight: Regular, Line Height: 16
    static let captionRegular: Font = .system(size: 12, weight: .regular)

    // MARK: - Semantic Aliases (For Codebase Usability & Backwards Compatibility)

    /// Large navigation / screen hero titles (LargeTitle/Bold)
    static let largeTitle: Font = largeTitleBold

    /// Card or section titles (Title3/Bold)
    static let title: Font = title3Bold

    /// Section headers and group labels (Body/Semibold)
    static let headline: Font = bodySemibold

    /// Primary body content (Body/Regular)
    static let body: Font = bodyRegular

    /// Card subheadings and labels (Subheadline/Regular)
    static let subheadline: Font = subheadlineRegular

    /// Tags, badges, timestamps (Caption/Regular)
    static let caption: Font = captionRegular

    /// Smallest labels / comparison deltas (Caption/Regular)
    static let caption2: Font = captionRegular

    /// Rounded metric value display (e.g., "72 BPM")
    static let metricValue: Font = .system(size: 22, weight: .bold, design: .rounded)

    /// Standard button label (Body/Semibold)
    static let buttonLabel: Font = bodySemibold
}
