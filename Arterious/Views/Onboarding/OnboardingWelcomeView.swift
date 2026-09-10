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
        GeometryReader { geo in
            ZStack(alignment: .bottom) {

                // MARK: - Background
                Color(hex: "F2F2F7")
                    .ignoresSafeArea()

                // MARK: - Hero Image (top ~58% of screen)
                VStack(spacing: 0) {
                    ZStack(alignment: .bottom) {
                        Image("Frame")
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height * 0.58)
                            .clipped()
                            .ignoresSafeArea(edges: .top)

                        // Gradient fade bottom of image → white
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .white.opacity(0.6), location: 0.65),
                                .init(color: .white, location: 1.0)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: geo.size.height * 0.28)
                    }
                    .frame(height: geo.size.height * 0.58)

                    Spacer()
                }

                // MARK: - Bottom Content Panel
                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 0) {
                        // Feature list
                        VStack(spacing: 0) {
                            ForEach(Array(features.enumerated()), id: \.element.id) { index, feature in
                                featureRow(feature)

                                if index < features.count - 1 {
                                    Divider()
                                        .padding(.leading, 52)
                                }
                            }
                        }

                        Spacer()
                            .frame(height: AppSpacing.xl)

                        // Continue Button
                        Button(action: onContinue) {
                            Text("Lanjut")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(AppColor.Brand.primaryBlue)
                                .clipShape(Capsule())
                        }
                        .padding(.bottom, geo.safeAreaInsets.bottom > 0 ? geo.safeAreaInsets.bottom : AppSpacing.xl)
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.xl)
                    .background(.white)
                }
                .frame(height: geo.size.height * 0.44)
            }
        }
        .ignoresSafeArea(edges: .bottom)
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
                    .font(.system(size: 13, weight: .regular))
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
