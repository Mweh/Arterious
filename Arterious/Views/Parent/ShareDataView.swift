import SwiftUI

/// Confirmation view for sharing health data with a selected contact.
struct ShareDataView: View {

    let contactName: String
    let contactPhone: String
    let onBack: () -> Void
    let onDismiss: () -> Void
    let onConfirm: () -> Void

    private var initial: String {
        String(contactName.prefix(1)).uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Bar
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColor.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppColor.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.sm)

            Spacer()
                .frame(height: AppSpacing.xl * 1.5)

            // Center Graphic: Health Card → Contact Avatar
            HStack(spacing: AppSpacing.lg) {
                // Health Document Card
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .stroke(AppColor.textPrimary, lineWidth: 2)
                        .frame(width: 52, height: 58)

                    VStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(AppColor.textPrimary)

                        Rectangle()
                            .fill(AppColor.textPrimary)
                            .frame(width: 24, height: 2)

                        Rectangle()
                            .fill(AppColor.textPrimary)
                            .frame(width: 18, height: 2)
                    }
                }

                Image(systemName: "arrow.right")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(AppColor.textSecondary)

                // Contact Avatar
                ZStack {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 56, height: 56)

                    Text(initial.isEmpty ? "A" : initial)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppColor.textPrimary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, AppSpacing.xl * 1.5)

            // Content Copy
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Share Data")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)

                Text("Granting access allows the person you choose to view your health trends regularly and receive alerts when unusual changes occur.")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColor.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, AppSpacing.lg)

            Spacer()

            // Actions
            VStack(spacing: AppSpacing.sm) {
                AppButton(
                    title: "Continue",
                    isFullWidth: true,
                    action: onConfirm
                )

                Button(action: onDismiss) {
                    Text("Cancel")
                        .font(AppTypography.buttonLabel)
                        .foregroundStyle(AppColor.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .background(Color(.systemGray6))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppColor.backgroundSecondary)
    }
}

#Preview {
    ShareDataView(
        contactName: "Alex Morgan",
        contactPhone: "+1 (555) 123-4567",
        onBack: { },
        onDismiss: { },
        onConfirm: { }
    )
}
