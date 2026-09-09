import SwiftUI

/// History tab screen matching Image 4 with week calendar selector, daily summary, and metric cards.
struct HistoryView: View {

    @State private var selectedDayIndex: Int = 2 // "TUE 3" selected by default
    @State private var showingCalendarPicker: Bool = false
    @State private var selectedCalendarDate: Date = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3)) ?? Date()

    private struct DayItem: Identifiable {
        let id: Int
        let dayName: String
        let dayNumber: Int
        let dateString: String
    }

    private let weekDays: [DayItem] = [
        DayItem(id: 0, dayName: "SUN", dayNumber: 1, dateString: "September 1, 2026"),
        DayItem(id: 1, dayName: "MON", dayNumber: 2, dateString: "September 2, 2026"),
        DayItem(id: 2, dayName: "TUE", dayNumber: 3, dateString: "September 3, 2026"),
        DayItem(id: 3, dayName: "WED", dayNumber: 4, dateString: "September 4, 2026"),
        DayItem(id: 4, dayName: "THU", dayNumber: 5, dateString: "September 5, 2026"),
        DayItem(id: 5, dayName: "FRI", dayNumber: 6, dateString: "September 6, 2026"),
        DayItem(id: 6, dayName: "SAT", dayNumber: 7, dateString: "September 7, 2026")
    ]

    private var currentSelectedDateString: String {
        weekDays.first(where: { $0.id == selectedDayIndex })?.dateString ?? "September 3, 2026"
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

                        // 1. Detak Jantung / Heart Rate
                        NavigationLink {
                            HeartRateDetailView()
                        } label: {
                            HealthMetricSummaryCard(
                                iconName: "heart.fill",
                                iconColor: AppColor.Accent.red,
                                iconBgColor: AppColor.Accent.red12,
                                title: "Detak Jantung",
                                value: "72",
                                unit: "BPM",
                                subtitle: "Dalam rentang normal",
                                dateString: "9 Sep",
                                chartValues: [0.4, 0.7, 0.5, 0.9, 0.8, 0.6]
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
                                value: "7j 40m",
                                subtitle: "Kualitas tidur baik",
                                dateString: "9 Sep",
                                chartValues: [0.3, 0.7, 0.4, 0.9, 0.8, 0.5]
                            )
                        }
                        .buttonStyle(.plain)

                        // 3. Aktivitas / Activity
                        NavigationLink {
                            ActivityDetailView()
                        } label: {
                            HealthMetricSummaryCard(
                                iconName: "figure.walk",
                                iconColor: AppColor.Accent.green,
                                iconBgColor: AppColor.Accent.green12,
                                title: "Aktivitas",
                                value: "4.280",
                                subtitle: "Lebih baik dari biasanya",
                                dateString: "9 Sep",
                                chartValues: [0.4, 0.6, 0.5, 0.9, 0.8, 0.3]
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

            Text("Condition fairly stable")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppColor.textPrimary)
                .padding(.top, 1)

            Text("Good sleep pattern, heart rate within normal range, and activity slightly better than usual.")
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
}

#Preview {
    HistoryView()
}
