import SwiftUI

/// Centralized corner radius tokens for Arterious derived from the Figma Shape style guide.
enum AppRadius {

    // MARK: - Figma: Shape (Corner Radius)

    /// 24 pt — standard card & container corner radius (from Figma Shape)
    static let r24: CGFloat = 24

    /// 32 pt — prominent card & dialog corner radius (from Figma Shape)
    static let r32: CGFloat = 32

    /// 34 pt — large surface corner radius (from Figma Shape)
    static let r34: CGFloat = 34

    /// 38 pt — full sheet & modal corner radius (from Figma Shape)
    static let r38: CGFloat = 38

    // MARK: - Semantic Aliases (For Codebase Usability & Compatibility)

    /// 8 pt — small elements like badges and chips.
    static let sm: CGFloat = 8

    /// 12 pt — compact inner containers and badges.
    static let md: CGFloat = 12

    /// 24 pt — standard cards (matches Figma r24).
    static let lg: CGFloat = 24

    /// 32 pt — prominent cards (matches Figma r32).
    static let xl: CGFloat = 32

    /// 38 pt — sheets & outer surfaces (matches Figma r38).
    static let xxl: CGFloat = 38
}
