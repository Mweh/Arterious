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
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)
                    .lineSpacing(2)

                Text("Pilih peran yang paling sesuai agar kami dapat memberikan pengalaman terbaik untuk Anda.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(AppColor.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 24)
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
                    .font(AppTypography.buttonLabel)
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
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColor.textPrimary)

                    Text(role.description)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(AppColor.textSecondary)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
            .shadow(
                color: Color.black.opacity(0.03),
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
