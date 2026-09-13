import SwiftUI

enum HUDType {
    case success
    case failure
}

struct ConnectionHUDState: Equatable {
    let type: HUDType
    let title: String
    let message: String
}

/// A native Apple-style centered status HUD displaying success (✓) or failure (✗)
/// with frosted liquid glass material, smooth spring animation, and haptic feedback.
struct NativeStatusHUD: View {
    let type: HUDType
    let title: String
    let message: String
    var onDismiss: (() -> Void)? = nil

    @State private var isVisible: Bool = false

    var body: some View {
        ZStack {
            // Subtle dimmed background that dismisses on tap
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            // Apple Native Center HUD Card
            VStack(spacing: AppSpacing.md) {
                // Native Icon with soft background circle
                ZStack {
                    Circle()
                        .fill(iconBackgroundColor)
                        .frame(width: 68, height: 68)

                    Image(systemName: iconName)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(iconForegroundColor)
                }
                .padding(.top, AppSpacing.xs)

                VStack(spacing: AppSpacing.xs) {
                    Text(title)
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColor.textPrimary)
                        .multilineTextAlignment(.center)

                    if !message.isEmpty {
                        Text(message)
                            .font(AppTypography.subheadlineRegular)
                            .foregroundStyle(AppColor.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.vertical, AppSpacing.lg)
            .frame(minWidth: 210, maxWidth: 280)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.r24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.r24, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.14), radius: 24, x: 0, y: 10)
            .scaleEffect(isVisible ? 1.0 : 0.85)
            .opacity(isVisible ? 1.0 : 0.0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                isVisible = true
            }

            // Trigger native haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            switch type {
            case .success:
                generator.notificationOccurred(.success)
            case .failure:
                generator.notificationOccurred(.error)
            }

            // Auto dismiss timer
            let dismissDelay: Double = (type == .success) ? 2.5 : 3.5
            DispatchQueue.main.asyncAfter(deadline: .now() + dismissDelay) {
                dismiss()
            }
        }
    }

    private func dismiss() {
        guard isVisible else { return }
        withAnimation(.easeInOut(duration: 0.22)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            onDismiss?()
        }
    }

    private var iconName: String {
        switch type {
        case .success:
            return "checkmark"
        case .failure:
            return "xmark"
        }
    }

    private var iconForegroundColor: Color {
        switch type {
        case .success:
            return AppColor.Accent.green
        case .failure:
            return AppColor.Accent.red
        }
    }

    private var iconBackgroundColor: Color {
        switch type {
        case .success:
            return AppColor.Accent.green12
        case .failure:
            return AppColor.Accent.red12
        }
    }
}

#Preview("Success") {
    NativeStatusHUD(
        type: .success,
        title: "Berhasil Terhubung",
        message: "Terhubung dengan Orang Tua"
    )
}

#Preview("Failure") {
    NativeStatusHUD(
        type: .failure,
        title: "Gagal Terhubung",
        message: "Tautan undangan tidak valid atau sudah kadaluarsa."
    )
}
