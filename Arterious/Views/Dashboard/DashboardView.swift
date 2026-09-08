import SwiftUI

struct DashboardView: View {

    @Bindable var viewModel: DashboardViewModel

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
        }
    }

    // MARK: - Paired Content (Screenshot 2)

    @ViewBuilder
    private var pairedContentView: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Parent Name Dropdown Header
            HStack(spacing: 6) {
                Text(viewModel.displayedParentName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)

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

    private var summaryTitle: String {
        viewModel.currentHealthRecord?.summaryTitle ?? "Kondisi cukup stabil"
    }

    private var summaryBody: String {
        viewModel.currentHealthRecord?.summaryBody ?? "Pola tidur baik, detak jantung dalam rentang normal, dan aktivitas sedikit lebih baik dari biasanya."
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
        return "72"
    }

    private var heartRateStatusText: String {
        viewModel.currentHealthRecord?.heartRateStatus ?? "Dalam rentang normal"
    }

    private var heartRateBarHeights: [CGFloat] {
        if let points = viewModel.currentHealthRecord?.recentHeartRatePoints, !points.isEmpty {
            let maxVal = points.max() ?? 100
            return points.suffix(6).map { CGFloat($0 / maxVal) }
        }
        return [0.4, 0.6, 0.5, 0.8, 0.7, 0.9]
    }

    private var sleepValue: String {
        if let f = viewModel.currentHealthRecord?.sleepFormatted {
            return f
        }
        if let hours = viewModel.displayedSummary.sleepHours {
            let h = Int(hours)
            let m = Int((hours - Double(h)) * 60)
            return "\(h)j \(m)m"
        }
        return "7j 40m"
    }

    private var sleepStatusText: String {
        viewModel.currentHealthRecord?.sleepStatus ?? "Kualitas tidur baik"
    }

    private var sleepBarHeights: [CGFloat] {
        if let points = viewModel.currentHealthRecord?.recentSleepPoints, !points.isEmpty {
            let maxVal = points.max() ?? 10
            return points.suffix(6).map { CGFloat($0 / maxVal) }
        }
        return [0.5, 0.7, 0.6, 0.85, 0.9]
    }

    private var stepsValue: String {
        if let s = viewModel.currentHealthRecord?.stepFormatted {
            return s
        }
        if let st = viewModel.displayedSummary.stepCount {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = "."
            return formatter.string(from: NSNumber(value: Int(st))) ?? "\(Int(st))"
        }
        return "4.280"
    }

    private var activityStatusText: String {
        viewModel.currentHealthRecord?.activityStatus ?? "Lebih baik dari biasanya"
    }

    private var stepsBarHeights: [CGFloat] {
        if let points = viewModel.currentHealthRecord?.recentStepPoints, !points.isEmpty {
            let maxVal = points.max() ?? 10000
            return points.suffix(6).map { CGFloat($0 / maxVal) }
        }
        return [0.3, 0.5, 0.7, 0.85, 0.95]
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

