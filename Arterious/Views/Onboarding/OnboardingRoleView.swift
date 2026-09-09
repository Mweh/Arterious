import SwiftUI

/// Second step of onboarding: Selecting whether user is Parent or Child.
struct OnboardingRoleView: View {

    @Binding var selectedRole: UserRole
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
                .frame(height: AppSpacing.xxl)

            // Header
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Start with\nyour role")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)
                    .lineSpacing(2)

                Text("Choose the role that best suits you so we can provide the best experience.")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, AppSpacing.xs)
            }
            .padding(.bottom, AppSpacing.xl * 1.2)

            // Role Selection Cards
            VStack(spacing: AppSpacing.md) {
                roleCard(
                    role: .parent,
                    iconName: "person.fill",
                    iconColor: AppColor.roleParent,
                    iconBgColor: AppColor.roleParent.opacity(0.14)
                )

                roleCard(
                    role: .child,
                    iconName: "person.2.fill",
                    iconColor: AppColor.roleChild,
                    iconBgColor: AppColor.roleChild.opacity(0.14)
                )
            }

            Spacer()

            // Continue Button
            AppButton(
                title: "Continue",
                isFullWidth: true,
                action: onContinue
            )
            .padding(.bottom, AppSpacing.lg)
        }
        .padding(.horizontal, AppSpacing.lg)
        .background(AppColor.backgroundPrimary.ignoresSafeArea())
    }

    // MARK: - Role Card

    private func roleCard(
        role: UserRole,
        iconName: String,
        iconColor: Color,
        iconBgColor: Color
    ) -> some View {
        let isSelected = selectedRole == role

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                selectedRole = role
            }
        } label: {
            HStack(alignment: .center, spacing: AppSpacing.md) {
                // Radio indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? AppColor.actionBlue : Color(.systemGray3))

                // Circular Icon Avatar
                ZStack {
                    Circle()
                        .fill(iconBgColor)
                        .frame(width: 48, height: 48)

                    Image(systemName: iconName)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(iconColor)
                }

                // Text Content
                VStack(alignment: .leading, spacing: 3) {
                    Text(role.title)
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColor.textPrimary)

                    Text(role.description)
                        .font(AppTypography.subheadline)
                        .foregroundStyle(AppColor.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(AppSpacing.lg)
            .background(AppColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.xl)
                    .stroke(
                        isSelected ? AppColor.actionBlue.opacity(0.3) : Color(.separator).opacity(0.4),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .shadow(
                color: Color.black.opacity(isSelected ? 0.04 : 0.02),
                radius: 6,
                x: 0,
                y: 2
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @State var role: UserRole = .parent
    OnboardingRoleView(selectedRole: $role) { }
}
