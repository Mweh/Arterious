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
    @State private var localViewModel = LLMInsightViewModel()
    
    private var activeOutput: LLMInsightOutput? {
        syncViewModel.insightOutput ?? localViewModel.insightOutput
    }
    
    private var isFallback: Bool {
        syncViewModel.insightOutput != nil ? syncViewModel.isUsingLocalRuleFallback : localViewModel.isUsingLocalRuleFallback
    }
    
    private var parentDisplayName: String {
        let name = syncViewModel.parentName
        return (name.isEmpty || name == "Nama Ortu 1" || name == "Saya") ? "Ibu" : name
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let output = activeOutput {
                    // Banner Indikator Sumber Analisis (Aturan Lokal vs AI)
                    if isFallback {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.footnote.weight(.semibold))
                            Text("Analisis Berdasarkan Aturan Klinis Lokal (Rule-Based)")
                                .font(.footnote.weight(.medium))
                            Spacer()
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
                } else if localViewModel.isLoading || syncViewModel.isLoading {
                    loadingCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Insight Kesehatan \(parentDisplayName)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if localViewModel.isLoading || syncViewModel.isLoading {
                    ProgressView()
                } else {
                    Button {
                        Task {
                            await syncViewModel.loadParentLocalHealthData(forceGemini: true)
                            await localViewModel.loadAndGenerateInsight(forceRefresh: true)
                        }
                    } label: {
                        Image(systemName: isFallback ? "arrow.clockwise" : "sparkles")
                            .font(.headline)
                            .foregroundStyle(isFallback ? .teal : .purple)
                    }
                }
            }
        }
        .refreshable {
            await syncViewModel.loadParentLocalHealthData(forceGemini: true)
            await localViewModel.loadAndGenerateInsight(forceRefresh: true)
        }
    }
    
    // MARK: - 1. Today's Overview Card
    
    private func todayOverviewCard(_ overview: TodayOverviewInsight) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TODAY'S OVERVIEW")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                
                Spacer()
                
                statusBadgeView(status: overview.conditionStatus, label: overview.statusLabel)
            }
            
            Text(overviewHeadline(overview.conditionStatus))
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
            
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: isFallback ? "doc.text.magnifyingglass" : "sparkles")
                    .font(.subheadline)
                    .foregroundStyle(isFallback ? .teal : .purple)
                    .padding(.top, 2)
                
                Text(overview.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - 2. Activity Section
    
    private func activitySection(_ insight: DomainMetricInsight) -> some View {
        domainCard(
            title: "Aktivitas Fisik",
            systemImage: "figure.walk",
            iconColor: .orange,
            metricInsight: insight,
            metricUnit: ""
        )
    }
    
    // MARK: - 3. Sleep Section
    
    private func sleepSection(_ insight: DomainMetricInsight) -> some View {
        domainCard(
            title: "Tidur Semalam",
            systemImage: "bed.double.fill",
            iconColor: .indigo,
            metricInsight: insight,
            metricUnit: ""
        )
    }
    
    // MARK: - 4. Heart Section (Unified Single Heart Rate)
    
    private func heartSection(_ insight: DomainMetricInsight) -> some View {
        domainCard(
            title: "Kesehatan Jantung",
            systemImage: "waveform.path.ecg",
            iconColor: .red,
            metricInsight: insight,
            metricUnit: ""
        )
    }
    
    // MARK: - Reusable Domain Metric Card
    
    private func domainCard(
        title: String,
        systemImage: String,
        iconColor: Color,
        metricInsight: DomainMetricInsight,
        metricUnit: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
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
                
                Spacer()
                
                deltaBadge(metricInsight.deltaPercentage, status: metricInsight.status)
            }
            
            // Numbers Comparison Row
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hari Ini")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(metricInsight.currentValue)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                    .frame(height: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Baseline 14 Hari")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(metricInsight.baselineValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                    .frame(height: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Selisih")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(deltaText(metricInsight.deltaPercentage, status: metricInsight.status))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(deltaColor(metricInsight.deltaPercentage, status: metricInsight.status))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            
            // Insight Text (AI vs Rule Engine)
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: isFallback ? "doc.text.magnifyingglass" : "sparkles")
                    .font(.caption2)
                    .foregroundStyle(isFallback ? .teal : .purple)
                    .padding(.top, 2)
                
                Text(metricInsight.insight)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - 5. Recommended Actions Section
    
    private func recommendedActionsSection(_ actions: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: isFallback ? "list.bullet.clipboard" : "sparkles")
                    .foregroundStyle(isFallback ? .teal : .purple)
                Text(isFallback ? "Rekomendasi Tindakan (Rule-Based)" : "Rekomendasi Tindakan Caregiver")
                    .font(.headline)
                    .foregroundStyle(.primary)
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
    
    private func statusBadgeView(status: String, label: String) -> some View {
        let (bgColor, fgColor, icon) = statusAppearance(status)
        return HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(label)
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(fgColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(bgColor)
        .clipShape(Capsule())
    }
    
    private func statusAppearance(_ status: String) -> (bg: Color, fg: Color, icon: String) {
        switch status.uppercased() {
        case "IMPROVED":
            return (Color.green.opacity(0.15), Color.green, "arrow.up.right.circle.fill")
        case "DECLINED":
            return (Color.red.opacity(0.15), Color.red, "arrow.down.right.circle.fill")
        default:
            return (Color.blue.opacity(0.15), Color.blue, "checkmark.circle.fill")
        }
    }
    
    private func overviewHeadline(_ status: String) -> String {
        RuleEngine.overviewHeadline(for: status)
    }
    
    private func deltaBadge(_ delta: Double, status: String) -> some View {
        let displayStatus = cleanStatusText(status)
        let color = badgeColor(delta: delta, status: displayStatus)
        return Text(displayStatus)
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
    
    private func cleanStatusText(_ status: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "\\s*[-+]?\\d+([.,]\\d+)?%\\s*", options: .caseInsensitive) else {
            return status
        }
        let cleaned = regex.stringByReplacingMatches(in: status, range: NSRange(location: 0, length: status.utf16.count), withTemplate: "")
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func badgeColor(delta: Double, status: String) -> Color {
        let lower = status.lowercased()
        if lower.contains("belum") || lower.contains("tidak") {
            return .secondary
        }
        if lower.contains("sedang") || lower.contains("stabil") || lower.contains("normal") {
            return .blue
        }
        if lower.contains("menurun") {
            return .red
        }
        if lower.contains("meningkat") || lower.contains("rileks") {
            return .green
        }
        return deltaColor(delta, status: status)
    }
    
    private func deltaText(_ delta: Double, status: String) -> String {
        let lower = status.lowercased()
        if lower.contains("sedang") || lower.contains("berjalan") {
            return "On-Track"
        }
        if lower.contains("belum") {
            return "—"
        }
        let sign = delta > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", delta))%"
    }
    
    private func deltaColor(_ delta: Double, status: String = "") -> Color {
        let lower = status.lowercased()
        if lower.contains("belum") {
            return .secondary
        }
        if lower.contains("sedang") || lower.contains("berjalan") || lower.contains("stabil") || lower.contains("normal") {
            return .blue
        }
        if lower.contains("menurun") {
            return .red
        }
        if lower.contains("meningkat") || lower.contains("rileks") {
            return .green
        }
        if abs(delta) < 10.0 {
            return .blue
        } else if delta < 0 {
            return .red
        } else {
            return .green
        }
    }
}

#Preview {
    LLMInsightView()
}
