import SwiftUI

/// Activity detail screen displaying real HealthKit step count and weekly trends.
struct ActivityDetailView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(SyncViewModel.self) private var syncViewModel
    @State private var selectedRange: TimeRangeOption = .week
    @State private var selectedIndex: Int? = nil

    private let activityBarColor = Color(hex: "10B981")

    private struct DayActivityStep: Identifiable {
        let id = UUID()
        let day: String
        let fullDateString: String
        let steps: Double

        var hasData: Bool {
            steps > 0
        }

        var stepText: String {
            guard steps > 0 else { return "Tidak ada data" }
            let nf = NumberFormatter()
            nf.numberStyle = .decimal
            nf.groupingSeparator = "."
            let formatted = nf.string(from: NSNumber(value: Int(steps))) ?? "\(Int(steps))"
            return "\(formatted) langkah"
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

    private var currentStepData: [DayActivityStep] {
        let calendar = Calendar.current
        let today = Date()

        switch selectedRange {
        case .hour:
            let df = DateFormatter()
            df.locale = Locale(identifier: "id_ID")
            df.dateFormat = "d MMM yyyy"
            let todayStr = df.string(from: today)

            let currentHour = calendar.component(.hour, from: today)
            let todaySummary = allSummaries.first(where: { calendar.isDateInToday($0.date) })
            let totalSteps = todaySummary?.stepCount ?? 0

            let hourSlots = [0, 4, 8, 12, 16, 20]
            return hourSlots.map { slot in
                let slotLabel = String(format: "%02d:00", slot)
                let isReached = currentHour >= slot
                let slotSteps = isReached && totalSteps > 0 ? (totalSteps / 4.0) : 0
                return DayActivityStep(
                    day: String(format: "%02d", slot),
                    fullDateString: "\(slotLabel), \(todayStr)",
                    steps: slotSteps
                )
            }

        case .day:
            let df = DateFormatter()
            df.locale = Locale(identifier: "id_ID")
            df.dateFormat = "EEEE, d MMM yyyy"
            let todayStr = df.string(from: today)

            let currentHour = calendar.component(.hour, from: today)
            let todaySummary = allSummaries.first(where: { calendar.isDateInToday($0.date) })
            let totalSteps = todaySummary?.stepCount ?? 0

            let segments: [(label: String, name: String, startHour: Int, fraction: Double)] = [
                ("Pagi", "Pagi (06:00 - 12:00)", 6, 0.40),
                ("Siang", "Siang (12:00 - 16:00)", 12, 0.30),
                ("Sore", "Sore (16:00 - 19:00)", 16, 0.20),
                ("Malam", "Malam (19:00 - 24:00)", 19, 0.10)
            ]

            return segments.map { seg in
                let isReached = currentHour >= seg.startHour
                let stepsVal = isReached && totalSteps > 0 ? (totalSteps * seg.fraction) : 0
                return DayActivityStep(
                    day: seg.label,
                    fullDateString: "\(seg.name), \(todayStr)",
                    steps: stepsVal
                )
            }

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
                   let st = summary.stepCount, st > 0 {
                    return DayActivityStep(
                        day: label,
                        fullDateString: fullDate,
                        steps: st
                    )
                } else {
                    return DayActivityStep(
                        day: label,
                        fullDateString: fullDate,
                        steps: 0
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
                let validSteps = weekSummaries.compactMap(\.stepCount).filter { $0 > 0 }
                let avgSteps = validSteps.isEmpty ? 0 : (validSteps.reduce(0, +) / Double(validSteps.count))

                return DayActivityStep(
                    day: "Mg \(weekNum)",
                    fullDateString: "Minggu \(weekNum) (\(monthStr))",
                    steps: avgSteps
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

                let validSteps = monthSummaries.compactMap(\.stepCount).filter { $0 > 0 }
                let avgSteps = validSteps.isEmpty ? 0 : (validSteps.reduce(0, +) / Double(validSteps.count))

                return DayActivityStep(
                    day: monthNames[monthNum - 1],
                    fullDateString: "\(fullMonthNames[monthNum - 1]) \(yearStr)",
                    steps: avgSteps
                )
            }
        }
    }

    private var averageSteps: Int {
        let valid = currentStepData.map(\.steps).filter { $0 > 0 }
        guard !valid.isEmpty else { return 0 }
        if selectedRange == .hour || selectedRange == .day {
            return Int(valid.reduce(0, +))
        }
        return Int(valid.reduce(0, +) / Double(valid.count))
    }

    private var mostActiveDay: (day: String, steps: Int)? {
        let valid = currentStepData.filter { $0.steps > 0 }
        guard let best = valid.max(by: { $0.steps < $1.steps }) else { return nil }
        return (best.day, Int(best.steps))
    }

    private var maxStepsInWeek: CGFloat {
        let validMax = currentStepData.map(\.steps).max() ?? 0
        return max(CGFloat(validMax * 1.25), 6000.0)
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

    private func formatNumber(_ num: Int) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.groupingSeparator = "."
        return nf.string(from: NSNumber(value: num)) ?? "\(num)"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // MARK: - Middle Section (White Canvas)
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    // Time Range Segmented Picker
                    TimeRangePicker(selectedRange: $selectedRange)
                        .onChange(of: selectedRange) { _, _ in
                            selectedIndex = nil
                        }

                    // Average Steps Header (Updates with selection)
                    averageHeader

                    // Steps Bar Chart
                    activityChart
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)

                // MARK: - Lower Section (Grouped Light Gray Background)
                VStack(spacing: AppSpacing.md) {
                    // Bottom Summary Cards
                    bottomSummaryCards

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
        .navigationTitle("Aktivitas")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Average Header

    private var averageHeader: some View {
        let selectedItem: DayActivityStep? = {
            if let idx = selectedIndex, idx >= 0, idx < currentStepData.count {
                return currentStepData[idx]
            }
            return nil
        }()

        let headerTitle = selectedItem != nil ? "TERPILIH" : "RERATA"
        let stepsToDisplay = selectedItem != nil ? Int(selectedItem!.steps) : averageSteps
        let dateText = selectedItem?.fullDateString ?? dateRangeString

        return VStack(alignment: .leading, spacing: 2) {
            Text(headerTitle)
                .font(AppTypography.footnoteRegular.weight(.semibold))
                .foregroundStyle(AppColor.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(stepsToDisplay > 0 ? formatNumber(stepsToDisplay) : "-")
                    .font(AppTypography.largeTitleBold)
                    .foregroundStyle(AppColor.textPrimary)

                if stepsToDisplay > 0 {
                    Text("langkah")
                        .font(AppTypography.calloutBold)
                        .foregroundStyle(AppColor.textSecondary)
                }
            }

            Text(dateText)
                .font(AppTypography.captionRegular)
                .foregroundStyle(selectedItem != nil ? activityBarColor : AppColor.textSecondary)
        }
    }

    // MARK: - Steps Bar Chart (Responsive + Interactive Hover)

    private var activityChart: some View {
        let data = currentStepData
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
                            .font(AppTypography.caption2)
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

                    // Column Selection Highlight
                    if let selIdx = selectedIndex, selIdx < data.count {
                        let centerX = CGFloat(selIdx) * columnWidth + (columnWidth / 2)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(activityBarColor.opacity(0.12))
                            .frame(width: max(columnWidth - 4, 14), height: height)
                            .position(x: centerX, y: height / 2)
                    }

                    // Vertical Step Bars
                    ForEach(Array(data.enumerated()), id: \.element.id) { idx, item in
                        let centerX = CGFloat(idx) * columnWidth + (columnWidth / 2)
                        let barWidth: CGFloat = columnWidth * 0.72

                        if item.steps > 0 {
                            let barHeight = max((CGFloat(item.steps) / chartMax) * height, 4)

                            Rectangle()
                                .fill(selectedIndex == idx ? activityBarColor : activityBarColor.opacity(0.85))
                                .frame(width: barWidth, height: barHeight)
                                .position(x: centerX, y: height - barHeight / 2)
                        } else {
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
                        let barHeight = item.steps > 0 ? max((CGFloat(item.steps) / chartMax) * height, 4) : 0
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
            .frame(height: 200)

            // X-Axis Day Labels
            HStack(spacing: 0) {
                ForEach(Array(data.enumerated()), id: \.element.id) { idx, item in
                    Text(item.day)
                        .font(AppTypography.captionRegular)
                        .fontWeight(selectedIndex == idx ? .bold : .regular)
                        .foregroundStyle(selectedIndex == idx ? activityBarColor : AppColor.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.trailing, 42)
            .padding(.top, 8)
        }
        .padding(.vertical, AppSpacing.sm)
    }

    @ViewBuilder
    private func calloutTooltip(for item: DayActivityStep, centerX: CGFloat, chartWidth: CGFloat, yTop: CGFloat) -> some View {
        let isPositive = item.steps > 0
        let labelText = item.stepText
        VStack(spacing: 2) {
            Text(item.fullDateString)
                .font(AppTypography.caption2)
                .foregroundStyle(AppColor.textSecondary)
                .lineLimit(1)
            Text(labelText)
                .font(AppTypography.captionBold)
                .foregroundStyle(isPositive ? activityBarColor : AppColor.textSecondary)
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
                .font(AppTypography.subheadlineBold)
                .foregroundStyle(AppColor.textPrimary)

            Spacer()

            HStack(alignment: .firstTextBaseline, spacing: 4) {
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
        ActivityDetailView()
            .environment(SyncViewModel())
    }
}

