import SwiftUI

struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()
    
    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Status & Authorization Summary
                    authorizationHeader
                    
                    // Early Caution Card
                    if let caution = viewModel.cautionInsight {
                        CautionCardView(insight: caution) { }
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // 1. Heart Rate & HRV Core Metrics
                    VStack(alignment: .leading, spacing: 12) {
                        Text("1. HRV & HR Core Metrics")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        LazyVGrid(columns: gridColumns, spacing: 12) {
                            MetricCardView(metric: .restingHeartRate, value: viewModel.todaySummary.restingHeartRate, baselineValue: viewModel.baselineRestingHeartRate())
                            MetricCardView(metric: .meanHeartRate24h, value: viewModel.todaySummary.meanHeartRate24h, baselineValue: nil)
                            MetricCardView(metric: .heartRateSD24h, value: viewModel.todaySummary.heartRateSD24h, baselineValue: nil)
                            MetricCardView(metric: .maxHeartRate24h, value: viewModel.todaySummary.maxHeartRate24h, baselineValue: nil)
                            MetricCardView(metric: .hrvSDNN14DayMean, value: viewModel.todaySummary.hrvSDNN14DayMean, baselineValue: nil)
                            MetricCardView(metric: .hrvRMSSD, value: viewModel.todaySummary.hrvRMSSD, baselineValue: nil)
                            MetricCardView(metric: .hrvDropFromBaseline, value: viewModel.todaySummary.hrvDropFromBaseline, baselineValue: nil)
                        }
                    }
                    
                    // 2. Sleep Analysis
                    VStack(alignment: .leading, spacing: 12) {
                        Text("2. Sleep (Analisis Tidur)")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        LazyVGrid(columns: gridColumns, spacing: 12) {
                            MetricCardView(metric: .sleep, value: viewModel.todaySummary.sleepHours, baselineValue: viewModel.baselineSleep())
                            MetricCardView(metric: .sleepEfficiency, value: viewModel.todaySummary.sleepEfficiency, baselineValue: nil)
                            MetricCardView(metric: .deepSleepPercentage, value: viewModel.todaySummary.deepSleepPercentage, baselineValue: nil)
                            MetricCardView(metric: .remSleepPercentage, value: viewModel.todaySummary.remSleepPercentage, baselineValue: nil)
                            MetricCardView(metric: .sleepConsistency, value: viewModel.todaySummary.sleepBedtimeSDMinutes, baselineValue: nil)
                        }
                    }
                    
                    // 3. Activity Metrics
                    VStack(alignment: .leading, spacing: 12) {
                        Text("3. Activity (Aktivitas Fisik)")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        LazyVGrid(columns: gridColumns, spacing: 12) {
                            MetricCardView(metric: .steps, value: viewModel.todaySummary.stepCount, baselineValue: viewModel.baselineSteps())
                            MetricCardView(metric: .activeMinutes, value: viewModel.todaySummary.activeMinutesToday, baselineValue: nil)
                            MetricCardView(metric: .exerciseMinutesWeek, value: viewModel.todaySummary.exerciseMinutesWeek, baselineValue: nil)
                            MetricCardView(metric: .activeEnergy, value: viewModel.todaySummary.activeEnergyKcalToday, baselineValue: nil)
                            MetricCardView(
                                metric: .standHours,
                                value: viewModel.todaySummary.standHoursToday != nil ? Double(viewModel.todaySummary.standHoursToday!) : nil,
                                baselineValue: nil
                            )
                        }
                    }
                    
                    // Medical Disclaimer
                    Text("Arterious reflects general wellness trends from Apple HealthKit and is not intended for medical diagnosis.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)
                        .padding(.horizontal, 24)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
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
    
    private var authorizationHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Current Status")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 8) {
                    Image(systemName: viewModel.wellnessStatus.iconName)
                        .foregroundStyle(statusColor)
                    
                    Text(viewModel.wellnessStatus.rawValue)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                }
            }
            
            Spacer()
            
            Button(action: {
                Task {
                    await viewModel.loadDashboardData()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.red)
                .clipShape(Capsule())
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    
    private var statusColor: Color {
        switch viewModel.wellnessStatus {
        case .good:
            return .green
        case .fair:
            return .blue
        case .needsAttention:
            return .orange
        }
    }
}

#Preview {
    DashboardView()
}
