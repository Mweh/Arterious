import SwiftUI

/// First step of onboarding: Brand introduction and key feature overview.
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
            iconName: "heart.text.square",
            title: "Daily Health Summary",
            subtitle: "Monitor heart rate, daily steps, and sleep patterns with ease."
        ),
        FeatureItem(
            iconName: "bell.and.waves.left.and.right",
            title: "Early Awareness",
            subtitle: "Receive gentle notifications when meaningful wellness pattern changes occur."
        ),
        FeatureItem(
            iconName: "person.crop.circle.badge.plus",
            title: "Connected Family",
            subtitle: "Stay informed about your parents' wellness trends securely and privately."
        )
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
                .frame(height: AppSpacing.xxl)

            // Brand Header
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                ArteriousLogoView(size: 64)

                Text("Arterious")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)
            }
            .padding(.bottom, AppSpacing.xl * 1.2)

            // Features List
            VStack(spacing: AppSpacing.lg) {
                ForEach(features) { feature in
                    featureRow(feature)
                }
            }

            Spacer()

            // Continue Button
            AppButton(
                title: "Continue",
                isFullWidth: true,
                action: onContinue
            )
            .padding(.bottom, AppSpacing.lg)
        }
        .padding(.horizontal, AppSpacing.lg)
        .background(AppColor.backgroundSecondary.ignoresSafeArea())
    }

    // MARK: - Feature Row

    private func featureRow(_ item: FeatureItem) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                Image(systemName: item.iconName)
                    .font(.system(size: 26))
                    .foregroundStyle(AppColor.textPrimary)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColor.textPrimary)

                    Text(item.subtitle)
                        .font(AppTypography.subheadline)
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()
                .padding(.leading, 48)
        }
    }
}

#Preview {
    OnboardingWelcomeView { }
}
