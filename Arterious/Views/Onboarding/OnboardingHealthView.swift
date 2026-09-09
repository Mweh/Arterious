import SwiftUI
import UserNotifications

/// Third step of onboarding: Requesting HealthKit and Notifications permissions with realistic mockup illustration.
struct OnboardingHealthView: View {

    let onComplete: () -> Void

    @State private var isConnecting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
                .frame(height: AppSpacing.xxl)

            // Header
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Hubungkan ke Health")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)

                Text("Arterious membutuhkan izin akses data kesehatan agar dapat berfungsi dengan optimal. Tenang saja, data kesehatanmu hanya disimpan secara lokal di perangkat dan tidak akan pernah diunggah.")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, AppSpacing.xs)
            }
            .padding(.bottom, AppSpacing.lg)

            // Health Access Graphic Mockup
            healthAccessMockup
                .padding(.bottom, AppSpacing.md)

            Spacer()

            // Error Banner if needed
            if let errorMessage {
                Text(errorMessage)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.caution)
                    .padding(.bottom, AppSpacing.xs)
            }

            // Connect Button
            AppButton(
                title: "Hubungkan",
                isLoading: isConnecting,
                isFullWidth: true,
                action: requestPermissionsAndProceed
            )
            .padding(.bottom, AppSpacing.xs)

            // Medical Disclaimer Footnote
            VStack(spacing: 2) {
                Text("Data kamu tidak pernah meninggalkan perangkat ini.")
                Text("Arterious bukan pengganti saran medis profesional. Selalu konsultasikan dengan dokter.")
            }
            .font(.system(size: 11))
            .foregroundStyle(AppColor.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.bottom, AppSpacing.sm)
        }
        .padding(.horizontal, AppSpacing.lg)
        .background(AppColor.backgroundPrimary.ignoresSafeArea())
    }

    // MARK: - Health Access Mockup

    private var healthAccessMockup: some View {
        VStack(spacing: 0) {
            VStack(spacing: AppSpacing.sm) {
                // Apple Health Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white)
                        .frame(width: 54, height: 54)
                        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)

                    Image(systemName: "heart.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.18, blue: 0.33), Color(red: 0.95, green: 0.1, blue: 0.2)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .padding(.top, AppSpacing.md)

                Text("Health")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColor.textPrimary)

                // "Turn On All" pill
                Text("Turn On All")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColor.actionBlue)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemFill))
                    .clipShape(Capsule())
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, 4)

                // Permissions List Preview
                VStack(spacing: 0) {
                    permissionRow(title: "Heart Rate")
                    Divider().padding(.leading, AppSpacing.sm)
                    permissionRow(title: "HRV")
                    Divider().padding(.leading, AppSpacing.sm)
                    permissionRow(title: "Sleep")
                    Divider().padding(.leading, AppSpacing.sm)
                    permissionRow(title: "Activity")
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, AppSpacing.sm)
            }
            .background(Color.white)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 24,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 24
                )
            )
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 24,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 24
                )
                .stroke(Color(.systemGray4).opacity(0.6), lineWidth: 1.5)
            )
        }
        .frame(maxWidth: 290)
        .frame(maxWidth: .infinity)
    }

    private func permissionRow(title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Color(.systemGray))

            Spacer()

            HStack(spacing: 4) {
                Text("Detail")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(.systemGray2))

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(.systemGray3))
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, AppSpacing.xs)
    }

    // MARK: - Permissions Flow

    private func requestPermissionsAndProceed() {
        isConnecting = true
        errorMessage = nil

        Task {
            // 1. Request Apple HealthKit access (triggers iOS Health Access modal)
            do {
                try await HealthKitManager.shared.requestAuthorization()
            } catch {
                // HealthKit may fail on simulators without data, proceed anyway gracefully
            }

            // 2. Request Notification permissions (triggers iOS Notification alert)
            do {
                _ = try await UNUserNotificationCenter.current().requestAuthorization(
                    options: [.alert, .badge, .sound]
                )
            } catch {
                // Notifications permission optional
            }

            await MainActor.run {
                isConnecting = false
                onComplete()
            }
        }
    }
}

#Preview {
    OnboardingHealthView { }
}
