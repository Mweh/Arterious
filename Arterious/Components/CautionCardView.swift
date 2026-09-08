import SwiftUI

/// A non-diagnostic wellness alert card that surfaces a gentle family check-in reminder.
struct CautionCardView: View {

    let insight: CautionInsight
    var onCheckInTapped: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "sparkles")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColor.caution)

                Text(insight.title)
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColor.textPrimary)

                Spacer()
            }

            Text(insight.message)
                .font(AppTypography.subheadline)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)

            AppButton(title: insight.suggestedAction, icon: "phone.fill") {
                onCheckInTapped?()
            }
        }
        .padding(AppSpacing.lg + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                .fill(AppColor.cautionBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                .stroke(AppColor.cautionBorder, lineWidth: 1)
        )
    }
}

#Preview {
    CautionCardView(
        insight: CautionInsight(
            title: "Time for a Warm Check-In",
            message: "Mom's resting heart rate is slightly elevated (+8 BPM) and her step count dropped over the last 3 days. A friendly call might brighten her day.",
            suggestedAction: "Call Mom",
            dateDetected: Date()
        )
    )
    .padding()
    .background(AppColor.backgroundPrimary)
}
