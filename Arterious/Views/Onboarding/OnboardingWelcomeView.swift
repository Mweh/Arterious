import SwiftUI

/// First step of onboarding: Brand introduction with iPhone mockup and key feature overview.
struct OnboardingWelcomeView: View {

    let onContinue: () -> Void

    // Background warna abu-abu muda sesuai design (#F2F2F7)
    private let pageBackground = Color(hex: "F2F2F7")

    private struct FeatureItem: Identifiable {
        let id = UUID()
        let iconName: String
        let title: String
        let subtitle: String
    }

    private let features: [FeatureItem] = [
        FeatureItem(
            iconName: "doc.text",
            title: "Pantau Kesehatan",
            subtitle: "Lihat kondisi harian orang tua dengan mudah"
        ),
        FeatureItem(
            iconName: "bell",
            title: "Dapatkan Notifikasi",
            subtitle: "Notifikasi saat ada perubahan penting"
        ),
        FeatureItem(
            iconName: "person.crop.circle.badge.plus",
            title: "Tetap terhubung",
            subtitle: "Tetap dekat dengan mereka setiap hari"
        )
    ]

    var body: some View {
        VStack(spacing: 0) {

            // MARK: - Hero Image dengan gradient fade ke abu-abu
            ZStack(alignment: .bottom) {
                Image("OnboardingPage1Image")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)

                // Gradient fade ke warna yang sama dengan background halaman
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: pageBackground.opacity(0.6), location: 0.65),
                        .init(color: pageBackground, location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 130)
            }

            // MARK: - Features
            VStack(spacing: 0) {
                ForEach(Array(features.enumerated()), id: \.element.id) { index, feature in
                    featureRow(feature)
                    if index < features.count - 1 {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)

            Spacer()

            // MARK: - Lanjut Button
            Button(action: onContinue) {
                Text("Lanjut")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(AppColor.Brand.primaryBlue)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(pageBackground.ignoresSafeArea())
    }

    // MARK: - Feature Row

    private func featureRow(_ item: FeatureItem) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: item.iconName)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(AppColor.Gray.gray100)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColor.Gray.gray100)

                Text(item.subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(AppColor.Gray.gray50)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.vertical, AppSpacing.md)
    }
}

#Preview {
    OnboardingWelcomeView { }
}
