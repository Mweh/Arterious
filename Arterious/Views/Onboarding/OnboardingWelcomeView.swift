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
            iconName: "bell.and.waves.left.and.right",
            title: "Dapatkan Notifikasi",
            subtitle: "Notifikasi saat ada perubahan penting"
        ),
        FeatureItem(
            iconName: "person.badge.plus",
            title: "Tetap terhubung",
            subtitle: "Tetap dekat dengan mereka setiap hari"
        )
    ]

    var body: some View {
        VStack(spacing: 0) {

            // MARK: - Hero Image dengan gradient fade halus
            ZStack(alignment: .bottom) {
                Image("OnboardingPage1Image")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)

                // Gradient fade ke warna background F2F2F7
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: AppColor.backgroundPrimary.opacity(0.65), location: 0.65),
                        .init(color: AppColor.backgroundPrimary, location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)
            }

            // MARK: - Features List
            VStack(spacing: 0) {
                ForEach(Array(features.enumerated()), id: \.element.id) { _, feature in
                    featureRow(feature)
                    Divider()
                        .background(AppColor.separator)
                        .padding(.leading, 48)
                }
            }
            .padding(.horizontal, AppSpacing.lg + 4)
            .padding(.top, AppSpacing.xs)

            Spacer()

            // MARK: - Lanjut Button
            Button(action: onContinue) {
                Text("Lanjut")
                    .font(AppTypography.bodySemibold) // SF Pro 17 Semibold
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AppColor.Brand.primaryBlue)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, AppSpacing.lg + 4)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppColor.backgroundPrimary.ignoresSafeArea())
    }

    // MARK: - Feature Row

    private func featureRow(_ item: FeatureItem) -> some View {
        HStack(alignment: .center, spacing: AppSpacing.md + 2) {
            Image(systemName: item.iconName)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(AppColor.textPrimary)
                .frame(width: 32, height: 32, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(AppTypography.calloutBold) // SF Pro 16 Bold
                    .foregroundStyle(AppColor.textPrimary)

                Text(item.subtitle)
                    .font(AppTypography.footnoteRegular) // SF Pro 13 Regular
                    .foregroundStyle(AppColor.textSecondary)
                    .lineSpacing(2) // Line height 18
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
    }
}

#Preview {
    OnboardingWelcomeView { }
}
