import SwiftUI

/// Heart Rate detail screen matching Screenshot 1 in the Child monitoring flow.
struct HeartRateDetailView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var selectedRange: TimeRangeOption = .week

    // Sample daily range data matching the screenshot
    private struct DayHRRange: Identifiable {
        let id = UUID()
        let day: String
        let minBPM: Double
        let maxBPM: Double
    }

    private let weekData: [DayHRRange] = [
        DayHRRange(day: "Min", minBPM: 36, maxBPM: 142),
        DayHRRange(day: "Sen", minBPM: 44, maxBPM: 86),
        DayHRRange(day: "Sel", minBPM: 45, maxBPM: 80),
        DayHRRange(day: "Rab", minBPM: 44, maxBPM: 98),
        DayHRRange(day: "Kam", minBPM: 48, maxBPM: 146),
        DayHRRange(day: "Jum", minBPM: 43, maxBPM: 132),
        DayHRRange(day: "Sab", minBPM: 45, maxBPM: 140)
    ]

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
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColor.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(AppColor.backgroundSecondary)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
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
            Text("Kondisi cukup stabil")
                .font(.system(size: 22, weight: .bold))
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
                Text("36-167")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)

                Text("BPM")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColor.textSecondary)
            }

            Text("1 - 7 Sep 2026")
                .font(AppTypography.captionRegular)
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    // MARK: - Weekly Range Bar Chart

    private var heartRateChart: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                let chartWidth = width - 40 // Leave 40pt for right axis labels
                let maxVal: CGFloat = 200.0
                let columnWidth = chartWidth / CGFloat(weekData.count)

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
                    ForEach(1..<weekData.count, id: \.self) { idx in
                        let x = CGFloat(idx) * columnWidth
                        Path { path in
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: height))
                        }
                        .stroke(Color.black.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }

                    // Vertical Range Bars
                    ForEach(Array(weekData.enumerated()), id: \.element.id) { idx, item in
                        let centerX = CGFloat(idx) * columnWidth + (columnWidth / 2)
                        let yTop = height - (CGFloat(item.maxBPM) / maxVal) * height
                        let yBottom = height - (CGFloat(item.minBPM) / maxVal) * height
                        let barHeight = max(yBottom - yTop, 6)

                        Capsule()
                            .fill(AppColor.Accent.red)
                            .frame(width: 8, height: barHeight)
                            .position(x: centerX, y: yTop + barHeight / 2)
                    }
                }
            }
            .frame(height: 200)

            // X-Axis Day Labels
            HStack(spacing: 0) {
                ForEach(weekData) { item in
                    Text(item.day)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AppColor.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.trailing, 40) // Align with chart area
            .padding(.top, 8)
        }
        .padding(.vertical, AppSpacing.sm)
    }

    // MARK: - Bottom Detail Cards

    private var bottomDetailCards: some View {
        VStack(spacing: AppSpacing.md) {
            metricInfoCard(
                title: "Terakhir: kemarin",
                value: "55",
                unit: "BPM"
            )

            metricInfoCard(
                title: "Rentang",
                value: "44-105",
                unit: "BPM"
            )

            metricInfoCard(
                title: "Tidur",
                value: "50",
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

                Text(unit)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColor.textSecondary)
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
    }
}
