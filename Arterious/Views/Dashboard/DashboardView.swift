import SwiftUI

struct DashboardView: View {

    @Bindable var viewModel: DashboardViewModel
    @State private var showParentSelectSheet: Bool = false

    @MainActor
    init(viewModel: DashboardViewModel) {
        self.viewModel = viewModel
    }

    @MainActor
    init() {
        self.viewModel = DashboardViewModel()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hue: 0.6, saturation: 0.02, brightness: 0.97)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if let err = viewModel.errorMessage ?? viewModel.syncViewModel.errorMessage {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                Text(err)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.red)
                                Spacer()
                            }
                            .padding(12)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .padding(.top, 4)
                        }

                        if viewModel.syncViewModel.syncState.role == .child && !viewModel.isPaired {
                            // NOT PAIRED STATE (Screenshot 1)
                            HomeNotPairedCardView(syncViewModel: viewModel.syncViewModel)
                                .padding(.top, 8)
                        } else {
                            // PAIRED / DEFAULT STATE (Screenshot 2)
                            pairedContentView
                        }

                        // Medical disclaimer
                        Text("Arterious reflects general wellness trends from Apple HealthKit and is not intended for medical diagnosis.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 12)
                            .padding(.bottom, 60)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Beranda")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isLoading {
                        ProgressView()
                    }
                }
            }
            .refreshable {
                await viewModel.loadDashboardData()
            }
            .task {
                await viewModel.loadDashboardData()
            }
            .sheet(isPresented: $showParentSelectSheet) {
                parentSelectSheet
            }
        }
    }

    // MARK: - Paired Content (Screenshot 2)

    @ViewBuilder
    private var pairedContentView: some View {
        VStack(alignment: .leading, spacing: 18) {
            // ONLY show Parent Name Dropdown Header in Child's POV! (Never in Parent's POV)
            if viewModel.syncViewModel.syncState.role == .child {
                Button {
                    showParentSelectSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Text(viewModel.displayedParentName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.primary)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }

            // Today Summary Card (Light blue gradient/tint card)
            VStack(alignment: .leading, spacing: 8) {
                Text("Ringkasan Hari Ini")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hue: 0.6, saturation: 0.6, brightness: 0.6))

                Text(summaryTitle)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)

                Text(summaryBody)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.primary.opacity(0.75))
                    .lineSpacing(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(
                LinearGradient(
                    colors: [Color(hue: 0.58, saturation: 0.12, brightness: 0.98),
                             Color(hue: 0.60, saturation: 0.18, brightness: 0.95)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.blue.opacity(0.08), lineWidth: 1)
            )

            // Section "Data Hari Ini"
            Text("Data Hari Ini")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.top, 4)

            // 1. Heart Rate Row Card
            MetricRowCardView(
                iconName: "heart.fill",
                iconColor: Color(hue: 0.98, saturation: 0.75, brightness: 0.95),
                iconBgColor: Color(hue: 0.98, saturation: 0.12, brightness: 0.98),
                title: "Detak Jantung",
                value: heartRateValue,
                unit: "BPM",
                statusText: heartRateStatusText,
                dateText: currentDateText,
                barHeights: heartRateBarHeights,
                barColor: Color(hue: 0.98, saturation: 0.65, brightness: 0.9)
            )

            // 2. Sleep Row Card
            MetricRowCardView(
                iconName: "bed.double.fill",
                iconColor: Color(hue: 0.68, saturation: 0.6, brightness: 0.85),
                iconBgColor: Color(hue: 0.68, saturation: 0.12, brightness: 0.98),
                title: "Tidur",
                value: sleepValue,
                unit: nil,
                statusText: sleepStatusText,
                dateText: currentDateText,
                barHeights: sleepBarHeights,
                barColor: Color(hue: 0.68, saturation: 0.65, brightness: 0.8)
            )

            // 3. Activity Row Card
            MetricRowCardView(
                iconName: "figure.walk",
                iconColor: Color(hue: 0.42, saturation: 0.7, brightness: 0.75),
                iconBgColor: Color(hue: 0.42, saturation: 0.15, brightness: 0.98),
                title: "Aktivitas",
                value: stepsValue,
                unit: nil,
                statusText: activityStatusText,
                dateText: currentDateText,
                barHeights: stepsBarHeights,
                barColor: Color(hue: 0.42, saturation: 0.7, brightness: 0.7)
            )
        }
    }

    // MARK: - Formatters & Dynamic Data

    private var hasAnyRealData: Bool {
        viewModel.displayedSummary.restingHeartRate != nil ||
        viewModel.displayedSummary.sleepHours != nil ||
        viewModel.displayedSummary.stepCount != nil ||
        viewModel.currentHealthRecord?.restingHeartRate != nil ||
        viewModel.currentHealthRecord?.sleepHours != nil ||
        viewModel.currentHealthRecord?.stepCount != nil
    }

    private var summaryTitle: String {
        if let title = viewModel.currentHealthRecord?.summaryTitle {
            return title
        }
        return hasAnyRealData ? "Kondisi cukup stabil" : "Belum ada data hari ini"
    }

    private var summaryBody: String {
        if let body = viewModel.currentHealthRecord?.summaryBody {
            return body
        }
        return hasAnyRealData
            ? "Pola tidur dan aktivitas tercatat dari Apple Health."
            : "Data kesehatan belum tercatat di Apple Health hari ini."
    }

    private var currentDateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: viewModel.displayedSummary.date)
    }

    private var heartRateValue: String {
        if let r = viewModel.currentHealthRecord?.restingHeartRate {
            return "\(Int(r))"
        }
        if let rhr = viewModel.displayedSummary.restingHeartRate {
            return "\(Int(rhr))"
        }
        return "-"
    }

    private var heartRateStatusText: String {
        if let status = viewModel.currentHealthRecord?.heartRateStatus {
            return status
        }
        if let rhr = viewModel.displayedSummary.restingHeartRate {
            return rhr < 60 ? "Sedikit rendah" : (rhr > 85 ? "Sedikit tinggi" : "Dalam rentang normal")
        }
        return "Belum ada data"
    }

    private var heartRateBarHeights: [CGFloat] {
        if let points = viewModel.currentHealthRecord?.recentHeartRatePoints, !points.isEmpty {
            let maxVal = points.max() ?? 100
            return points.suffix(6).map { CGFloat($0 / maxVal) }
        }
        let historyPoints = viewModel.historicalSummaries.compactMap(\.restingHeartRate)
        if !historyPoints.isEmpty {
            let maxVal = historyPoints.max() ?? 100
            return historyPoints.suffix(6).map { CGFloat($0 / maxVal) }
        }
        return []
    }

    private var sleepValue: String {
        if let f = viewModel.currentHealthRecord?.sleepFormatted, f != "-" {
            return f
        }
        if let hours = viewModel.displayedSummary.sleepHours {
            let h = Int(hours)
            let m = Int((hours - Double(h)) * 60)
            return "\(h)j \(m)m"
        }
        return "-"
    }

    private var sleepStatusText: String {
        if let status = viewModel.currentHealthRecord?.sleepStatus {
            return status
        }
        if let hours = viewModel.displayedSummary.sleepHours {
            return hours >= 7.0 ? "Kualitas tidur baik" : "Perlu istirahat lebih"
        }
        return "Belum ada data"
    }

    private var sleepBarHeights: [CGFloat] {
        if let points = viewModel.currentHealthRecord?.recentSleepPoints, !points.isEmpty {
            let maxVal = points.max() ?? 10
            return points.suffix(6).map { CGFloat($0 / maxVal) }
        }
        let historyPoints = viewModel.historicalSummaries.compactMap(\.sleepHours)
        if !historyPoints.isEmpty {
            let maxVal = historyPoints.max() ?? 10
            return historyPoints.suffix(6).map { CGFloat($0 / maxVal) }
        }
        return []
    }

    private var stepsValue: String {
        if let s = viewModel.currentHealthRecord?.stepFormatted, s != "-" {
            return s
        }
        if let st = viewModel.displayedSummary.stepCount {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = "."
            return formatter.string(from: NSNumber(value: Int(st))) ?? "\(Int(st))"
        }
        return "-"
    }

    private var activityStatusText: String {
        if let status = viewModel.currentHealthRecord?.activityStatus {
            return status
        }
        if let st = viewModel.displayedSummary.stepCount {
            return st >= 4000 ? "Lebih baik dari biasanya" : "Cenderung santai hari ini"
        }
        return "Belum ada data"
    }

    private var stepsBarHeights: [CGFloat] {
        if let points = viewModel.currentHealthRecord?.recentStepPoints, !points.isEmpty {
            let maxVal = points.max() ?? 10000
            return points.suffix(6).map { CGFloat($0 / maxVal) }
        }
        let historyPoints = viewModel.historicalSummaries.compactMap(\.stepCount)
        if !historyPoints.isEmpty {
            let maxVal = historyPoints.max() ?? 10000
            return historyPoints.suffix(6).map { CGFloat($0 / maxVal) }
        }
        return []
    }

    // MARK: - Parent Account Selection Sheet (Screenshot)

    private var parentSelectSheet: some View {
        VStack(spacing: 20) {
            Text("Orang Tua")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.top, 16)

            VStack(spacing: 0) {
                ForEach(0..<viewModel.availableParents.count, id: \.self) { index in
                    let name = viewModel.availableParents[index]
                    let isSelected = viewModel.selectedParentIndex == index

                    Button {
                        viewModel.selectedParentIndex = index
                        showParentSelectSheet = false
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundStyle(isSelected ? Color.blue : Color.secondary.opacity(0.35))

                            Text(name)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(.primary)

                            Spacer()
                        }
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)

                    Divider()
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .presentationDetents([.fraction(0.32), .medium])
        .presentationDragIndicator(.visible)
    }
}

#Preview("Not Paired") {
    DashboardView()
}

#Preview("Paired") {
    let vm = DashboardViewModel()
    vm.syncViewModel.syncState.status = .accepted
    vm.syncViewModel.healthRecord = HealthRecord.previewMock
    return DashboardView(viewModel: vm)
}

