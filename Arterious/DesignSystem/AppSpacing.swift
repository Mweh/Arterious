import Foundation

/// Centralized spacing scale for Arterious.
/// Use these constants instead of inline magic numbers for padding, spacing, and gaps.
enum AppSpacing {

    /// 4 pt — tight internal element gap (e.g., icon + label).
    static let xs: CGFloat = 4

    /// 8 pt — default small gap between related elements.
    static let sm: CGFloat = 8

    /// 12 pt — default grid spacing and compact section gaps.
    static let md: CGFloat = 12

    /// 16 pt — standard content padding (card inner horizontal).
    static let lg: CGFloat = 16

    /// 20 pt — section-level vertical spacing.
    static let xl: CGFloat = 20

    /// 24 pt — large section separators and bottom safe-area padding.
    static let xxl: CGFloat = 24
}
