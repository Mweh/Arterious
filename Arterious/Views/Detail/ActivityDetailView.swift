import SwiftUI

/// Activity detail screen displaying real HealthKit step count and weekly trends.
struct ActivityDetailView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(SyncViewModel.self) private var syncViewModel
    @State private var selectedRange: TimeRangeOption = .week

    private let activityBarColor = Color(hex: "F26430")

    private struct DayActivityStep: Identifiable {
        let id = UUID()
        let day: String
        let steps: Double
    }

    private var weeklyStepData: [DayActivityStep] {
        let history = syncViewModel.historicalSummaries
        let calendar = Calendar.current
        let df = DateFormatter()
        df.locale = Locale(identifier: "id_ID")
        df.dateFormat = "EEE"

        if history.isEmpty {
            let today = Date()
            return (0..<7).reversed().map { offset in
                let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
                return DayActivityStep(day: df.string(from: date).capitalized, steps: 0)
            }
        }

        let slice = history.suffix(7)
        return slice.map { summary in
            DayActivityStep(
                day: df.string(from: summary.date).capitalized,
                steps: summary.stepCount ?? 0
            )
        }
    }

    private var averageSteps: Int {
        let valid = weeklyStepData.map(\.steps).filter { $0 > 0 }
        guard !valid.isEmpty else { return 0 }
        return Int(valid.reduce(0, +) / Double(valid.count))
    }

    private var mostActiveDay: (day: String, steps: Int)? {
        let valid = weeklyStepData.filter { $0.steps > 0 }
        guard let best = valid.max(by: { $0.steps < $1.steps }) else { return nil }
        return (best.day, Int(best.steps))
    }

    private var maxStepsInWeek: CGFloat {
        let validMax = weeklyStepData.map(\.steps).max() ?? 0
        return max(CGFloat(validMax * 1.25), 5000.0)
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

    private func formatNumber(_ num: Int) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.groupingSeparator = "."
        return nf.string(from: NSNumber(value: num)) ?? "\(num)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                // Condition Header
                conditionHeader

                // Time Range Segmented Picker
                TimeRangePicker(selectedRange: $selectedRange)

                // Average Steps Header
                averageHeader

                // Steps Bar Chart
                activityChart

                // Bottom Summary Cards
                bottomSummaryCards

                // Medical Disclaimer
                MedicalDisclaimerView()
                    .padding(.top, AppSpacing.sm)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColor.backgroundPrimary.ignoresSafeArea(edges: .bottom))
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
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
                Text("Aktivitas")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)
            }
        }
    }

    // MARK: - Condition Header

    private var conditionHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(syncViewModel.healthRecord?.activityStatus ?? "Cenderung santai hari ini")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppColor.textPrimary)

            Text("Aktivitas harian dan jumlah langkah tercatat secara akurat dari Apple Health.")
                .font(AppTypography.subheadlineRegular)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Average Header

    private var averageHeader: some View {
        let avg = averageSteps

        return VStack(alignment: .leading, spacing: 2) {
            Text("RERATA")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColor.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(avg > 0 ? formatNumber(avg) : "-")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)

                if avg > 0 {
                    Text("langkah")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppColor.textSecondary)
                }
            }

            Text(dateRangeString)
                .font(AppTypography.captionRegular)
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    // MARK: - Steps Bar Chart

    private var activityChart: some View {
        let data = weeklyStepData
        let chartMax = maxStepsInWeek

        return VStack(spacing: 0) {
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                let chartWidth = width - 42
                let columnCount = max(CGFloat(data.count), 1)
                let columnWidth = chartWidth / columnCount

                ZStack(alignment: .topLeading) {
                    // Outer Frame
                    Rectangle()
                        .stroke(Color.black.opacity(0.18), lineWidth: 1)
                        .frame(width: chartWidth, height: height)

                    // Horizontal Grid Lines
                    let yMarks: [CGFloat] = [1.0, 0.66, 0.33, 0.0]

                    ForEach(yMarks, id: \.self) { ratio in
                        let yPos = height - (ratio * height)
                        let val = Int(ratio * chartMax)

                        Path { path in
                            path.move(to: CGPoint(x: 0, y: yPos))
                            path.addLine(to: CGPoint(x: chartWidth, y: yPos))
                        }
                        .stroke(Color.black.opacity(0.18), lineWidth: 1)

                        Text(val > 0 ? "\(val)" : "0")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(AppColor.textSecondary)
                            .position(x: chartWidth + 22, y: max(yPos, 8))
                    }

                    // Vertical Dashed Lines between days
                    ForEach(1..<data.count, id: \.self) { idx in
                        let x = CGFloat(idx) * columnWidth
                        Path { path in
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: height))
                        }
                        .stroke(Color.black.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }

                    // Vertical Step Bars
                    ForEach(Array(data.enumerated()), id: \.element.id) { idx, item in
                        let centerX = CGFloat(idx) * columnWidth + (columnWidth / 2)
                        let barWidth: CGFloat = columnWidth * 0.72

                        if item.steps > 0 {
                            let barHeight = max((CGFloat(item.steps) / chartMax) * height, 4)

                            Rectangle()
                                .fill(activityBarColor)
                                .frame(width: barWidth, height: barHeight)
                                .position(x: centerX, y: height - barHeight / 2)
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
            .padding(.trailing, 42)
            .padding(.top, 8)
        }
        .padding(.vertical, AppSpacing.sm)
    }

    // MARK: - Bottom Summary Cards

    private var bottomSummaryCards: some View {
        let avg = averageSteps
        let todaySteps = syncViewModel.healthRecord?.stepFormatted ?? "-"
        let best = mostActiveDay

        return VStack(spacing: AppSpacing.md) {
            metricInfoCard(
                title: "Langkah Hari Ini",
                value: todaySteps,
                unit: todaySteps != "-" ? "langkah" : ""
            )

            metricInfoCard(
                title: "Rerata langkah harian",
                value: avg > 0 ? formatNumber(avg) : "-",
                unit: avg > 0 ? "langkah" : ""
            )

            if let best = best {
                metricInfoCard(
                    title: "Hari teraktif: \(best.day)",
                    value: formatNumber(best.steps),
                    unit: "langkah"
                )
            }
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
        ActivityDetailView()
            .environment(SyncViewModel())
    }
}
