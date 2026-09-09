import SwiftUI

/// Heart Rate detail screen displaying real HealthKit metrics and weekly trends.
struct HeartRateDetailView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(SyncViewModel.self) private var syncViewModel
    @State private var selectedRange: TimeRangeOption = .week

    private struct DayHRRange: Identifiable {
        let id = UUID()
        let day: String
        let minBPM: Double
        let maxBPM: Double
    }

    private var weeklyData: [DayHRRange] {
        let history = syncViewModel.historicalSummaries
        let calendar = Calendar.current
        let df = DateFormatter()
        df.locale = Locale(identifier: "id_ID")
        df.dateFormat = "EEE"

        if history.isEmpty {
            let today = Date()
            return (0..<7).reversed().map { offset in
                let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
                return DayHRRange(day: df.string(from: date).capitalized, minBPM: 0, maxBPM: 0)
            }
        }

        let slice = history.suffix(7)
        return slice.map { summary in
            let latest = summary.latestHeartRate
            let minVal = summary.minHeartRate24h ?? (latest.map { max(35, $0 - 15) } ?? 0)
            let maxVal = summary.maxHeartRate24h ?? (latest.map { min(180, $0 + 20) } ?? 0)

            return DayHRRange(
                day: df.string(from: summary.date).capitalized,
                minBPM: minVal,
                maxBPM: max(maxVal, minVal)
            )
        }
    }

    private var weekMinBPM: Int? {
        let valid = weeklyData.map(\.minBPM).filter { $0 > 0 }
        guard let minVal = valid.min() else { return nil }
        return Int(minVal)
    }

    private var weekMaxBPM: Int? {
        let valid = weeklyData.map(\.maxBPM).filter { $0 > 0 }
        guard let maxVal = valid.max() else { return nil }
        return Int(maxVal)
    }

    private var dateRangeString: String {
        let calendar = Calendar.current
        let today = Date()
        let start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let df = DateFormatter()
        df.locale = Locale(identifier: "id_ID")
        df.dateFormat = "d"
        let dfEnd = DateFormatter()
        dfEnd.locale = Locale(identifier: "id_ID")
        dfEnd.dateFormat = "d MMM yyyy"
        return "\(df.string(from: start)) - \(dfEnd.string(from: today))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                // Condition Header
                conditionHeader

                // Time Range Segmented Picker
                TimeRangePicker(selectedRange: $selectedRange)

                // Metric Range Header
                rangeHeader

                // Heart Rate Range Chart
                heartRateChart

                // Bottom Detail Cards
                bottomDetailCards

                // Medical Disclaimer
                MedicalDisclaimerView()
                    .padding(.top, AppSpacing.sm)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColor.backgroundPrimary.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppColor.actionBlue)
                        .frame(width: 36, height: 36, alignment: .leading)
                        .contentShape(Rectangle())
                }
            }

            ToolbarItem(placement: .principal) {
                Text("Detak Jantung")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)
            }
        }
    }

    // MARK: - Condition Header

    private var conditionHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(syncViewModel.healthRecord?.heartRateStatus ?? "Dalam rentang normal")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppColor.textPrimary)

            Text("Detak jantung berada dalam rentang normal dan stabil tercatat dari Apple Health.")
                .font(AppTypography.subheadlineRegular)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Range Header

    private var rangeHeader: some View {
        let rangeText: String = {
            if let min = weekMinBPM, let max = weekMaxBPM, max > min {
                return "\(min)-\(max)"
            } else if let hr = syncViewModel.healthRecord?.displayHeartRate {
                return "\(Int(hr))"
            }
            return "-"
        }()

        return VStack(alignment: .leading, spacing: 2) {
            Text("RENTANG")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColor.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(rangeText)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)

                if rangeText != "-" {
                    Text("BPM")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColor.textSecondary)
                }
            }

            Text(dateRangeString)
                .font(AppTypography.captionRegular)
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    // MARK: - Weekly Range Bar Chart

    private var heartRateChart: some View {
        let data = weeklyData

        return VStack(spacing: 0) {
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                let chartWidth = width - 40
                let maxVal: CGFloat = 200.0
                let columnCount = max(CGFloat(data.count), 1)
                let columnWidth = chartWidth / columnCount

                ZStack(alignment: .topLeading) {
                    // Outer Grid Frame
                    Rectangle()
                        .stroke(Color.black.opacity(0.18), lineWidth: 1)
                        .frame(width: chartWidth, height: height)

                    // Horizontal Grid Lines at 0, 50, 100, 200
                    let yMarks: [(val: CGFloat, label: String)] = [
                        (200, "200"),
                        (100, "100"),
                        (50, "50"),
                        (0, "0")
                    ]

                    ForEach(yMarks, id: \.label) { mark in
                        let yPos = height - (mark.val / maxVal) * height

                        // Grid line
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: yPos))
                            path.addLine(to: CGPoint(x: chartWidth, y: yPos))
                        }
                        .stroke(Color.black.opacity(0.2), lineWidth: 1)

                        // Y-Axis label on right
                        Text(mark.label)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(AppColor.textSecondary)
                            .position(x: chartWidth + 18, y: max(yPos, 8))
                    }

                    // Vertical dashed separators between days
                    ForEach(1..<data.count, id: \.self) { idx in
                        let x = CGFloat(idx) * columnWidth
                        Path { path in
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: height))
                        }
                        .stroke(Color.black.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }

                    // Vertical Range Bars
                    ForEach(Array(data.enumerated()), id: \.element.id) { idx, item in
                        let centerX = CGFloat(idx) * columnWidth + (columnWidth / 2)

                        if item.maxBPM > 0 {
                            let yTop = height - (CGFloat(item.maxBPM) / maxVal) * height
                            let yBottom = height - (CGFloat(item.minBPM) / maxVal) * height
                            let barHeight = max(yBottom - yTop, 6)

                            Capsule()
                                .fill(AppColor.Accent.red)
                                .frame(width: 8, height: barHeight)
                                .position(x: centerX, y: yTop + barHeight / 2)
                        } else {
                            Circle()
                                .fill(AppColor.textSecondary.opacity(0.25))
                                .frame(width: 4, height: 4)
                                .position(x: centerX, y: height - 6)
                        }
                    }
                }
            }
            .frame(height: 200)

            // X-Axis Day Labels
            HStack(spacing: 0) {
                ForEach(data) { item in
                    Text(item.day)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AppColor.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.trailing, 40)
            .padding(.top, 8)
        }
        .padding(.vertical, AppSpacing.sm)
    }

    // MARK: - Bottom Detail Cards

    private var bottomDetailCards: some View {
        let lastHR = syncViewModel.healthRecord?.displayHeartRate.map { "\(Int($0))" } ?? "-"

        let rangeText: String = {
            if let min = weekMinBPM, let max = weekMaxBPM, max > min {
                return "\(min)-\(max)"
            }
            return lastHR
        }()

        return VStack(spacing: AppSpacing.md) {
            metricInfoCard(
                title: "Detak Jantung Terkini",
                value: lastHR,
                unit: lastHR != "-" ? "BPM" : ""
            )

            metricInfoCard(
                title: "Rentang Mingguan",
                value: rangeText,
                unit: rangeText != "-" ? "BPM" : ""
            )
        }
    }

    private func metricInfoCard(title: String, value: String, unit: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColor.textPrimary)

            Spacer()

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, 16)
        .background(AppColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.r24))
        .shadow(color: Color.black.opacity(0.025), radius: 6, x: 0, y: 2)
    }
}

#Preview {
    NavigationStack {
        HeartRateDetailView()
            .environment(SyncViewModel())
    }
}
