import SwiftUI

/// Second step of onboarding: Selecting whether user is Parent or Child.
struct OnboardingRoleView: View {

    @Binding var selectedRole: UserRole
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // MARK: - Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Mulai dengan\nperan Anda")
                    .font(AppTypography.largeTitleBold) // SF Pro 34 Bold
                    .foregroundStyle(AppColor.textPrimary)
                    .lineSpacing(4) // Line height 41

                Text("Pilih peran yang paling sesuai agar kami dapat memberikan pengalaman terbaik untuk Anda.")
                    .font(AppTypography.bodyRegular) // SF Pro 17 Regular
                    .foregroundStyle(AppColor.textSecondary)
                    .lineSpacing(4) // Line height 22
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
            .padding(.top, 20)
            .padding(.bottom, 28)

            // MARK: - Role Selection Cards
            VStack(spacing: 16) {
                roleCard(
                    role: .parent,
                    iconName: "person.fill",
                    iconColor: AppColor.Brand.primaryBlue,
                    iconBgColor: Color(hex: "0088FF", opacity: 0.16)
                )

                roleCard(
                    role: .child,
                    iconName: "person.2.fill",
                    iconColor: AppColor.Accent.green,
                    iconBgColor: Color(hex: "34C759", opacity: 0.16)
                )
            }

            Spacer()

            // MARK: - Lanjut Button
            Button(action: onContinue) {
                Text("Lanjut")
                    .font(AppTypography.bodySemibold) // SF Pro 17 Semibold
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AppColor.Brand.primaryBlue)
                    .clipShape(Capsule())
            }
            .padding(.bottom, AppSpacing.xl)
        }
        .padding(.horizontal, AppSpacing.lg + 4)
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
            HStack(alignment: .center, spacing: 14) {
                // Radio indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? AppColor.Brand.primaryBlue : Color(.systemGray4))

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
                VStack(alignment: .leading, spacing: 4) {
                    Text(role.title)
                        .font(AppTypography.bodySemibold) // SF Pro 17 Semibold
                        .foregroundStyle(AppColor.textPrimary)

                    Text(role.description)
                        .font(AppTypography.subheadlineRegular) // SF Pro 15 Regular
                        .foregroundStyle(AppColor.textSecondary)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(2) // Line height 20
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.r24))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.r24)
                    .stroke(Color.black.opacity(0.04), lineWidth: 1)
            )
            .shadow(
                color: Color.black.opacity(0.03),
                radius: 8,
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
