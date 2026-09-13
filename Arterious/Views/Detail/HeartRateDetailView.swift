import SwiftUI

/// Heart Rate detail screen displaying real HealthKit metrics and dynamic time range trends.
struct HeartRateDetailView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(SyncViewModel.self) private var syncViewModel
    @State private var selectedRange: TimeRangeOption = .week
    @State private var selectedIndex: Int? = nil

    private struct HRChartItem: Identifiable {
        let id = UUID()
        let label: String
        let fullDateString: String
        let minBPM: Double
        let maxBPM: Double

        var hasData: Bool {
            minBPM > 0 && maxBPM > 0
        }

        var rangeString: String {
            hasData ? "\(Int(minBPM))-\(Int(maxBPM)) BPM" : "Tidak ada data"
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

    private var currentChartData: [HRChartItem] {
        let calendar = Calendar.current
        let today = Date()

        switch selectedRange {
        case .hour:
            let currentHour = calendar.component(.hour, from: today)
            let df = DateFormatter()
            df.locale = Locale(identifier: "id_ID")
            df.dateFormat = "d MMM yyyy"
            let todayStr = df.string(from: today)

            let todaySummary = allSummaries.first(where: { calendar.isDateInToday($0.date) })
            let hr = todaySummary?.latestHeartRate ?? 0

            let hourSlots = [0, 4, 8, 12, 16, 20]
            return hourSlots.map { slot in
                let slotLabel = String(format: "%02d:00", slot)
                let isReached = currentHour >= slot
                let hasData = isReached && hr > 0
                let minVal = hasData ? (todaySummary?.minHeartRate24h ?? hr) : 0
                let maxVal = hasData ? (todaySummary?.maxHeartRate24h ?? hr) : 0
                return HRChartItem(
                    label: String(format: "%02d", slot),
                    fullDateString: "\(slotLabel), \(todayStr)",
                    minBPM: minVal,
                    maxBPM: maxVal
                )
            }

        case .day:
            let df = DateFormatter()
            df.locale = Locale(identifier: "id_ID")
            df.dateFormat = "d MMM yyyy"
            let todayStr = df.string(from: today)

            let currentHour = calendar.component(.hour, from: today)
            let todaySummary = allSummaries.first(where: { calendar.isDateInToday($0.date) })
            let liveHR = todaySummary?.latestHeartRate ?? todaySummary?.restingHeartRate ?? 0
            let minHR = todaySummary?.minHeartRate24h ?? (liveHR > 0 ? liveHR : 0)
            let maxHR = todaySummary?.maxHeartRate24h ?? (liveHR > 0 ? liveHR : 0)

            let segments: [(label: String, name: String, startHour: Int)] = [
                ("Pagi", "Pagi (06:00 - 12:00)", 6),
                ("Siang", "Siang (12:00 - 16:00)", 12),
                ("Sore", "Sore (16:00 - 19:00)", 16),
                ("Malam", "Malam (19:00 - 24:00)", 19)
            ]

            return segments.map { seg in
                let isPastOrCurrent = currentHour >= seg.startHour
                let hasData = isPastOrCurrent && liveHR > 0
                return HRChartItem(
                    label: seg.label,
                    fullDateString: "\(seg.name), \(todayStr)",
                    minBPM: hasData ? minHR : 0,
                    maxBPM: hasData ? maxHR : 0
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

                if let summary = allSummaries.first(where: { calendar.isDate($0.date, inSameDayAs: targetDate) }) {
                    let minVal = summary.minHeartRate24h ?? summary.restingHeartRate ?? summary.latestHeartRate ?? 0
                    let maxVal = summary.maxHeartRate24h ?? summary.latestHeartRate ?? summary.restingHeartRate ?? 0
                    let realMin = min(minVal, maxVal)
                    let realMax = max(minVal, maxVal)
                    return HRChartItem(label: label, fullDateString: fullDate, minBPM: realMin, maxBPM: realMax)
                } else {
                    return HRChartItem(label: label, fullDateString: fullDate, minBPM: 0, maxBPM: 0)
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
                let mins = weekSummaries.compactMap { $0.minHeartRate24h ?? $0.restingHeartRate ?? $0.latestHeartRate }.filter { $0 > 0 }
                let maxs = weekSummaries.compactMap { $0.maxHeartRate24h ?? $0.latestHeartRate ?? $0.restingHeartRate }.filter { $0 > 0 }

                let minB = mins.min() ?? 0
                let maxB = maxs.max() ?? 0

                return HRChartItem(
                    label: "Mg \(weekNum)",
                    fullDateString: "Minggu \(weekNum) (\(monthStr))",
                    minBPM: minB,
                    maxBPM: maxB
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

                let mins = monthSummaries.compactMap { $0.minHeartRate24h ?? $0.restingHeartRate ?? $0.latestHeartRate }.filter { $0 > 0 }
                let maxs = monthSummaries.compactMap { $0.maxHeartRate24h ?? $0.latestHeartRate ?? $0.restingHeartRate }.filter { $0 > 0 }

                let minB = mins.min() ?? 0
                let maxB = maxs.max() ?? 0

                return HRChartItem(
                    label: monthNames[monthNum - 1],
                    fullDateString: "\(fullMonthNames[monthNum - 1]) \(yearStr)",
                    minBPM: minB,
                    maxBPM: maxB
                )
            }
        }
    }

    private var currentMinBPM: Int? {
        let valid = currentChartData.map(\.minBPM).filter { $0 > 0 }
        guard let m = valid.min() else { return nil }
        return Int(m)
    }

    private var currentMaxBPM: Int? {
        let valid = currentChartData.map(\.maxBPM).filter { $0 > 0 }
        guard let m = valid.max() else { return nil }
        return Int(m)
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
                // MARK: - Middle Section (White Canvas)
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    // Time Range Segmented Picker
                    TimeRangePicker(selectedRange: $selectedRange)
                        .onChange(of: selectedRange) { _, _ in
                            selectedIndex = nil
                        }

                    // Metric Range Header (Updates with selection)
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
    }

    // MARK: - Range Header

    private var rangeHeader: some View {
        let selectedItem: HRChartItem? = {
            if let idx = selectedIndex, idx >= 0, idx < currentChartData.count {
                return currentChartData[idx]
            }
            return nil
        }()

        let headerTitle = selectedItem != nil ? "TERPILIH" : "RENTANG"
        let rangeText: String = {
            if let sel = selectedItem {
                return sel.hasData ? "\(Int(sel.minBPM))-\(Int(sel.maxBPM))" : "-"
            }
            if let minVal = currentMinBPM, let maxVal = currentMaxBPM {
                return "\(minVal)-\(maxVal)"
            }
            return "-"
        }()
        let dateText = selectedItem?.fullDateString ?? currentDateRangeString

        return VStack(alignment: .leading, spacing: 2) {
            Text(headerTitle)
                .font(AppTypography.footnoteRegular.weight(.semibold))
                .foregroundStyle(AppColor.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(rangeText)
                    .font(AppTypography.largeTitleBold)
                    .foregroundStyle(AppColor.textPrimary)
                    .contentTransition(.numericText())

                if rangeText != "-" {
                    Text("BPM")
                        .font(AppTypography.subheadlineBold)
                        .foregroundStyle(AppColor.textSecondary)
                }
            }

            Text(dateText)
                .font(AppTypography.captionRegular)
                .foregroundStyle(selectedItem != nil ? AppColor.Accent.red : AppColor.textSecondary)
        }
    }

    // MARK: - Range Bar Chart (Responsive to TimeRangeOption + Interactive Hover)

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

                        Path { path in
                            path.move(to: CGPoint(x: 0, y: yPos))
                            path.addLine(to: CGPoint(x: chartWidth, y: yPos))
                        }
                        .stroke(Color.black.opacity(0.2), lineWidth: 1)

                        Text(mark.label)
                            .font(AppTypography.caption2)
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

                    // Column Selection Highlight
                    if let selIdx = selectedIndex, selIdx < data.count {
                        let centerX = CGFloat(selIdx) * columnWidth + (columnWidth / 2)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AppColor.Accent.red.opacity(0.10))
                            .frame(width: max(columnWidth - 4, 12), height: height)
                            .position(x: centerX, y: height / 2)
                    }

                    // Vertical Range Bars
                    ForEach(Array(data.enumerated()), id: \.element.id) { idx, item in
                        let centerX = CGFloat(idx) * columnWidth + (columnWidth / 2)

                        if item.hasData {
                            let yTop = height - (CGFloat(item.maxBPM) / maxVal) * height
                            let yBottom = height - (CGFloat(item.minBPM) / maxVal) * height
                            let barHeight = max(yBottom - yTop, 6)
                            let barWidth: CGFloat = data.count > 7 ? 5 : 8

                            Capsule()
                                .fill(selectedIndex == idx ? AppColor.Accent.red : AppColor.Accent.red.opacity(0.85))
                                .frame(width: selectedIndex == idx ? barWidth + 2 : barWidth, height: barHeight)
                                .position(x: centerX, y: yTop + barHeight / 2)
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
                        let yTop = item.hasData ? (height - (CGFloat(item.maxBPM) / maxVal) * height) : (height - 30)
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

            // X-Axis Labels
            HStack(spacing: 0) {
                ForEach(Array(data.enumerated()), id: \.element.id) { idx, item in
                    Text(item.label)
                        .font(data.count > 7 ? AppTypography.caption2 : AppTypography.captionRegular)
                        .fontWeight(selectedIndex == idx ? .bold : .regular)
                        .foregroundStyle(selectedIndex == idx ? AppColor.Accent.red : AppColor.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.trailing, 40)
            .padding(.top, 8)
        }
        .padding(.vertical, AppSpacing.sm)
    }

    @ViewBuilder
    private func calloutTooltip(for item: HRChartItem, centerX: CGFloat, chartWidth: CGFloat, yTop: CGFloat) -> some View {
        VStack(spacing: 2) {
            Text(item.fullDateString)
                .font(AppTypography.caption2)
                .foregroundStyle(AppColor.textSecondary)
                .lineLimit(1)
            Text(item.rangeString)
                .font(AppTypography.captionBold)
                .foregroundStyle(item.hasData ? AppColor.Accent.red : AppColor.textSecondary)
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

    // MARK: - Bottom Detail Cards

    private var bottomDetailCards: some View {
        let lastHR = syncViewModel.healthRecord?.displayHeartRate.map { "\(Int($0))" } ?? "-"
        let sleepHR = syncViewModel.healthRecord?.restingHeartRate.map { "\(Int($0))" } ?? "-"

        let lastDateText: String = {
            if let dateStr = syncViewModel.healthRecord?.displayDate {
                return "Terakhir: \(dateStr)"
            }
            return "Terakhir"
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

        let rangeValue: String = {
            if let minVal = currentMinBPM, let maxVal = currentMaxBPM {
                return "\(minVal)-\(maxVal)"
            }
            return "-"
        }()

        return VStack(spacing: AppSpacing.md) {
            metricInfoCard(
                title: lastDateText,
                value: lastHR,
                unit: lastHR != "-" ? "BPM" : ""
            )

            metricInfoCard(
                title: rangeTitle,
                value: rangeValue,
                unit: rangeValue != "-" ? "BPM" : ""
            )

            metricInfoCard(
                title: "Detak Jantung Istirahat",
                value: sleepHR,
                unit: sleepHR != "-" ? "BPM" : ""
            )
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
        HeartRateDetailView()
            .environment(SyncViewModel())
    }
}

