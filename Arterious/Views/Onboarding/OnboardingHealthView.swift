import SwiftUI
import UserNotifications

struct OnboardingHealthView: View {

    let onComplete: () -> Void

    @State private var isConnecting = false
    @State private var errorMessage: String?

    // MARK: - Colors
    private let subtitleColor = Color(hex: "8E8E93")
    private let frameBorderColor = Color(hex: "8A8A8E")
    private let pillBackgroundColor = Color(hex: "E4E4E6")
    private let rowContainerBg = Color(hex: "F8F8F8")
    private let rowTextColor = Color(hex: "BFBFBF")
    private let rowDetailColor = Color(hex: "C7C7CC")

    var body: some View {
        VStack(spacing: 0) {

            // MARK: - Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Hubungkan ke Health")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.black)

                Text("Arterious membutuhkan izin akses\ndata kesehatan agar dapat\nberfungsi dengan optimal. Tenang\nsaja, data kesehatanmu hanya\ndisimpan secara lokal di perangkat\ndan tidak akan pernah diunggah.")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(subtitleColor)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 75)

            Spacer(minLength: 24)

            // MARK: - Health Access Graphic Mockup
            healthAccessMockup

            Spacer(minLength: 24)

            // Error Banner if needed
            if let errorMessage {
                Text(errorMessage)
                    .font(AppTypography.captionRegular)
                    .foregroundStyle(AppColor.caution)
                    .padding(.bottom, 4)
            }

            // MARK: - Bottom Area (Button + Disclaimer)
            VStack(spacing: 12) {
                Button(action: requestPermissionsAndProceed) {
                    HStack(spacing: AppSpacing.xs) {
                        if isConnecting {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        }
                        Text("Hubungkan")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AppColor.Brand.primaryBlue)
                    .clipShape(Capsule())
                }
                .disabled(isConnecting)

                VStack(spacing: 2) {
                    Text("Data kamu tidak pernah meninggalkan perangkat ini.")
                    Text("Arterious bukan pengganti saran medis profesional. Selalu")
                    Text("konsultasikan dengan dokter.")
                }
                .font(.system(size: 12.5, weight: .regular))
                .foregroundStyle(Color.black)
                .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }

    // MARK: - Health Access Mockup

    private var healthAccessMockup: some View {
        VStack(spacing: 0) {
            // Apple Health App Icon
            Image("AppleHealthIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 52, height: 52)
                .shadow(color: Color.black.opacity(0.10), radius: 6, x: 0, y: 3)
                .padding(.top, 20)

            Text("Health")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.black)
                .padding(.top, 4)

            // "Turn On All" pill (Left-aligned text)
            HStack {
                Text("Turn On All")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(AppColor.Brand.primaryBlue)
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(pillBackgroundColor)
            .clipShape(Capsule())
            .padding(.horizontal, 14)
            .padding(.top, 14)

            // Permissions List Preview Card
            VStack(spacing: 0) {
                permissionRow(title: "Heart Rate")
                Divider().padding(.leading, 12)
                permissionRow(title: "HRV")
                Divider().padding(.leading, 12)
                permissionRow(title: "Sleep")
                Divider().padding(.leading, 12)
                permissionRow(title: "Activity")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                TopRoundedRectangle(cornerRadius: 14)
                    .fill(rowContainerBg)
            )
            .padding(.horizontal, 14)
            .padding(.top, 16)

            Spacer(minLength: 0)
        }
        .frame(width: 280, height: 315)
        .background(
            TopRoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
        )
        .overlay(
            OpenCardShape(cornerRadius: 24)
                .stroke(frameBorderColor, lineWidth: 3)
        )
    }

    private func permissionRow(title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(rowTextColor)

            Spacer()

            HStack(spacing: 4) {
                Text("Detail")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(rowDetailColor)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(rowDetailColor)
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

// MARK: - Shapes for Open-Bottom Card

private struct OpenCardShape: Shape {
    var cornerRadius: CGFloat = 24

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
        path.addArc(
            center: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
        path.addArc(
            center: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY + cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(270),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}

private struct TopRoundedRectangle: Shape {
    var cornerRadius: CGFloat = 24

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
        path.addArc(
            center: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
        path.addArc(
            center: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY + cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(270),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    OnboardingHealthView { }
}
