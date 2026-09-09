import SwiftUI

/// Sleep detail screen matching Screenshot 2 in the Child monitoring flow.
struct SleepDetailView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var selectedRange: TimeRangeOption = .week

    // Sleep stages color palette matching the screenshot
    private let awakeColor = Color(hex: "FF6E52")
    private let remColor = Color(hex: "00C7B0")
    private let coreColor = Color(hex: "3267FF")
    private let deepColor = Color(hex: "1F2A7A")

    private struct DaySleepColumn: Identifiable {
        let id = UUID()
        let day: String
        let totalHours: Double
        let awakeMinutes: Double
        let remMinutes: Double
        let coreMinutes: Double
        let deepMinutes: Double
    }

    private let weekSleepData: [DaySleepColumn] = [
        DaySleepColumn(day: "Sun", totalHours: 8.1, awakeMinutes: 20, remMinutes: 95, coreMinutes: 310, deepMinutes: 60),
        DaySleepColumn(day: "Mon", totalHours: 6.8, awakeMinutes: 15, remMinutes: 80, coreMinutes: 270, deepMinutes: 45),
        DaySleepColumn(day: "Tue", totalHours: 6.9, awakeMinutes: 18, remMinutes: 85, coreMinutes: 275, deepMinutes: 35),
        DaySleepColumn(day: "Wed", totalHours: 7.0, awakeMinutes: 12, remMinutes: 90, coreMinutes: 280, deepMinutes: 40),
        DaySleepColumn(day: "Thu", totalHours: 7.1, awakeMinutes: 16, remMinutes: 88, coreMinutes: 285, deepMinutes: 38),
        DaySleepColumn(day: "Fri", totalHours: 6.7, awakeMinutes: 14, remMinutes: 82, coreMinutes: 265, deepMinutes: 42),
        DaySleepColumn(day: "Sat", totalHours: 7.3, awakeMinutes: 22, remMinutes: 92, coreMinutes: 290, deepMinutes: 35)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                // Condition Summary
                conditionHeader

                // Daily Sleep Score Card (Min, 6 Sep)
                dailyScoreSection

                // Time Range Segmented Control
                TimeRangePicker(selectedRange: $selectedRange)

                // Sleep Average Header
                averageSleepHeader

                // Sleep Stages Stacked Bar Chart
                sleepStagesChart

                // Bottom Breakdown Rows
                bottomBreakdownCards

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
                Text("Tidur")
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

            Text("Pola tidur baik, detak jantung dalam rentang normal, dan aktivitas sedikit lebih baik dari biasanya.")
                .font(AppTypography.subheadlineRegular)
                .foregroundStyle(AppColor.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Daily Sleep Score Section

    private var dailyScoreSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Min, 6 Sep")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppColor.textPrimary)

            DonutProgressGaugeView(
                score: 80,
                statusTitle: "Tinggi",
                durationText: "8j 5m",
                durationScoreText: "50/50",
                sleepTimeText: "7j 5m",
                sleepScoreText: "28/30",
                awakeText: "17 mnt",
                awakeScoreText: "7/20"
            )
        }
    }

    // MARK: - Average Sleep Stat Header

    private var averageSleepHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("RERATA WAKTU TIDUR")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColor.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("7")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)

                Text("jam")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppColor.textSecondary)
                    .padding(.trailing, 6)

                Text("54")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)

                Text("mnt")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppColor.textSecondary)
            }

            Text("1 - 7 Sep 2026")
                .font(AppTypography.captionRegular)
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    // MARK: - Sleep Stages Stacked Bar Chart

    private var sleepStagesChart: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                let chartWidth = width - 44
                let maxHours: CGFloat = 10.0
                let columnWidth = chartWidth / CGFloat(weekSleepData.count)

                ZStack(alignment: .topLeading) {
                    // Outer Border
                    Rectangle()
                        .stroke(Color.black.opacity(0.18), lineWidth: 1)
                        .frame(width: chartWidth, height: height)

                    // Horizontal Grid Lines & Y Labels (08.00 down to 0)
                    let yMarks: [(ratio: CGFloat, label: String)] = [
                        (0.95, "12.00"),
                        (0.85, "10.00"),
                        (0.72, "08.00"),
                        (0.60, "06.00"),
                        (0.48, "04.00"),
                        (0.36, "02.00"),
                        (0.24, "12.00"),
                        (0.12, "10.00"),
                        (0.00, "0")
                    ]

                    ForEach(yMarks, id: \.label) { mark in
                        let yPos = height - (mark.ratio * height)

                        Path { path in
                            path.move(to: CGPoint(x: 0, y: yPos))
                            path.addLine(to: CGPoint(x: chartWidth, y: yPos))
                        }
                        .stroke(Color.black.opacity(0.18), lineWidth: 1)

                        Text(mark.label)
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(AppColor.textSecondary)
                            .position(x: chartWidth + 22, y: max(yPos, 6))
                    }

                    // Vertical Dashed Lines between days
                    ForEach(1..<weekSleepData.count, id: \.self) { idx in
                        let x = CGFloat(idx) * columnWidth
                        Path { path in
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: height))
                        }
                        .stroke(Color.black.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }

                    // Stacked Sleep Stage Bars
                    ForEach(Array(weekSleepData.enumerated()), id: \.element.id) { idx, item in
                        let centerX = CGFloat(idx) * columnWidth + (columnWidth / 2)
                        let barWidth: CGFloat = columnWidth * 0.72
                        let totalBarHeight = (CGFloat(item.totalHours) / maxHours) * height

                        // Render layered sleep intervals
                        VStack(spacing: 1) {
                            // Awake segment
                            Rectangle()
                                .fill(awakeColor)
                                .frame(height: max(totalBarHeight * 0.08, 3))

                            // REM segment
                            Rectangle()
                                .fill(remColor)
                                .frame(height: max(totalBarHeight * 0.20, 6))

                            // Core segment
                            Rectangle()
                                .fill(coreColor)
                                .frame(height: max(totalBarHeight * 0.52, 14))

                            // Deep segment
                            Rectangle()
                                .fill(deepColor)
                                .frame(height: max(totalBarHeight * 0.20, 6))
                        }
                        .frame(width: barWidth)
                        .position(x: centerX, y: height - totalBarHeight / 2)
                    }
                }
            }
            .frame(height: 220)

            // X-Axis Day Labels
            HStack(spacing: 0) {
                ForEach(weekSleepData) { item in
                    Text(item.day)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(AppColor.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.trailing, 44)
            .padding(.top, 8)
        }
        .padding(.vertical, AppSpacing.sm)
    }

    // MARK: - Bottom Breakdown Cards

    private var bottomBreakdownCards: some View {
        VStack(spacing: AppSpacing.md) {
            stageInfoCard(
                dotColor: coreColor,
                title: "Rerata terbangun",
                value: "15",
                unit: "mnt"
            )

            stageInfoCard(
                dotColor: remColor,
                title: "Rerata REM",
                value: "1j 29m",
                unit: ""
            )

            stageInfoCard(
                dotColor: coreColor,
                title: "Rerata Inti",
                value: "4j 55m",
                unit: ""
            )

            stageInfoCard(
                dotColor: deepColor,
                title: "Rerata Inti",
                value: "25",
                unit: "m"
            )
        }
    }

    private func stageInfoCard(dotColor: Color, title: String, value: String, unit: String) -> some View {
        HStack(spacing: AppSpacing.md) {
            Circle()
                .fill(dotColor)
                .frame(width: 10, height: 10)

            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColor.textPrimary)

            Spacer()

            HStack(alignment: .firstTextBaseline, spacing: 3) {
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
        SleepDetailView()
    }
}
