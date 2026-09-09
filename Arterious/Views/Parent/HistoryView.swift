import SwiftUI

/// History tab screen with week calendar selector, daily summary, and metric cards.
struct HistoryView: View {

    @Environment(SyncViewModel.self) private var syncViewModel

    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var showingCalendarPicker: Bool = false
    @State private var selectedCalendarDate: Date = Date()

    private struct DayItem: Identifiable {
        let id: String
        let date: Date
        let dayName: String
        let dayNumber: Int
        let dateString: String
    }

    private var weekDays: [DayItem] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var days: [DayItem] = []
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "id_ID")
        dayFormatter.dateFormat = "EEE"

        let longFormatter = DateFormatter()
        longFormatter.locale = Locale(identifier: "id_ID")
        longFormatter.dateFormat = "d MMMM yyyy"

        for offset in (-6...0) {
            if let date = calendar.date(byAdding: .day, value: offset, to: today) {
                let dayNum = calendar.component(.day, from: date)
                let name = dayFormatter.string(from: date).uppercased()
                let dateStr = longFormatter.string(from: date)
                days.append(DayItem(
                    id: "\(offset)",
                    date: date,
                    dayName: name,
                    dayNumber: dayNum,
                    dateString: dateStr
                ))
            }
        }
        return days
    }

    private var currentSelectedDateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: selectedDate)
    }

    private var isViewingToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    private var historicalSummaryForSelectedDate: DailyHealthSummary? {
        let calendar = Calendar.current
        return syncViewModel.historicalSummaries.first { summary in
            calendar.isDate(summary.date, inSameDayAs: selectedDate)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    // Weekly Calendar Strip
                    weekCalendarStrip

                    // Selected Date Header
                    Text(currentSelectedDateString)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColor.textPrimary)
                        .padding(.top, AppSpacing.xs)

                    // "Summary" Blue Tinted Card
                    summaryCard

                    // Section "Data"
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("Data")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(AppColor.textPrimary)

                        // 1. Detak Jantung / Heart Rate (Regular Heart Rate)
                        NavigationLink {
                            HeartRateDetailView()
                        } label: {
                            HealthMetricSummaryCard(
                                iconName: "heart.fill",
                                iconColor: AppColor.Accent.red,
                                iconBgColor: AppColor.Accent.red12,
                                title: "Detak Jantung",
                                value: heartRateDisplayValue,
                                unit: heartRateDisplayValue == "-" ? nil : "BPM",
                                subtitle: heartRateSubtitle,
                                dateString: displayDateString,
                                chartValues: heartRateChartValues
                            )
                        }
                        .buttonStyle(.plain)

                        // 2. Tidur / Sleep
                        NavigationLink {
                            SleepDetailView()
                        } label: {
                            HealthMetricSummaryCard(
                                iconName: "bed.double.fill",
                                iconColor: Color(red: 0.55, green: 0.45, blue: 0.9),
                                iconBgColor: Color(red: 0.55, green: 0.45, blue: 0.9).opacity(0.12),
                                title: "Tidur",
                                value: sleepDisplayValue,
                                subtitle: sleepSubtitle,
                                dateString: displayDateString,
                                chartValues: sleepChartValues
                            )
                        }
                        .buttonStyle(.plain)

                        // 3. Aktivitas / Steps
                        NavigationLink {
                            ActivityDetailView()
                        } label: {
                            HealthMetricSummaryCard(
                                iconName: "figure.walk",
                                iconColor: AppColor.Accent.green,
                                iconBgColor: AppColor.Accent.green12,
                                title: "Aktivitas",
                                value: stepsDisplayValue,
                                subtitle: stepsSubtitle,
                                dateString: displayDateString,
                                chartValues: stepChartValues
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xxl)
            }
            .background(AppColor.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    calendarToolbarButton
                }
            }
            .sheet(isPresented: $showingCalendarPicker) {
                DatePicker(
                    "Select Date",
                    selection: $selectedCalendarDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
                .presentationDetents([.medium])
                .onChange(of: selectedCalendarDate) { _, newDate in
                    selectedDate = Calendar.current.startOfDay(for: newDate)
                    showingCalendarPicker = false
                }
            }
            .task {
                await syncViewModel.refreshIfNeeded()
            }
            .refreshable {
                await syncViewModel.refreshIfNeeded()
            }
        }
    }

    // MARK: - Weekly Calendar Strip

    private var weekCalendarStrip: some View {
        HStack(spacing: 0) {
            ForEach(weekDays) { item in
                let isSelected = Calendar.current.isDate(item.date, inSameDayAs: selectedDate)

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                        selectedDate = item.date
                    }
                } label: {
                    VStack(spacing: 8) {
                        Text(item.dayName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppColor.textSecondary)

                        ZStack {
                            if isSelected {
                                Circle()
                                    .fill(AppColor.Brand.primaryBlue.opacity(0.18))
                                    .frame(width: 38, height: 38)
                            }

                            Text("\(item.dayNumber)")
                                .font(.system(size: 16, weight: isSelected ? .bold : .medium))
                                .foregroundStyle(isSelected ? AppColor.Brand.primaryBlue : AppColor.textPrimary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, AppSpacing.xs)
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Summary")
                .font(AppTypography.subheadlineRegular)
                .foregroundStyle(AppColor.textSecondary)

            Text(summaryTitleText)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppColor.textPrimary)
                .padding(.top, 1)

            Text(summaryBodyText)
                .font(AppTypography.bodyRegular)
                .foregroundStyle(AppColor.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.Accent.blue12)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.r24))
    }

    // MARK: - Calendar Toolbar Button

    private var calendarToolbarButton: some View {
        Button {
            showingCalendarPicker = true
        } label: {
            Image(systemName: "calendar")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppColor.textPrimary)
                .frame(width: 34, height: 34)
                .background(AppColor.backgroundSecondary)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
        }
    }

    // MARK: - Dynamic Metric Formatted Values

    private var displayDateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: selectedDate)
    }

    private var heartRateDisplayValue: String {
        if isViewingToday {
            if let hr = syncViewModel.healthRecord?.displayHeartRate {
                return "\(Int(hr))"
            }
            return "-"
        } else {
            if let hr = historicalSummaryForSelectedDate?.latestHeartRate {
                return "\(Int(hr))"
            }
            return "-"
        }
    }

    private var heartRateSubtitle: String {
        if isViewingToday {
            return syncViewModel.healthRecord?.heartRateStatus ?? "Belum ada data"
        }
        if let hr = historicalSummaryForSelectedDate?.latestHeartRate {
            return hr < 55 ? "Cenderung Lambat" : (hr > 85 ? "Sedikit Meningkat" : "Stabil")
        }
        return "Belum ada data"
    }

    private var sleepDisplayValue: String {
        if isViewingToday {
            return syncViewModel.healthRecord?.sleepFormatted ?? "-"
        }
        if let s = historicalSummaryForSelectedDate?.sleepHours, s > 0 {
            let hours = Int(s)
            let mins = Int(((s - Double(hours)) * 60).rounded())
            return "\(hours)j \(mins)m"
        }
        return "-"
    }

    private var sleepSubtitle: String {
        if isViewingToday {
            return syncViewModel.healthRecord?.sleepStatus ?? "Belum ada data"
        }
        if let s = historicalSummaryForSelectedDate?.sleepHours, s > 0 {
            return s >= 7.0 ? "Kualitas tidur baik" : "Perlu istirahat lebih"
        }
        return "Belum ada data"
    }

    private var stepsDisplayValue: String {
        if isViewingToday {
            return syncViewModel.healthRecord?.stepFormatted ?? "-"
        }
        if let st = historicalSummaryForSelectedDate?.stepCount {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = "."
            return formatter.string(from: NSNumber(value: Int(st))) ?? "\(Int(st))"
        }
        return "-"
    }

    private var stepsSubtitle: String {
        if isViewingToday {
            return syncViewModel.healthRecord?.activityStatus ?? "Belum ada data"
        }
        if let st = historicalSummaryForSelectedDate?.stepCount {
            return st >= 4000 ? "Lebih baik dari biasanya" : (st > 0 ? "Cenderung santai hari ini" : "Belum mulai beraktivitas")
        }
        return "Belum ada data"
    }

    private var summaryTitleText: String {
        if isViewingToday {
            return syncViewModel.healthRecord?.summaryTitle ?? "Perubahan Pola Perlu Diperhatikan"
        }
        let hasData = (historicalSummaryForSelectedDate?.latestHeartRate != nil) ||
                      (historicalSummaryForSelectedDate?.sleepHours != nil && historicalSummaryForSelectedDate!.sleepHours! > 0) ||
                      (historicalSummaryForSelectedDate?.stepCount != nil)
        return hasData ? (syncViewModel.healthRecord?.summaryTitle ?? "Perubahan Pola Perlu Diperhatikan") : "Belum ada data"
    }

    private var summaryBodyText: String {
        if isViewingToday {
            return syncViewModel.healthRecord?.summaryBody ?? "Data detak jantung, tidur, dan langkah belum tersedia di Apple Health hari ini."
        }
        let hasData = (historicalSummaryForSelectedDate?.latestHeartRate != nil) ||
                      (historicalSummaryForSelectedDate?.sleepHours != nil && historicalSummaryForSelectedDate!.sleepHours! > 0) ||
                      (historicalSummaryForSelectedDate?.stepCount != nil)
        return hasData
            ? "Detak jantung, waktu tidur, dan jumlah langkah tercatat dari Apple Health pada tanggal ini."
            : "Data detak jantung, tidur, dan langkah tidak tercatat pada tanggal ini."
    }

    private var heartRateChartValues: [CGFloat] {
        let pts = syncViewModel.healthRecord?.recentHeartRatePoints ?? []
        if pts.count >= 3 {
            let maxVal = pts.max() ?? 1
            return pts.map { CGFloat(maxVal > 0 ? $0 / maxVal : 0.5) }
        }
        return [0.4, 0.7, 0.5, 0.9, 0.8, 0.6]
    }

    private var sleepChartValues: [CGFloat] {
        let pts = syncViewModel.healthRecord?.recentSleepPoints ?? []
        if pts.count >= 3 {
            let maxVal = pts.max() ?? 1
            return pts.map { CGFloat(maxVal > 0 ? $0 / maxVal : 0.5) }
        }
        return [0.3, 0.7, 0.4, 0.9, 0.8, 0.5]
    }

    private var stepChartValues: [CGFloat] {
        let pts = syncViewModel.healthRecord?.recentStepPoints ?? []
        if pts.count >= 3 {
            let maxVal = pts.max() ?? 1
            return pts.map { CGFloat(maxVal > 0 ? $0 / maxVal : 0.5) }
        }
        return [0.4, 0.6, 0.5, 0.9, 0.8, 0.3]
    }
}

#Preview {
    HistoryView()
        .environment(SyncViewModel())
}
