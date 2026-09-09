import SwiftUI

/// A full-screen or in-list empty state illustration with title and description.
///
/// Usage:
/// ```swift
/// EmptyStateView(
///     icon: "chart.xyaxis.line",
///     title: "No Trends Yet",
///     message: "Check back after a few days of data."
/// )
/// // With an optional action button:
/// EmptyStateView(
///     icon: "heart.slash",
///     title: "No Health Data",
///     message: "Allow Arterious to read HealthKit data in Settings.",
///     actionTitle: "Open Settings"
/// ) {
///     // open settings
/// }
/// ```
struct EmptyStateView: View {

    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(AppColor.textSecondary)

            VStack(spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.title)
                    .foregroundStyle(AppColor.textPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(AppTypography.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let actionTitle, let action {
                AppButton(title: actionTitle, action: action)
            }
        }
        .padding(AppSpacing.xxl)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    VStack {
        EmptyStateView(
            icon: "chart.xyaxis.line",
            title: "No Trends Yet",
            message: "Check back after a few days of collected data to see health trends."
        )

        EmptyStateView(
            icon: "heart.slash",
            title: "Health Access Needed",
            message: "Allow Arterious to read HealthKit data so we can keep an eye on your parent's wellness.",
            actionTitle: "Open Settings"
        ) { }
    }
    .background(AppColor.backgroundPrimary)
}
