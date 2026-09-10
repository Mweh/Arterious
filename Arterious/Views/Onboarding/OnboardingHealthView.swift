import SwiftUI
import UserNotifications

/// Third step of onboarding: Requesting HealthKit and Notifications permissions with realistic mockup illustration.
/// Exact 1-to-1 match to the Figma / Sketch artboard:
/// - Screen Top to Title: Exactly 80pt
/// - Screen Horizontal Margin: Exactly 16pt
/// - Stack Spacing (Header to Mockup): Exactly 32pt
/// - Title Font: SF Pro 22 Bold
/// - Subtitle: 6-line SF Pro Regular in #8E8E93 with lineSpacing 3
/// - Mockup Card: Width 280pt, Height 609pt, CornerRadius 24pt, Border 3pt #707076 (from Figma inspector)
/// - Bottom Overlay: White container with 52pt Capsule blue button and 3-line disclaimer
struct OnboardingHealthView: View {

    let onComplete: () -> Void

    @State private var isConnecting = false
    @State private var errorMessage: String?

    // Color tokens matching the Sketch
    private let subtitleColor = Color(hex: "8E8E93")
    private let frameBorderColor = Color(hex: "707076")

    var body: some View {
        ZStack(alignment: .bottom) {

            // MARK: - Scrollable / Top Content Stack
            VStack(alignment: .center, spacing: 0) {

                // Header (Title + Subtitle)
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

                // Gap 32pt between Header and Mockup (from Figma Stack ↕ 32)
                Spacer()
                    .frame(height: 32)

                // Health Access Mockup Card (W: 280, H: 609, Corners: 24, Border: 3)
                healthAccessMockup

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            // MARK: - Bottom Area (Button + Disclaimer) sitting over bottom of mockup card
            VStack(spacing: 12) {
                // Error Banner if needed
                if let errorMessage {
                    Text(errorMessage)
                        .font(AppTypography.captionRegular)
                        .foregroundStyle(AppColor.caution)
                }

                // Hubungkan Button
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
            .padding(.top, 16)
            .padding(.bottom, 16)
            .background(Color.white) // Solid white covers the bottom of the 609pt card
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Health Access Mockup (W: 280, H: 609, Corners: 24, Border: 3)

    private var healthAccessMockup: some View {
        VStack(spacing: 0) {
            // Apple Health App Icon
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white)
                    .frame(width: 52, height: 52)
                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)

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
            .padding(.top, 22)

            Text("Health")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.black)
                .padding(.top, 4)

            // "Turn On All" pill
            Text("Turn On All")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColor.Brand.primaryBlue)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(Color(hex: "E5E5EA"))
                .clipShape(Capsule())
                .padding(.horizontal, 16)
                .padding(.top, 14)

            // Permissions List Preview
            VStack(spacing: 0) {
                permissionRow(title: "Heart Rate")
                Divider().padding(.leading, 6)
                permissionRow(title: "HRV")
                Divider().padding(.leading, 6)
                permissionRow(title: "Sleep")
                Divider().padding(.leading, 6)
                permissionRow(title: "Activity")
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            Spacer()
        }
        .frame(width: 280, height: 609) // EXACT Figma Layout: W: 280, H: 609
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24)) // EXACT Figma Corners: 24
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(frameBorderColor, lineWidth: 3) // EXACT Figma Border: 3
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
        .padding(.horizontal, 2)
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
