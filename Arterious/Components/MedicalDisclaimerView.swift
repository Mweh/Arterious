import SwiftUI

/// Standard medical disclaimer component required across all health metric screens in Arterious.
struct MedicalDisclaimerView: View {

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: "info.circle")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColor.textSecondary.opacity(0.7))
                .padding(.top, 1)

            Text("Arterious reflects general wellness trends from Apple HealthKit and is not intended for medical diagnosis.")
                .font(AppTypography.captionRegular)
                .foregroundStyle(AppColor.textSecondary.opacity(0.8))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    MedicalDisclaimerView()
        .background(AppColor.backgroundPrimary)
}
