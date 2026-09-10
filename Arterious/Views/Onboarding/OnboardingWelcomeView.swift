import SwiftUI

/// First step of onboarding: Brand introduction with iPhone mockup and key feature overview.
struct OnboardingWelcomeView: View {

    let onContinue: () -> Void

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

            // MARK: - Hero Image
            ZStack(alignment: .bottom) {
                Image("Frame")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)

                // Gradient: transparent → white, so image melts into white content below
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .white.opacity(0.5), location: 0.6),
                        .init(color: .white, location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)
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
        .background(Color.white)
        .ignoresSafeArea(edges: .top)
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
