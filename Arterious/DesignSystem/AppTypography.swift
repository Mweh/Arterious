import SwiftUI

/// Centralized typography tokens for Arterious derived from the Figma Typography Naming Convention.
enum AppTypography {

    // MARK: - Figma: LargeTitle

    /// LargeTitle/Bold
    static let largeTitleBold: Font = .largeTitle.weight(.bold)

    /// LargeTitle/Regular
    static let largeTitleRegular: Font = .largeTitle.weight(.regular)

    // MARK: - Figma: Title 1

    /// Title1/Regular
    static let title1Regular: Font = .title.weight(.regular)

    // MARK: - Figma: Title 2

    /// Title2/Bold
    static let title2Bold: Font = .title2.weight(.bold)

    /// Title2/Regular
    static let title2Regular: Font = .title2.weight(.regular)

    // MARK: - Figma: Title 3

    /// Title3/Bold
    static let title3Bold: Font = .title3.weight(.bold)

    /// Title3/Regular
    static let title3Regular: Font = .title3.weight(.regular)

    // MARK: - Figma: Body

    /// Body/Semibold
    static let bodySemibold: Font = .body.weight(.semibold)

    /// Body/Medium
    static let bodyMedium: Font = .body.weight(.medium)

    /// Body/Regular
    static let bodyRegular: Font = .body.weight(.regular)

    // MARK: - Figma: Callout

    /// Callout/Bold
    static let calloutBold: Font = .callout.weight(.bold)

    // MARK: - Figma: Subheadline

    /// Subheadline/Bold
    static let subheadlineBold: Font = .subheadline.weight(.bold)

    /// Subheadline/Regular
    static let subheadlineRegular: Font = .subheadline.weight(.regular)

    // MARK: - Figma: Footnote

    /// Footnote/Regular
    static let footnoteRegular: Font = .footnote.weight(.regular)

    // MARK: - Figma: Caption

    /// Caption/Bold
    static let captionBold: Font = .caption.weight(.bold)

    /// Caption/Regular
    static let captionRegular: Font = .caption.weight(.regular)

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

    /// Rounded metric value display (Dynamic Type capable)
    static let metricValue: Font = .system(.title2, design: .rounded, weight: .bold)

    /// Standard button label (Body/Semibold)
    static let buttonLabel: Font = bodySemibold
}
