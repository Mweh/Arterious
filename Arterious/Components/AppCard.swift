import SwiftUI

/// A surface container that applies the standard Arterious card appearance.
///
/// Wraps any content in a rounded, elevated card using design tokens.
///
/// Usage:
/// ```swift
/// AppCard {
///     Text("Some content")
/// }
/// AppCard(padding: AppSpacing.lg) {
///     MetricCardView(...)
/// }
/// ```
struct AppCard<Content: View>: View {

    var padding: CGFloat = AppSpacing.lg
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
    }
}

#Preview {
    VStack(spacing: AppSpacing.md) {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Card Title")
                    .font(AppTypography.headline)
                Text("Supporting detail text goes here.")
                    .font(AppTypography.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }

        AppCard(padding: AppSpacing.md) {
            Text("Compact padding card")
                .font(AppTypography.caption)
        }
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}
