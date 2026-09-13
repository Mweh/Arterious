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
    var isFullWidth: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                if isLoading {
                    ProgressView()
                        .tint(style == .primary ? .white : AppColor.accent)
                        .scaleEffect(0.8)
                } else if let icon {
                    Image(systemName: icon)
                }

                Text(title)
            }
            .font(AppTypography.buttonLabel)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, isFullWidth ? AppSpacing.md : AppSpacing.sm + 2)
        }
        .buttonStyle(AppButtonStyle(style: style))
        .disabled(isLoading)
    }
}

/// Native SwiftUI ButtonStyle for Arterious buttons
struct AppButtonStyle: ButtonStyle {
    var style: AppButton.Style

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(style == .primary ? .white : AppColor.accent)
            .background(
                Capsule()
                    .fill(style == .primary ? AppColor.accent : Color.clear)
            )
            .overlay(
                Capsule()
                    .stroke(AppColor.accent, lineWidth: style == .secondary ? 1.5 : 0)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
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
