import SwiftUI

struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Status Summary
                    wellnessHeader
                    
                    // Early Caution Card (Appears on significant deviations)
                    if let caution = viewModel.cautionInsight {
                        CautionCardView(insight: caution) {
                            // Action: trigger phone call or quick message
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // Today's Health Metric Grid
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Today's Overview")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            MetricCardView(
                                metric: .steps,
                                value: viewModel.todaySummary.stepCount,
                                baselineValue: viewModel.baselineSteps()
                            )
                            
                            MetricCardView(
                                metric: .restingHeartRate,
                                value: viewModel.todaySummary.restingHeartRate,
                                baselineValue: viewModel.baselineRestingHeartRate()
                            )
                            
                            MetricCardView(
                                metric: .sleep,
                                value: viewModel.todaySummary.sleepHours,
                                baselineValue: viewModel.baselineSleep()
                            )
                            
                            MetricCardView(
                                metric: .heartRate,
                                value: viewModel.todaySummary.latestHeartRate,
                                baselineValue: nil
                            )
                        }
                    }
                    
                    // Gentle Medical Disclaimer (HealthKit Guideline Requirement)
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
    
    private var wellnessHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
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
            
            Text(Date.now.formatted(date: .abbreviated, time: .omitted))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemFill))
                .clipShape(Capsule())
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
