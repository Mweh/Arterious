import SwiftUI

/// Displays a single HealthKit metric value with an optional baseline comparison badge.
struct MetricCardView: View {

    let metric: MetricType
    let value: Double?
    let baselineValue: Double?

    private var formattedValue: String {
        guard let value else { return "Belum ada data" }
        switch metric {
        case .heartRate, .restingHeartRate, .meanHeartRate24h, .heartRateSD24h, .maxHeartRate24h, .hrvSDNN14DayMean, .hrvRMSSD:
            return String(format: "%.1f", value)
        case .hrvDropFromBaseline:
            let prefix = value > 0 ? "+" : ""
            return "\(prefix)\(String(format: "%.1f", value))"
        case .steps:
            return NumberFormatter.localizedString(from: NSNumber(value: Int(value)), number: .decimal)
        case .sleep, .sleepEfficiency, .deepSleepPercentage, .remSleepPercentage, .sleepConsistency, .activeMinutes, .exerciseMinutesWeek, .activeEnergy, .standHours:
            return String(format: "%.1f", value)
        }
    }

    private var differenceText: String? {
        guard let value, let baselineValue, baselineValue > 0 else { return nil }
        let diffPercent = ((value - baselineValue) / baselineValue) * 100.0
        let sign = diffPercent >= 0 ? "+" : ""
        return "\(sign)\(Int(round(diffPercent)))% vs 14d avg"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label(metric.rawValue, systemImage: metric.iconName)
                .font(AppTypography.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(AppColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                Text(formattedValue)
                    .font(value == nil ? AppTypography.subheadline : AppTypography.metricValue)
                    .foregroundStyle(value == nil ? AppColor.textSecondary : AppColor.textPrimary)

                if value != nil {
                    Text(metric.unitString)
                        .font(AppTypography.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(AppColor.textSecondary)
                }
            }

            if let differenceText {
                Text(differenceText)
                    .font(AppTypography.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(AppColor.textSecondary)
                    .padding(.horizontal, AppSpacing.sm - 2)
                    .padding(.vertical, AppSpacing.xs / 2)
                    .background(AppColor.fillSecondary)
                    .clipShape(Capsule())
            }
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
    }
}

#Preview {
    VStack(spacing: AppSpacing.md) {
        MetricCardView(metric: .steps, value: 3450, baselineValue: 4800)
        MetricCardView(metric: .restingHeartRate, value: nil, baselineValue: 64)
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}
