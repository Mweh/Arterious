import SwiftUI
import UserNotifications

/// Shape representing the top-rounded phone / sheet mockup from the Sketch design.
/// It draws the left border, rounded top corners, top border, and right border, running straight down without a bottom border.
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
/// Meticulously aligned to the Figma/Sketch inspector:
/// - Top: 80pt from screen top
/// - Horizontal padding: 16pt
/// - Stack spacing: 32pt
/// - Title Font: SF Pro 22 Bold
/// - Subtitle: 6-line SF Pro Regular in #8E8E93
/// - Mockup: centered phone frame extending directly down to the button
struct OnboardingHealthView: View {

    let onComplete: () -> Void

    @State private var isConnecting = false
    @State private var errorMessage: String?

    // Color tokens matching the Sketch
    private let subtitleColor = Color(hex: "8E8E93")
    private let frameBorderColor = Color(hex: "6C6C70")

    var body: some View {
        VStack(spacing: 0) {

            // MARK: - Main Stack (Top: 80pt, Horizontal: 16pt, Spacing: 32pt)
            VStack(alignment: .leading, spacing: 32) {

                // Header (Title SF Pro 22 Bold + Subtitle)
                VStack(alignment: .leading, spacing: 10) {
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

                // Health Access Graphic Mockup (centered, extending down to button)
                healthAccessMockup
            }
            .padding(.top, 20) // 59pt safe area + 20pt = ~80pt from screen top as per Sketch
            .padding(.horizontal, 16) // Exactly 16pt padding from Sketch inspector

            // Error Banner if needed
            if let errorMessage {
                Text(errorMessage)
                    .font(AppTypography.captionRegular)
                    .foregroundStyle(AppColor.caution)
                    .padding(.top, 4)
            }

            // MARK: - Bottom Area (Button + Disclaimer)
            VStack(spacing: 12) {
                // Hubungkan Button (Full width with 16pt horizontal padding)
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
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
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
                    .padding(.top, 4)

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
                .padding(.top, 6)

                // White flexible body extending down towards the button
                Spacer(minLength: 0)
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
                    .stroke(frameBorderColor, lineWidth: 2)
            )
        }
        .frame(maxWidth: 295)
        .frame(maxWidth: .infinity)
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
