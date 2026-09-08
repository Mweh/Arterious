import SwiftUI

struct DashboardView: View {

    @State private var viewModel = DashboardViewModel()

    private let gridColumns = [
        GridItem(.flexible(), spacing: AppSpacing.md),
        GridItem(.flexible(), spacing: AppSpacing.md)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {

                    statusHeader

                    if let caution = viewModel.cautionInsight {
                        CautionCardView(insight: caution) { }
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // 1. Heart Rate & HRV
                    metricSection(title: "Heart Rate & HRV") {
                        MetricCardView(metric: .restingHeartRate, value: viewModel.todaySummary.restingHeartRate, baselineValue: viewModel.baselineRestingHeartRate())
                        MetricCardView(metric: .meanHeartRate24h, value: viewModel.todaySummary.meanHeartRate24h, baselineValue: nil)
                        MetricCardView(metric: .heartRateSD24h, value: viewModel.todaySummary.heartRateSD24h, baselineValue: nil)
                        MetricCardView(metric: .maxHeartRate24h, value: viewModel.todaySummary.maxHeartRate24h, baselineValue: nil)
                        MetricCardView(metric: .hrvSDNN14DayMean, value: viewModel.todaySummary.hrvSDNN14DayMean, baselineValue: nil)
                        MetricCardView(metric: .hrvRMSSD, value: viewModel.todaySummary.hrvRMSSD, baselineValue: nil)
                        MetricCardView(metric: .hrvDropFromBaseline, value: viewModel.todaySummary.hrvDropFromBaseline, baselineValue: nil)
                    }

                    // 2. Sleep
                    metricSection(title: "Sleep") {
                        MetricCardView(metric: .sleep, value: viewModel.todaySummary.sleepHours, baselineValue: viewModel.baselineSleep())
                        MetricCardView(metric: .sleepEfficiency, value: viewModel.todaySummary.sleepEfficiency, baselineValue: nil)
                        MetricCardView(metric: .deepSleepPercentage, value: viewModel.todaySummary.deepSleepPercentage, baselineValue: nil)
                        MetricCardView(metric: .remSleepPercentage, value: viewModel.todaySummary.remSleepPercentage, baselineValue: nil)
                        MetricCardView(metric: .sleepConsistency, value: viewModel.todaySummary.sleepBedtimeSDMinutes, baselineValue: nil)
                    }

                    // 3. Activity
                    metricSection(title: "Activity") {
                        MetricCardView(metric: .steps, value: viewModel.todaySummary.stepCount, baselineValue: viewModel.baselineSteps())
                        MetricCardView(metric: .activeMinutes, value: viewModel.todaySummary.activeMinutesToday, baselineValue: nil)
                        MetricCardView(metric: .exerciseMinutesWeek, value: viewModel.todaySummary.exerciseMinutesWeek, baselineValue: nil)
                        MetricCardView(metric: .activeEnergy, value: viewModel.todaySummary.activeEnergyKcalToday, baselineValue: nil)
                        MetricCardView(
                            metric: .standHours,
                            value: viewModel.todaySummary.standHoursToday.map(Double.init),
                            baselineValue: nil
                        )
                    }

                    // Medical disclaimer
                    Text("Arterious reflects general wellness trends from Apple HealthKit and is not intended for medical diagnosis.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, AppSpacing.md)
                        .padding(.horizontal, AppSpacing.xxl)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xxl)
            }
            .background(AppColor.backgroundPrimary)
            .navigationTitle("\(viewModel.parentName)'s Wellness")
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
            .alert("Health Access", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Subviews

    private var statusHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Current Status")
                    .font(AppTypography.subheadline)
                    .foregroundStyle(AppColor.textSecondary)

                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: viewModel.wellnessStatus.iconName)
                        .foregroundStyle(statusColor)

                    Text(viewModel.wellnessStatus.rawValue)
                        .font(AppTypography.title)
                        .foregroundStyle(AppColor.textPrimary)
                }
            }

            Spacer()

            AppButton(title: "Refresh", icon: "arrow.clockwise", style: .secondary) {
                Task { await viewModel.loadDashboardData() }
            }
        }
        .padding(AppSpacing.lg)
        .background(AppColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous))
    }

    @ViewBuilder
    private func metricSection(title: String, @ViewBuilder cards: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(title: title)
            LazyVGrid(columns: gridColumns, spacing: AppSpacing.md) {
                cards()
            }
        }
    }

    private var statusColor: Color {
        switch viewModel.wellnessStatus {
        case .good:          return AppColor.healthy
        case .fair:          return AppColor.info
        case .needsAttention: return AppColor.caution
        }
    }
}

#Preview {
    DashboardView()
}
