import SwiftUI

/// Activity detail screen matching Screenshot 3 in the Child monitoring flow.
struct ActivityDetailView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var selectedRange: TimeRangeOption = .week

    private let activityBarColor = Color(hex: "F26430")

    private struct DayActivityStep: Identifiable {
        let id = UUID()
        let day: String
        let steps: Double
    }

    private let weekStepData: [DayActivityStep] = [
        DayActivityStep(day: "Min", steps: 7600),
        DayActivityStep(day: "Sen", steps: 4600),
        DayActivityStep(day: "Sel", steps: 3900),
        DayActivityStep(day: "Rab", steps: 850),
        DayActivityStep(day: "Kam", steps: 7800),
        DayActivityStep(day: "Jum", steps: 8900),
        DayActivityStep(day: "Sab", steps: 5200)
    ]

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
                Text("Aktivitas")
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

            Text("Aktivitas harian berada pada tingkat yang baik dan konsisten.")
                .font(AppTypography.subheadlineRegular)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Average Header

    private var averageHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("RERATA")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColor.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("1500")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)

                Text("langkah")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppColor.textSecondary)
            }

            Text("1 - 7 Sep 2026")
                .font(AppTypography.captionRegular)
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    // MARK: - Steps Bar Chart

    private var activityChart: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                let chartWidth = width - 42
                let maxSteps: CGFloat = 16000.0
                let columnWidth = chartWidth / CGFloat(weekStepData.count)

                ZStack(alignment: .topLeading) {
                    // Outer Frame
                    Rectangle()
                        .stroke(Color.black.opacity(0.18), lineWidth: 1)
                        .frame(width: chartWidth, height: height)

                    // Horizontal Grid Lines at 0, 5000, 10000, 200
                    let yMarks: [(val: CGFloat, label: String)] = [
                        (16000, "200"),
                        (10000, "10000"),
                        (5000, "5000"),
                        (0, "0")
                    ]

                    ForEach(yMarks, id: \.label) { mark in
                        let yPos = height - (mark.val / maxSteps) * height

                        Path { path in
                            path.move(to: CGPoint(x: 0, y: yPos))
                            path.addLine(to: CGPoint(x: chartWidth, y: yPos))
                        }
                        .stroke(Color.black.opacity(0.18), lineWidth: 1)

                        Text(mark.label)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(AppColor.textSecondary)
                            .position(x: chartWidth + 20, y: max(yPos, 8))
                    }

                    // Vertical Dashed Lines between days
                    ForEach(1..<weekStepData.count, id: \.self) { idx in
                        let x = CGFloat(idx) * columnWidth
                        Path { path in
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: height))
                        }
                        .stroke(Color.black.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }

                    // Vertical Step Bars
                    ForEach(Array(weekStepData.enumerated()), id: \.element.id) { idx, item in
                        let centerX = CGFloat(idx) * columnWidth + (columnWidth / 2)
                        let barWidth: CGFloat = columnWidth * 0.72
                        let barHeight = max((CGFloat(item.steps) / maxSteps) * height, 4)

                        Rectangle()
                            .fill(activityBarColor)
                            .frame(width: barWidth, height: barHeight)
                            .position(x: centerX, y: height - barHeight / 2)
                    }
                }
            }
            .frame(height: 200)

            // X-Axis Day Labels
            HStack(spacing: 0) {
                ForEach(weekStepData) { item in
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
        VStack(spacing: AppSpacing.md) {
            metricInfoCard(
                title: "Rerata langkah harian",
                value: "1.500",
                unit: "langkah"
            )

            metricInfoCard(
                title: "Hari teraktif: Jumat",
                value: "8.900",
                unit: "langkah"
            )

            metricInfoCard(
                title: "Waktu aktif harian",
                value: "42",
                unit: "mnt"
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
        ActivityDetailView()
    }
}
