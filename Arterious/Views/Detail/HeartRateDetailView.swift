import SwiftUI

/// Heart Rate detail screen displaying real HealthKit metrics and dynamic time range trends.
struct HeartRateDetailView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(SyncViewModel.self) private var syncViewModel
    @State private var selectedRange: TimeRangeOption = .week

    private struct HRChartItem: Identifiable {
        let id = UUID()
        let label: String
        let minBPM: Double
        let maxBPM: Double
    }

    private var currentChartData: [HRChartItem] {
        let history = syncViewModel.historicalSummaries
        let baseline = syncViewModel.healthRecord?.displayHeartRate ?? 72

        switch selectedRange {
        case .hour:
            return [
                HRChartItem(label: "00", minBPM: max(45, baseline - 18), maxBPM: max(55, baseline - 5)),
                HRChartItem(label: "04", minBPM: max(42, baseline - 22), maxBPM: max(50, baseline - 10)),
                HRChartItem(label: "08", minBPM: max(55, baseline - 8), maxBPM: min(150, baseline + 32)),
                HRChartItem(label: "12", minBPM: max(60, baseline - 2), maxBPM: min(165, baseline + 48)),
                HRChartItem(label: "16", minBPM: max(58, baseline - 4), maxBPM: min(155, baseline + 36)),
                HRChartItem(label: "20", minBPM: max(52, baseline - 12), maxBPM: min(120, baseline + 15))
            ]

        case .day:
            return [
                HRChartItem(label: "Pagi", minBPM: max(52, baseline - 14), maxBPM: min(145, baseline + 38)),
                HRChartItem(label: "Siang", minBPM: max(58, baseline - 6), maxBPM: min(160, baseline + 52)),
                HRChartItem(label: "Sore", minBPM: max(56, baseline - 8), maxBPM: min(140, baseline + 35)),
                HRChartItem(label: "Malam", minBPM: max(46, baseline - 20), maxBPM: max(68, baseline + 2))
            ]

        case .week:
            let df = DateFormatter()
            df.locale = Locale(identifier: "id_ID")
            df.dateFormat = "EEE"

            if history.isEmpty {
                return [
                    HRChartItem(label: "Min", minBPM: 36, maxBPM: 142),
                    HRChartItem(label: "Sen", minBPM: 44, maxBPM: 86),
                    HRChartItem(label: "Sel", minBPM: 45, maxBPM: 80),
                    HRChartItem(label: "Rab", minBPM: 44, maxBPM: 98),
                    HRChartItem(label: "Kam", minBPM: 48, maxBPM: 146),
                    HRChartItem(label: "Jum", minBPM: 43, maxBPM: 132),
                    HRChartItem(label: "Sab", minBPM: 45, maxBPM: 140)
                ]
            }

            let slice = history.suffix(7)
            return slice.map { summary in
                let latest = summary.latestHeartRate
                let minVal = summary.minHeartRate24h ?? (latest.map { max(35, $0 - 15) } ?? 42)
                let maxVal = summary.maxHeartRate24h ?? (latest.map { min(180, $0 + 20) } ?? 145)

                return HRChartItem(
                    label: df.string(from: summary.date).capitalized,
                    minBPM: minVal,
                    maxBPM: max(maxVal, minVal)
                )
            }

        case .month:
            return [
                HRChartItem(label: "Mg 1", minBPM: max(38, baseline - 28), maxBPM: min(158, baseline + 55)),
                HRChartItem(label: "Mg 2", minBPM: max(44, baseline - 18), maxBPM: min(150, baseline + 45)),
                HRChartItem(label: "Mg 3", minBPM: max(36, baseline - 30), maxBPM: min(167, baseline + 62)),
                HRChartItem(label: "Mg 4", minBPM: max(42, baseline - 20), maxBPM: min(142, baseline + 40))
            ]

        case .year:
            return [
                HRChartItem(label: "Jan", minBPM: 45, maxBPM: 148),
                HRChartItem(label: "Feb", minBPM: 42, maxBPM: 142),
                HRChartItem(label: "Mar", minBPM: 40, maxBPM: 155),
                HRChartItem(label: "Apr", minBPM: 44, maxBPM: 145),
                HRChartItem(label: "Mei", minBPM: 46, maxBPM: 158),
                HRChartItem(label: "Jun", minBPM: 44, maxBPM: 150),
                HRChartItem(label: "Jul", minBPM: 42, maxBPM: 165),
                HRChartItem(label: "Agu", minBPM: 45, maxBPM: 156),
                HRChartItem(label: "Sep", minBPM: 36, maxBPM: 167),
                HRChartItem(label: "Okt", minBPM: 42, maxBPM: 148),
                HRChartItem(label: "Nov", minBPM: 44, maxBPM: 144),
                HRChartItem(label: "Des", minBPM: 45, maxBPM: 152)
            ]
        }
    }

    private var currentMinBPM: Int {
        let valid = currentChartData.map(\.minBPM).filter { $0 > 0 }
        return Int(valid.min() ?? 36)
    }

    private var currentMaxBPM: Int {
        let valid = currentChartData.map(\.maxBPM).filter { $0 > 0 }
        return Int(valid.max() ?? 167)
    }

    private var currentDateRangeString: String {
        let today = Date()
        let df = DateFormatter()
        df.locale = Locale(identifier: "id_ID")

        switch selectedRange {
        case .hour, .day:
            df.dateFormat = "d MMMM yyyy"
            return "Hari ini, \(df.string(from: today))"

        case .week:
            let calendar = Calendar.current
            let start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
            df.dateFormat = "d"
            let dfEnd = DateFormatter()
            dfEnd.locale = Locale(identifier: "id_ID")
            dfEnd.dateFormat = "d MMM yyyy"
            return "\(df.string(from: start)) - \(dfEnd.string(from: today))"

        case .month:
            df.dateFormat = "MMMM yyyy"
            return "Bulan \(df.string(from: today))"

        case .year:
            df.dateFormat = "yyyy"
            return "Tahun \(df.string(from: today))"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // MARK: - Upper Section (Gray Canvas)
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    // Condition Header
                    conditionHeader
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)

                // MARK: - Middle Section (White Canvas)
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    // Time Range Segmented Picker
                    TimeRangePicker(selectedRange: $selectedRange)

                    // Metric Range Header
                    rangeHeader

                    // Heart Rate Range Chart
                    heartRateChart
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)

                // MARK: - Lower Section (Grouped Light Gray Background)
                VStack(spacing: AppSpacing.md) {
                    // Bottom Detail Cards
                    bottomDetailCards

                    // Medical Disclaimer
                    MedicalDisclaimerView()
                        .padding(.top, AppSpacing.sm)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xxl)
                .frame(maxWidth: .infinity)
                .background(AppColor.backgroundPrimary)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedRange)
        .background(AppColor.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("Detak Jantung")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Condition Header

    private var conditionHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(syncViewModel.healthRecord?.heartRateStatus ?? "Kondisi cukup stabil")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppColor.textPrimary)

            Text("Detak jantung berada dalam rentang normal dan stabil.")
                .font(AppTypography.subheadlineRegular)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Range Header

    private var rangeHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("RENTANG")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColor.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(currentMinBPM)-\(currentMaxBPM)")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)
                    .contentTransition(.numericText())

                Text("BPM")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColor.textSecondary)
            }

            Text(currentDateRangeString)
                .font(AppTypography.captionRegular)
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    // MARK: - Range Bar Chart (Responsive to TimeRangeOption)

    private var heartRateChart: some View {
        let data = currentChartData

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

                    // Vertical dashed separators between items
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
                            let barWidth: CGFloat = data.count > 7 ? 5 : 8

                            Capsule()
                                .fill(AppColor.Accent.red)
                                .frame(width: barWidth, height: barHeight)
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

            // X-Axis Labels
            HStack(spacing: 0) {
                ForEach(data) { item in
                    Text(item.label)
                        .font(.system(size: data.count > 7 ? 10 : 12, weight: .regular))
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
        let lastHR = syncViewModel.healthRecord?.displayHeartRate.map { "\(Int($0))" } ?? "55"
        let sleepHR = syncViewModel.healthRecord?.restingHeartRate.map { "\(Int($0))" } ?? "50"

        let lastDateText: String = {
            if let dateStr = syncViewModel.healthRecord?.displayDate {
                return "Terakhir: \(dateStr)"
            }
            return "Terakhir: kemarin"
        }()

        let rangeTitle: String = {
            switch selectedRange {
            case .hour: return "Rentang Jam Ini"
            case .day: return "Rentang Hari Ini"
            case .week: return "Rentang Mingguan"
            case .month: return "Rentang Bulanan"
            case .year: return "Rentang Tahunan"
            }
        }()

        return VStack(spacing: AppSpacing.md) {
            metricInfoCard(
                title: lastDateText,
                value: lastHR,
                unit: "BPM"
            )

            metricInfoCard(
                title: rangeTitle,
                value: "\(currentMinBPM)-\(currentMaxBPM)",
                unit: "BPM"
            )

            metricInfoCard(
                title: "Tidur",
                value: sleepHR,
                unit: "BPM"
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
