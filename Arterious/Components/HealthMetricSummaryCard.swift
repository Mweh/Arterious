import SwiftUI

/// Card component displaying a health metric summary row (Heart Rate, Sleep, Activity)
/// matching Image 3 & 4 in the parent flow.
struct HealthMetricSummaryCard: View {

    let iconName: String
    let iconColor: Color
    let iconBgColor: Color
    let title: String
    let value: String
    var unit: String? = nil
    let subtitle: String
    var dateString: String = "9 Sep"
    var chartValues: [CGFloat] = [0.4, 0.7, 0.5, 0.9, 0.8, 0.6]

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.md) {
            // Circular Icon Badge
            ZStack {
                Circle()
                    .fill(iconBgColor)
                    .frame(width: 48, height: 48)

                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            // Metric Text Details
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.subheadlineRegular)
                    .foregroundStyle(AppColor.textPrimary)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(AppColor.textPrimary)

                    if let unit {
                        Text(unit)
                            .font(AppTypography.captionRegular)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }

                Text(subtitle)
                    .font(AppTypography.captionRegular)
                    .foregroundStyle(AppColor.textSecondary)
            }

            Spacer(minLength: 4)

            // Right Trailing: Chevron, Date, Mini Chart
            VStack(alignment: .trailing, spacing: 4) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(.systemGray3))

                Text(dateString)
                    .font(AppTypography.captionRegular)
                    .foregroundStyle(AppColor.textSecondary)

                MiniBarChartPreview(values: chartValues, color: iconColor)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
        .background(AppColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.r24))
        .shadow(color: Color.black.opacity(0.025), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    VStack(spacing: AppSpacing.md) {
        HealthMetricSummaryCard(
            iconName: "heart.fill",
            iconColor: AppColor.Accent.red,
            iconBgColor: AppColor.Accent.red12,
            title: "Detak Jantung",
            value: "72",
            unit: "BPM",
            subtitle: "Dalam rentang normal",
            chartValues: [0.5, 0.8, 0.4, 1.0, 0.7, 0.4]
        )

        HealthMetricSummaryCard(
            iconName: "bed.double.fill",
            iconColor: Color(red: 0.55, green: 0.45, blue: 0.9),
            iconBgColor: Color(red: 0.55, green: 0.45, blue: 0.9).opacity(0.12),
            title: "Tidur",
            value: "7j 40m",
            subtitle: "Kualitas tidur baik",
            chartValues: [0.3, 0.7, 0.4, 0.9, 0.8, 0.5]
        )

        HealthMetricSummaryCard(
            iconName: "figure.walk",
            iconColor: AppColor.Accent.green,
            iconBgColor: AppColor.Accent.green12,
            title: "Aktivitas",
            value: "4.280",
            subtitle: "Lebih baik dari biasanya",
            chartValues: [0.4, 0.6, 0.5, 0.9, 0.8, 0.3]
        )
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}
