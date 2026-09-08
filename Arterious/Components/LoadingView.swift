import SwiftUI

/// An inline or full-screen loading indicator with an optional label.
///
/// Usage:
/// ```swift
/// // Inline spinner only:
/// LoadingView()
///
/// // With a message:
/// LoadingView(message: "Reading health data…")
/// ```
struct LoadingView: View {

    var message: String?

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            ProgressView()
                .controlSize(.large)

            if let message {
                Text(message)
                    .font(AppTypography.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppSpacing.xxl)
    }
}

#Preview {
    VStack(spacing: AppSpacing.xxl) {
        LoadingView()
        LoadingView(message: "Reading health data…")
    }
    .background(AppColor.backgroundPrimary)
}
