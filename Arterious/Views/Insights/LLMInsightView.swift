//
//  LLMInsightView.swift
//  Arterious
//
//  Tampilan Caregiver Insight berbasis perbandingan hari ini vs baseline 14 hari:
//  - Today's Overview (Status umum: Membaik / Kondisi Stabil / Penurunan X%)
//  - Section Activity (Angka langkah hari ini, baseline, delta %, dan insight AI)
//  - Section Sleep (Angka durasi tidur hari ini, baseline, delta %, dan insight AI)
//  - Section Heart (Angka resting HR hari ini, baseline, delta %, dan insight AI)
//  - Rekomendasi Tindakan Caregiver
//

import SwiftUI

struct LLMInsightView: View {
    @Environment(SyncViewModel.self) private var syncViewModel
    @State private var localViewModel = LLMInsightViewModel(autoFetch: false)
    
    private var isChild: Bool {
        syncViewModel.syncState.role == .child
    }
    
    private var activeOutput: LLMInsightOutput? {
        if isChild {
            return syncViewModel.insightOutput ?? syncViewModel.fallbackInsightFromCurrentRecord
        }
        return syncViewModel.insightOutput ?? localViewModel.insightOutput
    }
    
    private var isFallback: Bool {
        if isChild {
            return syncViewModel.isUsingLocalRuleFallback
        }
        return syncViewModel.insightOutput != nil ? syncViewModel.isUsingLocalRuleFallback : localViewModel.isUsingLocalRuleFallback
    }
    
    private var parentDisplayName: String {
        let name = syncViewModel.parentName
        return (name.isEmpty || name == "Nama Ortu 1" || name == "Saya") ? "Ibu" : name
    }
    
    private var isCurrentlyLoading: Bool {
        if isChild {
            return syncViewModel.isLoading && activeOutput == nil
        }
        return (localViewModel.isLoading || syncViewModel.isLoading) && activeOutput == nil
    }
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    if let output = activeOutput {
                        // Banner Indikator Sumber Analisis (Aturan Lokal vs AI)
                        if isFallback {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.footnote.weight(.semibold))
                                Text("Analisis Berdasarkan Aturan Klinis Lokal (Rule-Based)")
                                    .font(.footnote.weight(.medium))
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(.teal)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.teal.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        
                        todayOverviewCard(output.todayOverview)
                        activitySection(output.activityInsight)
                        sleepSection(output.sleepInsight)
                        heartSection(output.heartInsight)
                        recommendedActionsSection(output.recommendedActions)
                        
                        // Disclaimer Pembanding Personal (Non-Medis)
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text("Pola 14 hari terakhir digunakan sebagai pembanding personal, bukan target medis.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 4)
                        .padding(.top, 4)
                    } else if isCurrentlyLoading {
                        loadingCard
                    } else {
                        loadingCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
                .containerRelativeFrame(.horizontal) { width, _ in width }
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        }
        .navigationTitle("Insight Kesehatan \(parentDisplayName)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isChild ? syncViewModel.isLoading : (localViewModel.isLoading || syncViewModel.isLoading) {
                    ProgressView()
                } else {
                    Button {
                        Task {
                            if isChild {
                                await syncViewModel.fetchSharedParentSnapshot()
                            } else {
                                await syncViewModel.loadParentLocalHealthData(forceGemini: true)
                                await localViewModel.loadAndGenerateInsight(forceRefresh: true)
                            }
                        }
                    } label: {
                        Image(systemName: isFallback ? "arrow.clockwise" : "sparkles")
                            .font(.headline)
                            .foregroundStyle(isFallback ? .teal : AppColor.actionBlue)
                    }
                }
            }
        }
        .refreshable {
            if isChild {
                await syncViewModel.fetchSharedParentSnapshot()
            } else {
                await syncViewModel.loadParentLocalHealthData(forceGemini: false)
                await localViewModel.loadAndGenerateInsight(forceRefresh: false)
            }
        }
        .task {
            if isChild {
                if syncViewModel.insightOutput == nil {
                    await syncViewModel.fetchSharedParentSnapshot()
                }
            } else {
                if syncViewModel.insightOutput == nil && localViewModel.insightOutput == nil {
                    await localViewModel.loadAndGenerateInsight()
                }
            }
        }
    }
    
    // MARK: - 1. Today's Overview Card
    
    private func todayOverviewCard(_ overview: TodayOverviewInsight) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                Text("TODAY'S OVERVIEW")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                    .lineLimit(1)
                
                Spacer(minLength: 4)
            }
            
            Text(overviewHeadline(overview.conditionStatus))
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: isFallback ? "doc.text.magnifyingglass" : "sparkles")
                    .font(.subheadline)
                    .foregroundStyle(isFallback ? .teal : AppColor.actionBlue)
                    .padding(.top, 2)
                
                Text(overview.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - 2. Activity Section
    
    // MARK: - 2. Activity Section
    
    private func activitySection(_ insight: DomainMetricInsight) -> some View {
        let baselineText = insight.baselineValue.contains("/hari") ? insight.baselineValue : "\(insight.baselineValue)/hari"
        
        return domainCard(
            title: "Aktivitas Fisik",
            systemImage: "figure.walk",
            iconColor: .green,
            metricInsight: insight,
            baselineLabel: "Pola 14 hari terakhir",
            baselineValueFormatted: baselineText
        )
    }
    
    // MARK: - 3. Sleep Section
    
    private func sleepSection(_ insight: DomainMetricInsight) -> some View {
        let baselineText = insight.baselineValue.contains("/malam") ? insight.baselineValue : "\(insight.baselineValue)/malam"
        
        return domainCard(
            title: "Tidur Semalam",
            systemImage: "bed.double.fill",
            iconColor: .indigo,
            metricInsight: insight,
            baselineLabel: "Pola 14 malam terakhir",
            baselineValueFormatted: baselineText
        )
    }
    
    // MARK: - 4. Heart Section (Denyut Saat Istirahat)
    
    private func heartSection(_ insight: DomainMetricInsight) -> some View {
        let baselineText = insight.baselineValue.contains("bpm") || insight.baselineValue.contains("BPM") ? insight.baselineValue.lowercased() : "\(insight.baselineValue) bpm"
        let currentText = insight.currentValue.contains("bpm") || insight.currentValue.contains("BPM") ? insight.currentValue.lowercased() : "\(insight.currentValue) bpm"
        
        return domainCard(
            title: "Denyut Saat Istirahat",
            systemImage: "waveform.path.ecg",
            iconColor: .red,
            metricInsight: insight,
            currentValueFormatted: currentText,
            baselineLabel: "Pola 14 hari terakhir",
            baselineValueFormatted: baselineText
        )
    }
    
    // MARK: - Reusable Domain Metric Card
    
    private func domainCard(
        title: String,
        systemImage: String,
        iconColor: Color,
        metricInsight: DomainMetricInsight,
        currentValueFormatted: String? = nil,
        baselineLabel: String,
        baselineValueFormatted: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Bar
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 28, height: 28)
                    .background(iconColor.opacity(0.12))
                    .clipShape(Circle())
                
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Spacer()
            }
            
            // Numbers Comparison Row (Clean & Non-Technical Table/Box)
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hari ini")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(currentValueFormatted ?? metricInsight.currentValue)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                    .frame(height: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(baselineLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(baselineValueFormatted)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            
            // Insight Text (AI vs Rule Engine) - Multi-Sparkles!
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(metricInsight.allInsights.enumerated()), id: \.offset) { _, point in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: isFallback ? "doc.text.magnifyingglass" : "sparkles")
                            .font(.caption)
                            .foregroundStyle(isFallback ? .teal : AppColor.actionBlue)
                            .padding(.top, 2)
                        
                        Text(point)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - 5. Recommended Actions Section
    
    private func recommendedActionsSection(_ actions: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: isFallback ? "list.bullet.clipboard" : "sparkles")
                    .foregroundStyle(isFallback ? .teal : AppColor.actionBlue)
                Text(isFallback ? "Rekomendasi Tindakan (Rule-Based)" : "Rekomendasi Tindakan Caregiver")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                ForEach(actions, id: \.self) { action in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                            .padding(.top, 2)
                        
                        Text(action)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - Loading Card
    
    private var loadingCard: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Mengevaluasi baseline 14 hari & insight...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - UI Helpers
    
    private func overviewHeadline(_ status: String) -> String {
        RuleEngine.overviewHeadline(for: status)
    }
}

#Preview {
    LLMInsightView()
        .environment(SyncViewModel())
}
