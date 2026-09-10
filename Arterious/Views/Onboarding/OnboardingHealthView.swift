import SwiftUI
import UserNotifications

/// Third step of onboarding: Requesting HealthKit and Notifications permissions with realistic mockup illustration.
struct OnboardingHealthView: View {

    let onComplete: () -> Void

    @State private var isConnecting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // MARK: - Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Hubungkan ke Health")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)

                Text("Arterious membutuhkan izin akses data kesehatan agar dapat berfungsi dengan optimal. Tenang saja, data kesehatanmu hanya disimpan secara lokal di perangkat dan tidak akan pernah diunggah.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(AppColor.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 24)
            .padding(.bottom, 16)

            // MARK: - Health Access Graphic Mockup
            healthAccessMockup

            Spacer()

            // Error Banner if needed
            if let errorMessage {
                Text(errorMessage)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.caution)
                    .padding(.bottom, AppSpacing.xs)
            }

            // MARK: - Hubungkan Button
            Button(action: requestPermissionsAndProceed) {
                HStack(spacing: AppSpacing.xs) {
                    if isConnecting {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    }
                    Text("Hubungkan")
                        .font(AppTypography.buttonLabel)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(AppColor.Brand.primaryBlue)
                .clipShape(Capsule())
            }
            .disabled(isConnecting)
            .padding(.bottom, 8)

            // MARK: - Medical Disclaimer Footnote
            VStack(spacing: 2) {
                Text("Data kamu tidak pernah meninggalkan perangkat ini.")
                Text("Arterious bukan pengganti saran medis profesional. Selalu konsultasikan dengan dokter.")
            }
            .font(.system(size: 11, weight: .regular))
            .foregroundStyle(AppColor.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.bottom, AppSpacing.md)
        }
        .padding(.horizontal, AppSpacing.lg + 4)
        .background(AppColor.backgroundPrimary.ignoresSafeArea())
    }

    // MARK: - Health Access Mockup

    private var healthAccessMockup: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                // Apple Health App Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .frame(width: 48, height: 48)
                        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)

                    Image(systemName: "heart.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "FF2D55"), Color(hex: "FF3B30")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .padding(.top, 14)

                Text("Health")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColor.textPrimary)

                // "Turn On All" pill
                Text("Turn On All")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColor.Brand.primaryBlue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity)
                    .background(Color(hex: "EFEFF4"))
                    .clipShape(Capsule())
                    .padding(.horizontal, 14)
                    .padding(.top, 2)

                // Permissions List Preview
                VStack(spacing: 0) {
                    permissionRow(title: "Heart Rate")
                    Divider().padding(.leading, 8)
                    permissionRow(title: "HRV")
                    Divider().padding(.leading, 8)
                    permissionRow(title: "Sleep")
                    Divider().padding(.leading, 8)
                    permissionRow(title: "Activity")
                }
                .padding(.horizontal, 10)
                .padding(.top, 4)
                .padding(.bottom, 8)
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
                .stroke(Color(.systemGray4).opacity(0.7), lineWidth: 1.5)
            )
        }
        .frame(maxWidth: 290)
        .frame(maxWidth: .infinity)
    }

    private func permissionRow(title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color(.systemGray))

            Spacer()

            HStack(spacing: 4) {
                Text("Detail")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color(.systemGray2))

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(.systemGray3))
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 4)
    }

    // MARK: - Permissions Flow

    private func requestPermissionsAndProceed() {
        isConnecting = true
        errorMessage = nil

        Task {
            // 1. Request Apple HealthKit access
            do {
                try await HealthKitManager.shared.requestAuthorization()
            } catch {
                // Simulator fallback
            }

            // 2. Request Notification permissions
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
