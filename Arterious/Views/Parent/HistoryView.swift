import SwiftUI

/// History tab screen (Riwayat) with empty state, calendar selector, daily summary, and metric cards in Bahasa Indonesia.
struct HistoryView: View {

    @State private var hasHistoryData: Bool = false
    @State private var selectedDayIndex: Int = 2 // "SEL 3"
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
            ZStack {
                AppColor.backgroundPrimary
                    .ignoresSafeArea()

                if !hasHistoryData {
                    emptyStateView
                } else {
                    historyContentView
                }
            }
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

                    Button {
                        hasHistoryData.toggle()
                        showingCalendarPicker = false
                    } label: {
                        Text(hasHistoryData ? "Tampilkan Empty State" : "Tampilkan Contoh Data")
                            .font(AppTypography.captionRegular)
                            .foregroundStyle(AppColor.actionBlue)
                    }
                    .padding(.bottom, AppSpacing.sm)
                }
                .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Text("Belum Ada Riwayat Data")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color(hex: "707076"))

            Text("Belum ada riwayat kesehatan yang tercatat.\nHubungkan akun terlebih dahulu untuk\nmulai melihat data harian.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color(hex: "8E8E93"))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    // MARK: - History Content View

    private var historyContentView: some View {
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
                            value: "72",
                            unit: "BPM",
                            subtitle: "Dalam rentang normal",
                            dateString: "9 Sep",
                            chartValues: [0.4, 0.7, 0.5, 0.9, 0.8, 0.6]
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
                            value: "7j 40m",
                            subtitle: "Kualitas tidur baik",
                            dateString: "9 Sep",
                            chartValues: [0.3, 0.7, 0.4, 0.9, 0.8, 0.5]
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

                                Circle()
                                    .fill(AppColor.Brand.primaryBlue)
                                    .frame(width: 32, height: 32)
                            }

                            Text("\(item.dayNumber)")
                                .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                                .foregroundStyle(isSelected ? Color.white : AppColor.textPrimary)
                        }
                        .frame(width: 38, height: 38)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, AppSpacing.sm)
        .background(AppColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.r24))
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Ringkasan")
                .font(AppTypography.subheadlineRegular)
                .foregroundStyle(AppColor.textSecondary)

            Text("Kondisi cukup stabil")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppColor.textPrimary)
                .padding(.top, 1)

            Text("Pola tidur baik, detak jantung dalam rentang normal, dan aktivitas sedikit lebih baik dari biasanya.")
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
