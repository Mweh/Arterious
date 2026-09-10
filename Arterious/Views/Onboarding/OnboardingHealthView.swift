import SwiftUI
import UserNotifications

/// Third step of onboarding: Requesting HealthKit and Notifications permissions with realistic mockup illustration.
/// Meticulously aligned to the Figma/Sketch inspector:
/// - Top offset: Exactly 80pt from the very top of the screen
/// - Horizontal padding: Exactly 16pt
/// - Stack spacing: Exactly 32pt
/// - Title Font: SF Pro 22 Bold
/// - Subtitle: 6-line SF Pro Regular in #8E8E93
/// - Mockup: Width 326pt, CornerRadius 28pt, Border 2pt #7C7C80
/// - Button: Full width with 16pt padding, 52pt height, Capsule, Blue #0088FF
/// - Disclaimer: 3-line SF Pro 11.5 Regular in Black
struct OnboardingHealthView: View {

    let onComplete: () -> Void

    @State private var isConnecting = false
    @State private var errorMessage: String?

    // Color tokens matching the Sketch
    private let subtitleColor = Color(hex: "8E8E93")
    private let frameBorderColor = Color(hex: "7C7C80")

    var body: some View {
        VStack(spacing: 0) {

            // MARK: - Header (Top: 80pt from screen top, Left/Right: 16pt)
            VStack(alignment: .leading, spacing: 8) {
                Text("Hubungkan ke Health")
                    .font(.system(size: 22, weight: .bold)) // SF Pro 22 Bold
                    .foregroundStyle(Color.black)

                Text("Arterious membutuhkan izin akses\ndata kesehatan agar dapat\nberfungsi dengan optimal. Tenang\nsaja, data kesehatanmu hanya\ndisimpan secara lokal di perangkat\ndan tidak akan pernah diunggah.")
                    .font(.system(size: 15.5, weight: .regular)) // SF Pro Regular
                    .foregroundStyle(subtitleColor)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 80) // Exactly 80pt from top of screen as per Figma inspector

            // Gap 32pt to Mockup as per Figma Stack (↕ 32)
            Spacer()
                .frame(height: 32)

            // MARK: - Health Access Graphic Mockup
            healthAccessMockup
                .padding(.horizontal, 16)

            Spacer()

            // Error Banner if needed
            if let errorMessage {
                Text(errorMessage)
                    .font(AppTypography.captionRegular)
                    .foregroundStyle(AppColor.caution)
                    .padding(.bottom, 6)
            }

            // MARK: - Bottom Area (Button + Disclaimer)
            VStack(spacing: 12) {
                // Hubungkan Button (Full width with 16pt margin)
                Button(action: requestPermissionsAndProceed) {
                    HStack(spacing: AppSpacing.xs) {
                        if isConnecting {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        }
                        Text("Hubungkan")
                            .font(.system(size: 17, weight: .semibold)) // SF Pro 17 Semibold
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AppColor.Brand.primaryBlue)
                    .clipShape(Capsule())
                }
                .disabled(isConnecting)

                // Medical Disclaimer Footnote (3 lines, SF Pro 11.5 Regular, Black)
                VStack(spacing: 2) {
                    Text("Data kamu tidak pernah meninggalkan perangkat ini.")
                    Text("Arterious bukan pengganti saran medis profesional. Selalu")
                    Text("konsultasikan dengan dokter.")
                }
                .font(.system(size: 11.5, weight: .regular))
                .foregroundStyle(Color.black)
                .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .ignoresSafeArea(edges: .top) // Allows padding(.top, 80) to measure from screen top
    }

    // MARK: - Health Access Mockup

    private var healthAccessMockup: some View {
        VStack(spacing: 0) {
            // Apple Health App Icon
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white)
                    .frame(width: 52, height: 52)
                    .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 3)

                Image(systemName: "heart.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "FF2D55"), Color(hex: "FF3B30")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .padding(.top, 18)

            Text("Health")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.black)
                .padding(.top, 4)

            // "Turn On All" pill
            Text("Turn On All")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColor.Brand.primaryBlue)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(Color(hex: "E5E5EA"))
                .clipShape(Capsule())
                .padding(.horizontal, 16)
                .padding(.top, 14)

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
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: 326) // Proportional card width matching Sketch
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(frameBorderColor, lineWidth: 2)
        )
    }

    private func permissionRow(title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(subtitleColor)

            Spacer()

            HStack(spacing: 4) {
                Text("Detail")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color(hex: "C7C7CC"))

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(hex: "C7C7CC"))
            }
        }
        .padding(.vertical, 8)
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
