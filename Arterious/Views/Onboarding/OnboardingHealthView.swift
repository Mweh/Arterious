import SwiftUI
import UserNotifications

/// Shape representing the top-rounded phone / sheet mockup from the Sketch design.
/// It draws the left border, rounded top corners, top border, and right border, running straight down to the bottom without a bottom border.
struct TopRoundedPhoneFrame: Shape {
    var cornerRadius: CGFloat = 28

    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Start at bottom-left
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        // Straight up left side
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
        // Top-left rounded corner
        path.addArc(
            center: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        // Across top
        path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
        // Top-right rounded corner
        path.addArc(
            center: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY + cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(270),
            endAngle: .degrees(0),
            clockwise: false
        )
        // Straight down right side
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}

/// Third step of onboarding: Requesting HealthKit and Notifications permissions with realistic mockup illustration.
struct OnboardingHealthView: View {

    let onComplete: () -> Void

    @State private var isConnecting = false
    @State private var errorMessage: String?

    // Color tokens matching the Sketch
    private let subtitleColor = Color(hex: "8E8E93")
    private let frameBorderColor = Color(hex: "6C6C70")

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // MARK: - Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Hubungkan ke Health")
                    .font(.system(size: 24, weight: .bold)) // SF Pro 24 Bold
                    .foregroundStyle(Color.black)

                Text("Arterious membutuhkan izin akses\ndata kesehatan agar dapat\nberfungsi dengan optimal. Tenang\nsaja, data kesehatanmu hanya\ndisimpan secara lokal di perangkat\ndan tidak akan pernah diunggah.")
                    .font(AppTypography.bodyRegular) // SF Pro 17 Regular
                    .foregroundStyle(subtitleColor)
                    .lineSpacing(3) // Line height 22
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            .padding(.top, 16)
            .padding(.bottom, 12)

            // MARK: - Health Access Graphic Mockup (extends down to the button)
            healthAccessMockup
                .padding(.bottom, 12)

            // Error Banner if needed
            if let errorMessage {
                Text(errorMessage)
                    .font(AppTypography.captionRegular)
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
                        .font(AppTypography.bodySemibold) // SF Pro 17 Semibold
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(AppColor.Brand.primaryBlue)
                .clipShape(Capsule())
            }
            .disabled(isConnecting)
            .padding(.bottom, 10)

            // MARK: - Medical Disclaimer Footnote
            VStack(spacing: 2) {
                Text("Data kamu tidak pernah meninggalkan perangkat ini.")
                Text("Arterious bukan pengganti saran medis profesional. Selalu")
                Text("konsultasikan dengan dokter.")
            }
            .font(.system(size: 11.5, weight: .regular)) // SF Pro 11.5 Regular
            .foregroundStyle(Color.black)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.bottom, AppSpacing.sm)
        }
        .padding(.horizontal, 24)
        .background(Color.white.ignoresSafeArea())
    }

    // MARK: - Health Access Mockup

    private var healthAccessMockup: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
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
                .padding(.top, 16)

                Text("Health")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.black)

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
                    .padding(.top, 6)

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
                .padding(.horizontal, 12)
                .padding(.top, 6)

                // White flexible body extending down towards the button
                Spacer(minLength: 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 28,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 28
                )
            )
            .overlay(
                TopRoundedPhoneFrame(cornerRadius: 28)
                    .stroke(frameBorderColor, lineWidth: 2.2)
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func permissionRow(title: String) -> some View {
        HStack {
            Text(title)
                .font(AppTypography.footnoteRegular) // SF Pro 13 Regular
                .foregroundStyle(subtitleColor)

            Spacer()

            HStack(spacing: 4) {
                Text("Detail")
                    .font(AppTypography.footnoteRegular) // SF Pro 13 Regular
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
