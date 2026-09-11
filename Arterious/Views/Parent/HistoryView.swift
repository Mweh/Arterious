import SwiftUI

/// History tab screen (Riwayat) with calendar selector, daily summary, and metric cards matching Figma design.
struct HistoryView: View {

    @Environment(SyncViewModel.self) private var syncViewModel
    @AppStorage("userRole") private var userRole: String = UserRole.parent.rawValue

    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var showingCalendarPicker: Bool = false
    @State private var tempCalendarDate: Date = Date()

    private var isChildEmpty: Bool {
        userRole == UserRole.child.rawValue && (syncViewModel.syncState.status != .accepted || syncViewModel.healthRecord == nil)
    }

    private struct DayItem: Identifiable {
        let id: String
        let date: Date
        let dayName: String
        let dayNumber: Int
        let dateString: String
    }

    private var weekDays: [DayItem] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1 // 1 = Sunday (MIN)
        calendar.locale = Locale(identifier: "id_ID")

        let startOfDay = calendar.startOfDay(for: selectedDate)
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: startOfDay) else {
            return []
        }

        var days: [DayItem] = []
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "id_ID")
        dayFormatter.dateFormat = "EEE"

        let longFormatter = DateFormatter()
        longFormatter.locale = Locale(identifier: "id_ID")
        longFormatter.dateFormat = "d MMMM yyyy"

        for offset in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: offset, to: weekInterval.start) {
                let dayNum = calendar.component(.day, from: date)
                let name = dayFormatter.string(from: date).uppercased()
                let dateStr = longFormatter.string(from: date)
                days.append(DayItem(
                    id: "\(date.timeIntervalSince1970)",
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
            ZStack {
                AppColor.backgroundPrimary
                    .ignoresSafeArea()

                if isChildEmpty {
                    childEmptyStateView
                } else {
                    historyContentView
                }
            }
            .navigationTitle("Riwayat")
            .toolbar {
                if !isChildEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        calendarToolbarButton
                    }
                }
            }
            .sheet(isPresented: $showingCalendarPicker) {
                calendarPickerSheet
                    .presentationDetents([.height(350)])
                    .presentationDragIndicator(.visible)
            }
            .task {
                await syncViewModel.refreshIfNeeded()
            }
            .refreshable {
                await syncViewModel.refreshIfNeeded()
            }
        }
    }

    // MARK: - History Content View

    private var historyContentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                // Horizontal Calendar Strip
                weekCalendarStrip

                // Selected Date Text (e.g. "3 September 2026")
                Text(currentSelectedDateString)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(AppColor.textPrimary)
                    .padding(.top, AppSpacing.xs)

                // Summary Card ("Ringkasan")
                summaryCard

                // Metric Cards Section
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("Data")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppColor.textPrimary)

                    // 1. Detak Jantung Card
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

                    // 2. Tidur Card
                    NavigationLink {
                        SleepDetailView()
                    } label: {
                        HealthMetricSummaryCard(
                            iconName: "bed.double.fill",
                            iconColor: Color(red: 0.35, green: 0.35, blue: 0.85),
                            iconBgColor: Color(red: 0.35, green: 0.35, blue: 0.85).opacity(0.12),
                            title: "Tidur",
                            value: sleepDisplayValue,
                            subtitle: sleepSubtitle,
                            dateString: displayDateString,
                            chartValues: sleepChartValues
                        )
                    }
                    .buttonStyle(.plain)

                    // 3. Aktivitas Card
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
                    VStack(spacing: 6) {
                        Text(item.dayName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppColor.textSecondary)

                        ZStack {
                            if isSelected {
                                Circle()
                                    .fill(Color(hex: "D0E6FF"))
                                    .frame(width: 36, height: 36)
                            }

                            Text("\(item.dayNumber)")
                                .font(.system(size: 17, weight: isSelected ? .bold : .regular))
                                .foregroundStyle(isSelected ? AppColor.Brand.primaryBlue : AppColor.textPrimary)
                        }
                        .frame(width: 36, height: 36)
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
            Text("Ringkasan")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: "687B94"))

            Text(summaryTitleText)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppColor.textPrimary)
                .padding(.top, 1)

            Text(summaryBodyText)
                .font(AppTypography.subheadlineRegular)
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
            tempCalendarDate = selectedDate
            showingCalendarPicker = true
        } label: {
            Image(systemName: "calendar")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColor.textPrimary)
                .frame(width: 38, height: 38)
                .background(Color.white)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Calendar Picker Bottom Sheet (Matching Image 2)

    private var calendarPickerSheet: some View {
        VStack(spacing: 0) {
            Text("Pilih Tanggal")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppColor.textPrimary)
                .padding(.top, 20)
                .padding(.bottom, 8)

            DatePicker(
                "",
                selection: $tempCalendarDate,
                displayedComponents: .date
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .environment(\.locale, Locale(identifier: "id_ID"))
            .frame(maxWidth: .infinity)

            Spacer()

            Button {
                selectedDate = Calendar.current.startOfDay(for: tempCalendarDate)
                showingCalendarPicker = false
            } label: {
                Text("Simpan")
                    .font(AppTypography.buttonLabel)
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppColor.actionBlue)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(Color.white)
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
            return "72"
        } else {
            if let hr = historicalSummaryForSelectedDate?.latestHeartRate {
                return "\(Int(hr))"
            }
            return "72"
        }
    }

    private var heartRateSubtitle: String {
        if isViewingToday {
            return syncViewModel.healthRecord?.heartRateStatus ?? "Dalam rentang normal"
        }
        if let hr = historicalSummaryForSelectedDate?.latestHeartRate {
            return hr < 55 ? "Cenderung Lambat" : (hr > 85 ? "Sedikit Meningkat" : "Dalam rentang normal")
        }
        return "Dalam rentang normal"
    }

    private var sleepDisplayValue: String {
        if isViewingToday {
            return syncViewModel.healthRecord?.sleepFormatted ?? "7j 40m"
        }
        if let s = historicalSummaryForSelectedDate?.sleepHours, s > 0 {
            let hours = Int(s)
            let mins = Int(((s - Double(hours)) * 60).rounded())
            return "\(hours)j \(mins)m"
        }
        return "7j 40m"
    }

    private var sleepSubtitle: String {
        if isViewingToday {
            return syncViewModel.healthRecord?.sleepStatus ?? "Kualitas tidur baik"
        }
        if let s = historicalSummaryForSelectedDate?.sleepHours, s > 0 {
            return s >= 7.0 ? "Kualitas tidur baik" : "Perlu istirahat lebih"
        }
        return "Kualitas tidur baik"
    }

    private var stepsDisplayValue: String {
        if isViewingToday {
            return syncViewModel.healthRecord?.stepFormatted ?? "4.280"
        }
        if let st = historicalSummaryForSelectedDate?.stepCount {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = "."
            return formatter.string(from: NSNumber(value: Int(st))) ?? "\(Int(st))"
        }
        return "4.280"
    }

    private var stepsSubtitle: String {
        if isViewingToday {
            return syncViewModel.healthRecord?.activityStatus ?? "Lebih baik dari biasanya"
        }
        if let st = historicalSummaryForSelectedDate?.stepCount {
            return st >= 4000 ? "Lebih baik dari biasanya" : (st > 0 ? "Cenderung santai hari ini" : "Belum mulai beraktivitas")
        }
        return "Lebih baik dari biasanya"
    }

    private var summaryTitleText: String {
        if isViewingToday {
            return syncViewModel.healthRecord?.summaryTitle ?? "Kondisi cukup stabil"
        }
        let hasData = (historicalSummaryForSelectedDate?.latestHeartRate != nil) ||
                      (historicalSummaryForSelectedDate?.sleepHours != nil && historicalSummaryForSelectedDate!.sleepHours! > 0) ||
                      (historicalSummaryForSelectedDate?.stepCount != nil)
        return hasData ? (syncViewModel.healthRecord?.summaryTitle ?? "Kondisi cukup stabil") : "Kondisi cukup stabil"
    }

    private var summaryBodyText: String {
        if isViewingToday {
            return syncViewModel.healthRecord?.summaryBody ?? "Pola tidur baik, detak jantung dalam rentang normal, dan aktivitas sedikit lebih baik dari biasanya."
        }
        let hasData = (historicalSummaryForSelectedDate?.latestHeartRate != nil) ||
                      (historicalSummaryForSelectedDate?.sleepHours != nil && historicalSummaryForSelectedDate!.sleepHours! > 0) ||
                      (historicalSummaryForSelectedDate?.stepCount != nil)
        return hasData
            ? (syncViewModel.healthRecord?.summaryBody ?? "Pola tidur baik, detak jantung dalam rentang normal, dan aktivitas sedikit lebih baik dari biasanya.")
            : "Pola tidur baik, detak jantung dalam rentang normal, dan aktivitas sedikit lebih baik dari biasanya."
    }

    private var heartRateChartValues: [CGFloat] {
        let pts = syncViewModel.healthRecord?.recentHeartRatePoints ?? []
        if pts.count >= 3 {
            let maxVal = pts.max() ?? 1
            return pts.map { CGFloat(maxVal > 0 ? $0 / maxVal : 0.5) }
        }
        return [0.4, 0.6, 0.3, 0.9, 0.7, 1.0, 0.5]
    }

    private var sleepChartValues: [CGFloat] {
        let pts = syncViewModel.healthRecord?.recentSleepPoints ?? []
        if pts.count >= 3 {
            let maxVal = pts.max() ?? 1
            return pts.map { CGFloat(maxVal > 0 ? $0 / maxVal : 0.5) }
        }
        return [0.3, 0.7, 0.4, 0.9, 0.8, 0.6, 0.5]
    }

    private var stepChartValues: [CGFloat] {
        let pts = syncViewModel.healthRecord?.recentStepPoints ?? []
        if pts.count >= 3 {
            let maxVal = pts.max() ?? 1
            return pts.map { CGFloat(maxVal > 0 ? $0 / maxVal : 0.5) }
        }
        return [0.4, 0.6, 0.5, 0.9, 0.8, 0.7, 0.3]
    }

    // MARK: - Child Empty State

    private var childEmptyStateView: some View {
        VStack(spacing: AppSpacing.sm) {
            Spacer()
                .frame(height: 140)

            Text("Belum Ada Riwayat")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(.systemGray))
                .multilineTextAlignment(.center)

            Text("Hubungkan dengan akun orang tua di menu Beranda atau Akses untuk mulai memantau riwayat data kesehatan.")
                .font(AppTypography.subheadlineRegular)
                .foregroundStyle(Color(.systemGray2))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, AppSpacing.xl)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    HistoryView()
        .environment(SyncViewModel())
}
