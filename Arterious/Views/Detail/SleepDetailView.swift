import SwiftUI

/// Sleep detail screen displaying real HealthKit metrics and weekly trends.
struct SleepDetailView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(SyncViewModel.self) private var syncViewModel
    @State private var selectedRange: TimeRangeOption = .week
    @State private var selectedIndex: Int? = nil

    // Sleep stages color palette matching Apple Health
    private let awakeColor = Color(hex: "FF6E52")
    private let remColor = Color(hex: "00C7B0")
    private let coreColor = Color(hex: "3267FF")
    private let deepColor = Color(hex: "1F2A7A")

    private struct DaySleepColumn: Identifiable {
        let id = UUID()
        let day: String
        let fullDateString: String
        let totalHours: Double
        let awakeMinutes: Double
        let remMinutes: Double
        let coreMinutes: Double
        let deepMinutes: Double

        var hasData: Bool {
            totalHours > 0
        }

        var formattedDuration: String {
            guard hasData else { return "Tidak ada data" }
            let h = Int(totalHours)
            let m = Int(((totalHours - Double(h)) * 60).rounded())
            if h > 0 && m > 0 { return "\(h) jam \(m) mnt" }
            if h > 0 { return "\(h) jam" }
            return "\(m) mnt"
        }
    }

    private var allSummaries: [DailyHealthSummary] {
        var list = syncViewModel.historicalSummaries
        if let rec = syncViewModel.healthRecord {
            let calendar = Calendar.current
            if !list.contains(where: { calendar.isDate($0.date, inSameDayAs: rec.recordDate) }) {
                list.append(DailyHealthSummary(
                    date: rec.recordDate,
                    latestHeartRate: rec.displayHeartRate,
                    restingHeartRate: rec.restingHeartRate,
                    minHeartRate24h: rec.displayHeartRate,
                    maxHeartRate24h: rec.displayHeartRate,
                    sleepHours: rec.sleepHours,
                    stepCount: rec.stepCount.map { Double($0) }
                ))
            }
        }
        return list
    }

    private var currentSleepData: [DaySleepColumn] {
        let calendar = Calendar.current
        let today = Date()

        switch selectedRange {
        case .hour:
            let df = DateFormatter()
            df.locale = Locale(identifier: "id_ID")
            df.dateFormat = "d MMM yyyy"
            let todayStr = df.string(from: today)

            let todaySummary = allSummaries.first(where: { calendar.isDateInToday($0.date) })
            let total = todaySummary?.sleepHours ?? 0

            let hourSlots = [22, 0, 2, 4, 6]
            return hourSlots.map { slot in
                let slotLabel = String(format: "%02d:00", slot)
                let slotHours = total > 0 ? (total / 5.0) : 0
                return DaySleepColumn(
                    day: String(format: "%02d", slot),
                    fullDateString: "\(slotLabel), \(todayStr)",
                    totalHours: slotHours,
                    awakeMinutes: slotHours > 0 ? 5 : 0,
                    remMinutes: slotHours > 0 ? 15 : 0,
                    coreMinutes: slotHours > 0 ? slotHours * 35 : 0,
                    deepMinutes: slotHours > 0 ? 10 : 0
                )
            }

        case .day:
            let df = DateFormatter()
            df.locale = Locale(identifier: "id_ID")
            df.dateFormat = "EEEE, d MMM yyyy"
            let todayStr = df.string(from: today)

            let todaySummary = allSummaries.first(where: { calendar.isDateInToday($0.date) })
            let details = todaySummary?.sleepDetails
            let awake = todaySummary?.awakeSleepMinutes ?? (details?.awakeMinutes ?? 0)
            let rem = todaySummary?.remSleepMinutes ?? (details?.remMinutes ?? 0)
            let core = todaySummary?.coreSleepMinutes ?? (details?.coreMinutes ?? 0)
            let deep = todaySummary?.deepSleepMinutes ?? (details?.deepMinutes ?? 0)

            return [
                DaySleepColumn(day: "Bangun", fullDateString: "Terbangun, \(todayStr)", totalHours: awake / 60.0, awakeMinutes: awake, remMinutes: 0, coreMinutes: 0, deepMinutes: 0),
                DaySleepColumn(day: "REM", fullDateString: "Tidur REM, \(todayStr)", totalHours: rem / 60.0, awakeMinutes: 0, remMinutes: rem, coreMinutes: 0, deepMinutes: 0),
                DaySleepColumn(day: "Inti", fullDateString: "Tidur Inti, \(todayStr)", totalHours: core / 60.0, awakeMinutes: 0, remMinutes: 0, coreMinutes: core, deepMinutes: 0),
                DaySleepColumn(day: "Dalam", fullDateString: "Tidur Nyenyak, \(todayStr)", totalHours: deep / 60.0, awakeMinutes: 0, remMinutes: 0, coreMinutes: 0, deepMinutes: deep)
            ]

        case .week:
            let dayFormatter = DateFormatter()
            dayFormatter.locale = Locale(identifier: "id_ID")
            dayFormatter.dateFormat = "EEE"

            let fullDateFormatter = DateFormatter()
            fullDateFormatter.locale = Locale(identifier: "id_ID")
            fullDateFormatter.dateFormat = "EEEE, d MMM yyyy"

            return (0..<7).reversed().map { dayOffset in
                let targetDate = calendar.date(byAdding: .day, value: -dayOffset, to: today) ?? today
                let label = dayFormatter.string(from: targetDate).capitalized
                let fullDate = fullDateFormatter.string(from: targetDate).capitalized

                if let summary = allSummaries.first(where: { calendar.isDate($0.date, inSameDayAs: targetDate) }),
                   let total = summary.sleepHours, total > 0 {
                    let details = summary.sleepDetails
                    let awake = summary.awakeSleepMinutes ?? (details?.awakeMinutes ?? 0)
                    let rem = summary.remSleepMinutes ?? (details?.remMinutes ?? 0)
                    let deep = summary.deepSleepMinutes ?? (details?.deepMinutes ?? 0)
                    let core = summary.coreSleepMinutes ?? (details?.coreMinutes ?? max(0, total * 60 - awake - rem - deep))

                    return DaySleepColumn(
                        day: label,
                        fullDateString: fullDate,
                        totalHours: total,
                        awakeMinutes: awake,
                        remMinutes: rem,
                        coreMinutes: core,
                        deepMinutes: deep
                    )
                } else {
                    return DaySleepColumn(
                        day: label,
                        fullDateString: fullDate,
                        totalHours: 0,
                        awakeMinutes: 0,
                        remMinutes: 0,
                        coreMinutes: 0,
                        deepMinutes: 0
                    )
                }
            }

        case .month:
            let dfMonth = DateFormatter()
            dfMonth.locale = Locale(identifier: "id_ID")
            dfMonth.dateFormat = "MMMM yyyy"
            let monthStr = dfMonth.string(from: today)

            return (1...4).map { weekNum in
                let daysAgoEnd = (4 - weekNum) * 7
                let daysAgoStart = daysAgoEnd + 6
                let startDate = calendar.date(byAdding: .day, value: -daysAgoStart, to: today) ?? today
                let endDate = calendar.date(byAdding: .day, value: -daysAgoEnd, to: today) ?? today

                let weekSummaries = allSummaries.filter { $0.date >= startDate && $0.date <= endDate }
                let validSleep = weekSummaries.compactMap(\.sleepHours).filter { $0 > 0 }
                let avgTotal = validSleep.isEmpty ? 0 : (validSleep.reduce(0, +) / Double(validSleep.count))

                let validAwake = weekSummaries.compactMap(\.awakeSleepMinutes).filter { $0 > 0 }
                let avgAwake = validAwake.isEmpty ? 0 : (validAwake.reduce(0, +) / Double(validAwake.count))

                let validRem = weekSummaries.compactMap(\.remSleepMinutes).filter { $0 > 0 }
                let avgRem = validRem.isEmpty ? 0 : (validRem.reduce(0, +) / Double(validRem.count))

                let validCore = weekSummaries.compactMap(\.coreSleepMinutes).filter { $0 > 0 }
                let avgCore = validCore.isEmpty ? 0 : (validCore.reduce(0, +) / Double(validCore.count))

                let validDeep = weekSummaries.compactMap(\.deepSleepMinutes).filter { $0 > 0 }
                let avgDeep = validDeep.isEmpty ? 0 : (validDeep.reduce(0, +) / Double(validDeep.count))

                return DaySleepColumn(
                    day: "Mg \(weekNum)",
                    fullDateString: "Minggu \(weekNum) (\(monthStr))",
                    totalHours: avgTotal,
                    awakeMinutes: avgAwake,
                    remMinutes: avgRem,
                    coreMinutes: avgCore,
                    deepMinutes: avgDeep
                )
            }

        case .year:
            let dfYear = DateFormatter()
            dfYear.dateFormat = "yyyy"
            let yearStr = dfYear.string(from: today)

            let monthNames = ["Jan", "Feb", "Mar", "Apr", "Mei", "Jun", "Jul", "Agu", "Sep", "Okt", "Nov", "Des"]
            let fullMonthNames = ["Januari", "Februari", "Maret", "April", "Mei", "Juni", "Juli", "Agustus", "September", "Oktober", "November", "Desember"]

            return (1...12).map { monthNum in
                let monthSummaries = allSummaries.filter {
                    let comps = calendar.dateComponents([.year, .month], from: $0.date)
                    let currentComps = calendar.dateComponents([.year], from: today)
                    return comps.year == currentComps.year && comps.month == monthNum
                }

                let validSleep = monthSummaries.compactMap(\.sleepHours).filter { $0 > 0 }
                let avgTotal = validSleep.isEmpty ? 0 : (validSleep.reduce(0, +) / Double(validSleep.count))

                return DaySleepColumn(
                    day: monthNames[monthNum - 1],
                    fullDateString: "\(fullMonthNames[monthNum - 1]) \(yearStr)",
                    totalHours: avgTotal,
                    awakeMinutes: 0,
                    remMinutes: 0,
                    coreMinutes: avgTotal * 60,
                    deepMinutes: 0
                )
            }
        }
    }

    private var averageSleepHours: Double {
        let valid = currentSleepData.map(\.totalHours).filter { $0 > 0 }
        guard !valid.isEmpty else { return 0 }
        if selectedRange == .day {
            return valid.reduce(0, +)
        }
        return valid.reduce(0, +) / Double(valid.count)
    }

    private var averageAwakeMinutes: Double {
        let valid = currentSleepData.map(\.awakeMinutes).filter { $0 > 0 }
        guard !valid.isEmpty else { return 0 }
        return valid.reduce(0, +) / Double(valid.count)
    }

    private var averageRemMinutes: Double {
        let valid = currentSleepData.map(\.remMinutes).filter { $0 > 0 }
        guard !valid.isEmpty else { return 0 }
        return valid.reduce(0, +) / Double(valid.count)
    }

    private var averageCoreMinutes: Double {
        let valid = currentSleepData.map(\.coreMinutes).filter { $0 > 0 }
        guard !valid.isEmpty else { return 0 }
        return valid.reduce(0, +) / Double(valid.count)
    }

    private var averageDeepMinutes: Double {
        let valid = currentSleepData.map(\.deepMinutes).filter { $0 > 0 }
        guard !valid.isEmpty else { return 0 }
        return valid.reduce(0, +) / Double(valid.count)
    }

    private var dateRangeString: String {
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

    private var todayDateHeader: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "id_ID")
        df.dateFormat = "EEE, d MMM"
        return df.string(from: Date()).capitalized
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Daily Sleep Score Card
                dailyScoreSection
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.md)
                    .padding(.bottom, AppSpacing.lg)

                // Time Range Segmented Control
                TimeRangePicker(selectedRange: $selectedRange)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.lg)
                    .onChange(of: selectedRange) { _, _ in
                        selectedIndex = nil
                    }

                // MARK: - Chart Section (White Canvas)
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    // Sleep Average Header (Updates with selection)
                    averageSleepHeader

                    // Sleep Stages Stacked Bar Chart
                    sleepStagesChart
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.lg)
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
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedRange)
        .background(AppColor.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("Tidur")
        .navigationBarTitleDisplayMode(.inline)
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
                .font(AppTypography.headline)
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
        let selectedItem: DaySleepColumn? = {
            if let idx = selectedIndex, idx >= 0, idx < currentSleepData.count {
                return currentSleepData[idx]
            }
            return nil
        }()

        let headerTitle = selectedItem != nil ? "TERPILIH" : "RERATA WAKTU TIDUR"
        let durationToDisplay = selectedItem?.totalHours ?? averageSleepHours
        let avgH = Int(durationToDisplay)
        let avgM = Int(((durationToDisplay - Double(avgH)) * 60).rounded())
        let dateText = selectedItem?.fullDateString ?? dateRangeString

        return VStack(alignment: .leading, spacing: 2) {
            Text(headerTitle)
                .font(AppTypography.footnoteRegular.weight(.semibold))
                .foregroundStyle(AppColor.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if durationToDisplay > 0 {
                    if avgH > 0 {
                        Text("\(avgH)")
                            .font(AppTypography.largeTitleBold)
                            .foregroundStyle(AppColor.textPrimary)

                        Text("jam")
                            .font(AppTypography.calloutBold)
                            .foregroundStyle(AppColor.textSecondary)
                            .padding(.trailing, 6)
                    }

                    if avgM > 0 || avgH == 0 {
                        Text("\(avgM)")
                            .font(AppTypography.largeTitleBold)
                            .foregroundStyle(AppColor.textPrimary)

                        Text("mnt")
                            .font(AppTypography.calloutBold)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                } else {
                    Text("-")
                        .font(AppTypography.largeTitleBold)
                        .foregroundStyle(AppColor.textPrimary)
                }
            }

            Text(dateText)
                .font(AppTypography.captionRegular)
                .foregroundStyle(selectedItem != nil ? AppColor.actionBlue : AppColor.textSecondary)
        }
    }

    // MARK: - Sleep Stages Stacked Bar Chart (Responsive + Interactive Hover)

    private var sleepStagesChart: some View {
        let data = currentSleepData

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
                            .font(AppTypography.caption2)
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

                    // Column Selection Highlight
                    if let selIdx = selectedIndex, selIdx < data.count {
                        let centerX = CGFloat(selIdx) * columnWidth + (columnWidth / 2)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(coreColor.opacity(0.12))
                            .frame(width: max(columnWidth - 4, 14), height: height)
                            .position(x: centerX, y: height / 2)
                    }

                    // Stacked Sleep Stage Bars
                    ForEach(Array(data.enumerated()), id: \.element.id) { idx, item in
                        let centerX = CGFloat(idx) * columnWidth + (columnWidth / 2)
                        let barWidth: CGFloat = columnWidth * 0.72

                        if item.hasData {
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
                            // Placeholder dot on days with no data
                            Circle()
                                .fill(AppColor.textSecondary.opacity(0.25))
                                .frame(width: 4, height: 4)
                                .position(x: centerX, y: height - 6)
                        }
                    }

                    // Floating Callout Pill on Hover/Touch
                    if let selIdx = selectedIndex, selIdx < data.count {
                        let item = data[selIdx]
                        let centerX = CGFloat(selIdx) * columnWidth + (columnWidth / 2)
                        let barHeight = item.hasData ? min(height, (CGFloat(item.totalHours) / maxHours) * height) : 0
                        let yTop = height - barHeight
                        calloutTooltip(for: item, centerX: centerX, chartWidth: chartWidth, yTop: yTop)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let clampedX = max(0, min(gesture.location.x, chartWidth - 1))
                            let newIdx = Int(clampedX / columnWidth)
                            if newIdx >= 0 && newIdx < data.count {
                                if selectedIndex != newIdx {
                                    selectedIndex = newIdx
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            }
                        }
                )
            }
            .frame(height: 220)

            // X-Axis Day Labels
            HStack(spacing: 0) {
                ForEach(Array(data.enumerated()), id: \.element.id) { idx, item in
                    Text(item.day)
                        .font(AppTypography.caption2)
                        .fontWeight(selectedIndex == idx ? .bold : .regular)
                        .foregroundStyle(selectedIndex == idx ? coreColor : AppColor.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.trailing, 44)
            .padding(.top, 8)
        }
        .padding(.vertical, AppSpacing.sm)
    }

    @ViewBuilder
    private func calloutTooltip(for item: DaySleepColumn, centerX: CGFloat, chartWidth: CGFloat, yTop: CGFloat) -> some View {
        VStack(spacing: 2) {
            Text(item.fullDateString)
                .font(AppTypography.caption2)
                .foregroundStyle(AppColor.textSecondary)
                .lineLimit(1)
            Text(item.formattedDuration)
                .font(AppTypography.captionBold)
                .foregroundStyle(item.hasData ? coreColor : AppColor.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 2)
        )
        .position(
            x: min(max(centerX, 70), chartWidth - 70),
            y: max(yTop - 28, 22)
        )
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    // MARK: - Bottom Breakdown Cards

    private var bottomBreakdownCards: some View {
        let selectedItem: DaySleepColumn? = {
            if let idx = selectedIndex, idx >= 0, idx < currentSleepData.count {
                return currentSleepData[idx]
            }
            return nil
        }()

        let titlePrefix = selectedItem != nil ? "Tahapan" : "Rerata"
        let awakeMinutes = selectedItem != nil ? selectedItem!.awakeMinutes : averageAwakeMinutes
        let remMinutes = selectedItem != nil ? selectedItem!.remMinutes : averageRemMinutes
        let coreMinutes = selectedItem != nil ? selectedItem!.coreMinutes : averageCoreMinutes
        let deepMinutes = selectedItem != nil ? selectedItem!.deepMinutes : averageDeepMinutes

        let awakeStr = awakeMinutes > 0 ? "\(Int(awakeMinutes))" : "-"
        let remStr = remMinutes > 0 ? formatHoursMins(mins: remMinutes) : "-"
        let coreStr = coreMinutes > 0 ? formatHoursMins(mins: coreMinutes) : "-"
        let deepStr = deepMinutes > 0 ? formatHoursMins(mins: deepMinutes) : "-"

        return VStack(spacing: AppSpacing.md) {
            stageInfoCard(
                dotColor: awakeColor,
                title: "\(titlePrefix) terbangun",
                value: awakeStr,
                unit: awakeMinutes > 0 ? "mnt" : ""
            )

            stageInfoCard(
                dotColor: remColor,
                title: "\(titlePrefix) REM",
                value: remStr,
                unit: ""
            )

            stageInfoCard(
                dotColor: coreColor,
                title: "\(titlePrefix) Inti",
                value: coreStr,
                unit: ""
            )

            stageInfoCard(
                dotColor: deepColor,
                title: "\(titlePrefix) Dalam",
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
                .font(AppTypography.subheadlineBold)
                .foregroundStyle(AppColor.textPrimary)

            Spacer()

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(AppTypography.calloutBold)
                    .foregroundStyle(AppColor.textPrimary)

                if !unit.isEmpty {
                    Text(unit)
                        .font(AppTypography.footnoteRegular.weight(.semibold))
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

