import SwiftUI

struct HomeNotPairedCardView: View {
    @Bindable var syncViewModel: SyncViewModel
    @State private var isSharing = false

    var body: some View {
        VStack(spacing: 24) {
            // Interconnected Icons Ring Illustration
            ZStack {
                // Dashed ellipse orbit
                Ellipse()
                    .stroke(
                        Color.blue.opacity(0.35),
                        style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
                    )
                    .frame(width: 220, height: 110)

                // Top-left: Bed icon
                iconCircle(
                    icon: "bed.double.fill",
                    color: Color(hue: 0.72, saturation: 0.6, brightness: 0.8),
                    bgColor: Color(hue: 0.72, saturation: 0.2, brightness: 0.95),
                    size: 40
                )
                .offset(x: -80, y: -40)

                // Top-right: Family/People icon
                iconCircle(
                    icon: "person.2.fill",
                    color: Color(hue: 0.6, saturation: 0.6, brightness: 0.8),
                    bgColor: Color(hue: 0.6, saturation: 0.2, brightness: 0.95),
                    size: 40
                )
                .offset(x: 24, y: -45)

                // Bottom-right: Walking figure
                iconCircle(
                    icon: "figure.walk",
                    color: Color(hue: 0.4, saturation: 0.65, brightness: 0.75),
                    bgColor: Color(hue: 0.4, saturation: 0.2, brightness: 0.95),
                    size: 40
                )
                .offset(x: 75, y: -10)

                // Bottom-center: Glowing Heart icon
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.18))
                        .frame(width: 50, height: 50)
                        .blur(radius: 4)

                    iconCircle(
                        icon: "heart.fill",
                        color: .red,
                        bgColor: Color(hue: 0.0, saturation: 0.15, brightness: 0.98),
                        size: 40
                    )
                }
                .offset(x: -25, y: 15)
            }
            .frame(height: 140)
            .padding(.top, 12)

            // Text section
            VStack(spacing: 10) {
                Text("Tetap dekat, meski berjauhan")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.center)

                Text("Pantau perubahan pola kesehatan dan aktivitas orang tua dari jauh, agar kamu tahu kapan waktunya mengecek kabar mereka")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 16)
            }

            // Blue Action Button
            Button {
                Task {
                    isSharing = true
                    if let url = await syncViewModel.requestShareLink() {
                        ShareSheetHelper.share(url: url)
                    }
                    isSharing = false
                }
            } label: {
                HStack(spacing: 8) {
                    if isSharing || syncViewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    Text("Minta Kontak Membagikan Data")
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .shadow(color: Color.blue.opacity(0.28), radius: 8, y: 4)
            }
            .disabled(isSharing || syncViewModel.isLoading)
            .padding(.horizontal, 8)
        }
        .padding(24)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
    }

    private func iconCircle(icon: String, color: Color, bgColor: Color, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(bgColor)
                .frame(width: size, height: size)
            Image(systemName: icon)
                .font(.system(size: size * 0.45, weight: .medium))
                .foregroundStyle(color)
        }
    }
}

#Preview {
    HomeNotPairedCardView(syncViewModel: SyncViewModel())
        .padding()
        .background(Color(white: 0.95))
}
