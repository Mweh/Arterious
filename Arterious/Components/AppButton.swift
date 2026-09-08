import SwiftUI

/// A configurable primary action button following Apple HIG.
///
/// Usage:
/// ```swift
/// AppButton("Call Mom", icon: "phone.fill") {
///     // action
/// }
/// AppButton("Refresh", style: .secondary) { }
/// ```
struct AppButton: View {

    enum Style {
        /// Filled background — for primary actions.
        case primary
        /// Capsule outline — for secondary / destructive-neutral actions.
        case secondary
    }

    let title: String
    var icon: String?
    var style: Style = .primary
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                if isLoading {
                    ProgressView()
                        .tint(foregroundColor)
                        .scaleEffect(0.8)
                } else if let icon {
                    Image(systemName: icon)
                }

                Text(title)
            }
            .font(AppTypography.buttonLabel)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.sm + 2)
            .background(background)
            .clipShape(Capsule())
        }
        .disabled(isLoading)
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .primary:
            Capsule().fill(AppColor.accent)
        case .secondary:
            Capsule()
                .stroke(AppColor.accent, lineWidth: 1.5)
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return AppColor.accent
        }
    }
}

#Preview {
    VStack(spacing: AppSpacing.md) {
        AppButton(title: "Call Mom", icon: "phone.fill") { }
        AppButton(title: "Refresh", icon: "arrow.clockwise", style: .secondary) { }
        AppButton(title: "Loading...", isLoading: true) { }
    }
    .padding()
}
