import SwiftUI

/// Sleep detail screen displaying real HealthKit metrics and weekly trends.
struct SleepDetailView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(SyncViewModel.self) private var syncViewModel
    @State private var selectedRange: TimeRangeOption = .week

    // Sleep stages color palette matching Apple Health
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

    private var weeklySleepData: [DaySleepColumn] {
        let history = syncViewModel.historicalSummaries
        let calendar = Calendar.current
        let df = DateFormatter()
        df.locale = Locale(identifier: "id_ID")
        df.dateFormat = "EEE"

        if history.isEmpty {
            // If empty, generate past 7 days with zero values
            let today = Date()
            return (0..<7).reversed().map { offset in
                let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
                return DaySleepColumn(
                    day: df.string(from: date).capitalized,
                    totalHours: 0,
                    awakeMinutes: 0,
                    remMinutes: 0,
                    coreMinutes: 0,
                    deepMinutes: 0
                )
            }
        }

        let slice = history.suffix(7)
        return slice.map { summary in
            let total = summary.sleepHours ?? 0
            let awake = summary.awakeSleepMinutes ?? 0
            let rem = summary.remSleepMinutes ?? 0
            let deep = summary.deepSleepMinutes ?? 0
            let core = summary.coreSleepMinutes ?? (total > 0 && rem == 0 && deep == 0 ? total * 60 : 0)

            return DaySleepColumn(
                day: df.string(from: summary.date).capitalized,
                totalHours: total,
                awakeMinutes: awake,
                remMinutes: rem,
                coreMinutes: core,
                deepMinutes: deep
            )
        }
    }

    private var averageSleepHours: Double {
        let valid = weeklySleepData.map(\.totalHours).filter { $0 > 0 }
        guard !valid.isEmpty else { return 0 }
        return valid.reduce(0, +) / Double(valid.count)
    }

    private var averageAwakeMinutes: Double {
        let valid = weeklySleepData.map(\.awakeMinutes).filter { $0 > 0 }
        guard !valid.isEmpty else { return 0 }
        return valid.reduce(0, +) / Double(valid.count)
    }

    private var averageRemMinutes: Double {
        let valid = weeklySleepData.map(\.remMinutes).filter { $0 > 0 }
        guard !valid.isEmpty else { return 0 }
        return valid.reduce(0, +) / Double(valid.count)
    }

    private var averageCoreMinutes: Double {
        let valid = weeklySleepData.map(\.coreMinutes).filter { $0 > 0 }
        guard !valid.isEmpty else { return 0 }
        return valid.reduce(0, +) / Double(valid.count)
    }

    private var averageDeepMinutes: Double {
        let valid = weeklySleepData.map(\.deepMinutes).filter { $0 > 0 }
        guard !valid.isEmpty else { return 0 }
        return valid.reduce(0, +) / Double(valid.count)
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

    private var todayDateHeader: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "id_ID")
        df.dateFormat = "EEE, d MMM"
        return df.string(from: Date()).capitalized
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // MARK: - Upper Section (Pure White Canvas)
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    // Condition Summary
                    conditionHeader

                    // Daily Sleep Score Card
                    dailyScoreSection

                    // Time Range Segmented Control
                    TimeRangePicker(selectedRange: $selectedRange)

                    // Sleep Average Header
                    averageSleepHeader

                    // Sleep Stages Stacked Bar Chart
                    sleepStagesChart
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)

                // MARK: - Lower Section (Grouped Light Gray Background)
                VStack(spacing: AppSpacing.md) {
                    // Bottom Breakdown Rows
                    bottomBreakdownCards

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
        .background {
            VStack(spacing: 0) {
                Color.white
                    .frame(height: 550)
                AppColor.backgroundPrimary
            }
            .ignoresSafeArea()
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(Color.white, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColor.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
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
            Text(syncViewModel.healthRecord?.summaryTitle ?? (syncViewModel.healthRecord?.sleepStatus ?? "Pola Istirahat Terpantau"))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppColor.textPrimary)

            Text(syncViewModel.healthRecord?.summaryBody ?? "Pola tidur dan waktu istirahat tercatat secara berkala dari Apple Health.")
                .font(AppTypography.subheadlineRegular)
                .foregroundStyle(AppColor.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Daily Sleep Score Section

    private var dailyScoreSection: some View {
        let sleepHours = syncViewModel.healthRecord?.sleepHours ?? 0
        let hasData = sleepHours > 0

        let score = hasData ? min(100, max(45, Int((sleepHours / 8.0) * 88))) : 0
        let statusTitle = hasData ? (sleepHours >= 7.0 ? "Baik" : (sleepHours >= 6.0 ? "Cukup" : "Kurang")) : "Belum Ada"

        let durationText = hasData ? syncViewModel.healthRecord?.sleepFormatted ?? "-" : "-"
        let awakeMins = averageAwakeMinutes > 0 ? "\(Int(averageAwakeMinutes)) mnt" : "-"

        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(todayDateHeader)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppColor.textPrimary)

            DonutProgressGaugeView(
                score: score,
                statusTitle: statusTitle,
                durationText: durationText,
                durationScoreText: hasData ? "\(min(50, Int(sleepHours * 6.5)))/50" : "-/50",
                sleepTimeText: durationText,
                sleepScoreText: hasData ? "\(min(30, Int(sleepHours * 4.0)))/30" : "-/30",
                awakeText: awakeMins,
                awakeScoreText: hasData ? "15/20" : "-/20"
            )
        }
    }

    // MARK: - Average Sleep Stat Header

    private var averageSleepHeader: some View {
        let avgH = Int(averageSleepHours)
        let avgM = Int(((averageSleepHours - Double(avgH)) * 60).rounded())

        return VStack(alignment: .leading, spacing: 2) {
            Text("RERATA WAKTU TIDUR")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColor.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if averageSleepHours > 0 {
                    Text("\(avgH)")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(AppColor.textPrimary)

                    Text("jam")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppColor.textSecondary)
                        .padding(.trailing, 6)

                    Text("\(avgM)")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(AppColor.textPrimary)

                    Text("mnt")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppColor.textSecondary)
                } else {
                    Text("-")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(AppColor.textPrimary)
                }
            }

            Text(dateRangeString)
                .font(AppTypography.captionRegular)
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    // MARK: - Sleep Stages Stacked Bar Chart

    private var sleepStagesChart: some View {
        let data = weeklySleepData

        return VStack(spacing: 0) {
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                let chartWidth = width - 44
                let maxHours: CGFloat = 10.0
                let columnCount = max(CGFloat(data.count), 1)
                let columnWidth = chartWidth / columnCount

                ZStack(alignment: .topLeading) {
                    // Outer Border
                    Rectangle()
                        .stroke(Color.black.opacity(0.18), lineWidth: 1)
                        .frame(width: chartWidth, height: height)

                    // Horizontal Grid Lines & Y Labels
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
                    ForEach(1..<data.count, id: \.self) { idx in
                        let x = CGFloat(idx) * columnWidth
                        Path { path in
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: height))
                        }
                        .stroke(Color.black.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }

                    // Stacked Sleep Stage Bars
                    ForEach(Array(data.enumerated()), id: \.element.id) { idx, item in
                        let centerX = CGFloat(idx) * columnWidth + (columnWidth / 2)
                        let barWidth: CGFloat = columnWidth * 0.72

                        if item.totalHours > 0 {
                            let totalBarHeight = min(height, (CGFloat(item.totalHours) / maxHours) * height)

                            // Render layered sleep intervals
                            VStack(spacing: 1) {
                                if item.awakeMinutes > 0 {
                                    Rectangle()
                                        .fill(awakeColor)
                                        .frame(height: max(totalBarHeight * 0.08, 2))
                                }

                                if item.remMinutes > 0 {
                                    Rectangle()
                                        .fill(remColor)
                                        .frame(height: max(totalBarHeight * 0.20, 3))
                                }

                                Rectangle()
                                    .fill(coreColor)
                                    .frame(height: max(totalBarHeight * (item.deepMinutes > 0 ? 0.52 : 0.75), 6))

                                if item.deepMinutes > 0 {
                                    Rectangle()
                                        .fill(deepColor)
                                        .frame(height: max(totalBarHeight * 0.20, 3))
                                }
                            }
                            .frame(width: barWidth)
                            .position(x: centerX, y: height - totalBarHeight / 2)
                        } else {
                            // Subtle placeholder dot on days with no data
                            Circle()
                                .fill(AppColor.textSecondary.opacity(0.25))
                                .frame(width: 4, height: 4)
                                .position(x: centerX, y: height - 6)
                        }
                    }
                }
            }
            .frame(height: 220)

            // X-Axis Day Labels
            HStack(spacing: 0) {
                ForEach(data) { item in
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
        let awakeStr = averageAwakeMinutes > 0 ? "\(Int(averageAwakeMinutes))" : "-"
        let remStr = averageRemMinutes > 0 ? formatHoursMins(mins: averageRemMinutes) : "-"
        let coreStr = averageCoreMinutes > 0 ? formatHoursMins(mins: averageCoreMinutes) : "-"
        let deepStr = averageDeepMinutes > 0 ? formatHoursMins(mins: averageDeepMinutes) : "-"

        return VStack(spacing: AppSpacing.md) {
            stageInfoCard(
                dotColor: awakeColor,
                title: "Rerata terbangun",
                value: awakeStr,
                unit: averageAwakeMinutes > 0 ? "mnt" : ""
            )

            stageInfoCard(
                dotColor: remColor,
                title: "Rerata REM",
                value: remStr,
                unit: ""
            )

            stageInfoCard(
                dotColor: coreColor,
                title: "Rerata Inti",
                value: coreStr,
                unit: ""
            )

            stageInfoCard(
                dotColor: deepColor,
                title: "Rerata Dalam",
                value: deepStr,
                unit: ""
            )
        }
    }

    private func formatHoursMins(mins: Double) -> String {
        let totalMins = Int(mins.rounded())
        let h = totalMins / 60
        let m = totalMins % 60
        if h > 0 {
            return "\(h)j \(m)m"
        }
        return "\(m) mnt"
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
            .environment(SyncViewModel())
    }
}
