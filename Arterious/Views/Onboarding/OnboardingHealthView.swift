import SwiftUI
import UserNotifications

/// Third step of onboarding: Requesting HealthKit and Notifications permissions.
/// Meticulously aligned to the Figma/Sketch inspector source of truth:
/// - Layout W: 280, H: 382
/// - Corners: Rounded 24
/// - Borders: Center 3 (#707076)
/// - Top offset: Exactly 80pt from the very top of the screen
/// - Horizontal padding: Exactly 16pt
/// - Stack spacing: Exactly 32pt
/// - Title: "Hubungkan ke Health" (SF Pro 22 Bold)
/// - Subtitle: 6-line SF Pro Regular in #8E8E93
/// - CTA: "Hubungkan" (52pt height, Capsule, Blue #0088FF)
/// - Disclaimer: 3-line SF Pro 11.5 Regular in Black
struct OnboardingHealthView: View {

    let onComplete: () -> Void

    @State private var isConnecting = false
    @State private var errorMessage: String?

    // MARK: - Layout Constants
    private enum Layout {
        static let screenTopOffset: CGFloat = 80
        static let horizontalPadding: CGFloat = 16
        static let headerSpacing: CGFloat = 8
        static let stackSpacing: CGFloat = 32

        // Health Preview Card (from Figma inspector: W: 280, H: 382)
        static let cardWidth: CGFloat = 280
        static let cardHeight: CGFloat = 382
        static let cardCornerRadius: CGFloat = 24
        static let cardBorderWidth: CGFloat = 3

        // Button & Footer
        static let buttonHeight: CGFloat = 52
        static let buttonSpacing: CGFloat = 12
        static let footerBottomPadding: CGFloat = 16
    }

    // MARK: - Colors
    private let subtitleColor = Color(hex: "8E8E93")
    private let frameBorderColor = Color(hex: "707076")
    private let pillBackgroundColor = Color(hex: "E5E5EA")

    var body: some View {
        VStack(spacing: 0) {

            // MARK: - Header (Top: 80pt from screen top, Left/Right: 16pt)
            VStack(alignment: .leading, spacing: Layout.headerSpacing) {
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
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.top, Layout.screenTopOffset)

            // Gap 32pt between Header and Mockup (from Figma Stack ↕ 32)
            Spacer()
                .frame(height: Layout.stackSpacing)

            // MARK: - Health Access Graphic Mockup (Exact Figma: W: 280, H: 382, Corners: 24, Border: 3)
            healthAccessMockup

            Spacer()

            // Error Banner if needed
            if let errorMessage {
                Text(errorMessage)
                    .font(AppTypography.captionRegular)
                    .foregroundStyle(AppColor.caution)
                    .padding(.bottom, 4)
            }

            // MARK: - Bottom Area (Button + Disclaimer)
            VStack(spacing: Layout.buttonSpacing) {
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
                    .frame(height: Layout.buttonHeight)
                    .background(AppColor.Brand.primaryBlue)
                    .clipShape(Capsule())
                }
                .disabled(isConnecting)

                // Medical Disclaimer Footnote (3 lines, SF Pro 11.5 Regular, Black)
                VStack(spacing: 2) {
                    Text("Data kamu tidak pernah meninggalkan perangkat ini.")
                    Text("Arterious bukan pengganti seorang medis profesional. Selalu")
                    Text("konsultasikan dengan dokter.")
                }
                .font(.system(size: 11.5, weight: .regular))
                .foregroundStyle(Color.black)
                .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.bottom, Layout.footerBottomPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .ignoresSafeArea(edges: .top) // Allows screenTopOffset (80pt) to measure directly from screen top
    }

    // MARK: - Health Access Mockup (W: 280, H: 382, Corners: 24, Border: 3)

    private var healthAccessMockup: some View {
        VStack(spacing: 0) {
            // Apple Health App Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .frame(width: 48, height: 48)
                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)

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
            .padding(.top, 16)

            Text("Health")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.black)
                .padding(.top, 4)

            // "Turn On All" pill
            Text("Turn On All")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColor.Brand.primaryBlue)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(pillBackgroundColor)
                .clipShape(Capsule())
                .padding(.horizontal, 14)
                .padding(.top, 12)

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
            .padding(.horizontal, 14)
            .padding(.top, 8)

            Spacer(minLength: 0)
        }
        .frame(width: Layout.cardWidth, height: Layout.cardHeight) // EXACT Figma: W: 280, H: 382
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cardCornerRadius)) // EXACT Figma: Rounded 24
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                .stroke(frameBorderColor, lineWidth: Layout.cardBorderWidth) // EXACT Figma: Border 3
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
        .padding(.vertical, 7)
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
