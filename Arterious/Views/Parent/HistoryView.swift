import SwiftUI

/// History tab screen (Riwayat) matching the exact Sketch design specification ("History / Default")
/// with calendar week selector, daily summary, and metric cards in Bahasa Indonesia.
struct HistoryView: View {

    @Environment(SyncViewModel.self) private var syncViewModel

    @State private var selectedDayIndex: Int = 2 // "SEL 3" default selected as per Sketch
    @State private var showingCalendarPicker: Bool = false
    @State private var selectedCalendarDate: Date = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3)) ?? Date()

    private struct DayItem: Identifiable {
        let id: Int
        let dayName: String
        let dayNumber: Int
        let dateString: String
    }

    private let weekDays: [DayItem] = [
        DayItem(id: 0, dayName: "MIN", dayNumber: 1, dateString: "1 September 2026"),
        DayItem(id: 1, dayName: "SEN", dayNumber: 2, dateString: "2 September 2026"),
        DayItem(id: 2, dayName: "SEL", dayNumber: 3, dateString: "3 September 2026"),
        DayItem(id: 3, dayName: "RAB", dayNumber: 4, dateString: "4 September 2026"),
        DayItem(id: 4, dayName: "KAM", dayNumber: 5, dateString: "5 September 2026"),
        DayItem(id: 5, dayName: "JUM", dayNumber: 6, dateString: "6 September 2026"),
        DayItem(id: 6, dayName: "SAB", dayNumber: 7, dateString: "7 September 2026")
    ]

    private var currentSelectedDateString: String {
        weekDays.first(where: { $0.id == selectedDayIndex })?.dateString ?? "3 September 2026"
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

                    // "Ringkasan" Card
                    summaryCard

                    // Section "Data"
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("Data")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(AppColor.textPrimary)

                        // 1. Detak Jantung
                        NavigationLink {
                            HeartRateDetailView()
                        } label: {
                            HealthMetricSummaryCard(
                                iconName: "heart.fill",
                                iconColor: AppColor.Accent.red,
                                iconBgColor: AppColor.Accent.red12,
                                title: "Detak Jantung",
                                value: heartRateDisplayValue,
                                unit: "BPM",
                                subtitle: heartRateSubtitle,
                                dateString: "9 Sep",
                                chartValues: heartRateChartValues
                            )
                        }
                        .buttonStyle(.plain)

                        // 2. Tidur
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
                                dateString: "9 Sep",
                                chartValues: sleepChartValues
                            )
                        }
                        .buttonStyle(.plain)

                        // 3. Aktivitas
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
                                dateString: "9 Sep",
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
            .navigationTitle("Riwayat")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    calendarToolbarButton
                }
            }
            .sheet(isPresented: $showingCalendarPicker) {
                VStack(spacing: AppSpacing.md) {
                    DatePicker(
                        "Pilih Tanggal",
                        selection: $selectedCalendarDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding()
                }
                .presentationDetents([.medium])
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
                let isSelected = item.id == selectedDayIndex

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                        selectedDayIndex = item.id
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
                        .frame(width: 38, height: 38)
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

    // MARK: - Metric Formatted Values

    private var heartRateDisplayValue: String {
        if let hr = syncViewModel.healthRecord?.displayHeartRate, hr > 0 {
            return "\(Int(hr))"
        }
        return "72"
    }

    private var heartRateSubtitle: String {
        if let status = syncViewModel.healthRecord?.heartRateStatus, !status.isEmpty, status != "Belum ada data" {
            return status
        }
        return "Dalam rentang normal"
    }

    private var sleepDisplayValue: String {
        if let s = syncViewModel.healthRecord?.sleepFormatted, s != "-" {
            return s
        }
        return "7j 40m"
    }

    private var sleepSubtitle: String {
        if let status = syncViewModel.healthRecord?.sleepStatus, !status.isEmpty, status != "Belum ada data" {
            return status
        }
        return "Kualitas tidur baik"
    }

    private var stepsDisplayValue: String {
        if let st = syncViewModel.healthRecord?.stepFormatted, st != "-" {
            return st
        }
        return "4.280"
    }

    private var stepsSubtitle: String {
        if let status = syncViewModel.healthRecord?.activityStatus, !status.isEmpty, status != "Belum ada data" {
            return status
        }
        return "Lebih baik dari biasanya"
    }

    private var summaryTitleText: String {
        if let title = syncViewModel.healthRecord?.summaryTitle, !title.isEmpty, title != "Belum ada data" {
            return title
        }
        return "Kondisi cukup stabil"
    }

    private var summaryBodyText: String {
        if let body = syncViewModel.healthRecord?.summaryBody, !body.isEmpty, !body.contains("belum tersedia") {
            return body
        }
        return "Pola tidur baik, detak jantung dalam rentang normal, dan aktivitas sedikit lebih baik dari biasanya."
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
