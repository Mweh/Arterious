//
//  LLMInsightView.swift
//  Arterious
//
//  Tampilan sederhana menggunakan Native SwiftUI Components untuk:
//  1. Melihat data dummy & rule yang HIT
//  2. Memanggil Gemini API secara langsung
//  3. Menampilkan hasil insight yang terstruktur
//  4. Menyajikan live log jaringan (bukti hit API)
//

import SwiftUI

struct LLMInsightView: View {
    @State private var viewModel = LLMInsightViewModel()
    
    var body: some View {
        NavigationStack {
            List {
                controlSection
                resultSection
                dummyDataSection
                auditLogSection
            }
            .navigationTitle("AI Caregiver Insight")
            .refreshable {
                viewModel.loadDummyScenario()
            }
        }
    }
    
    // MARK: - Subviews
    
    // 1. Kontrol API Gemini
    private var controlSection: some View {
        Section {
            Picker("Model Gemini", selection: $viewModel.selectedModel) {
                ForEach(GeminiModel.allCases) { model in
                    Text(model.displayName).tag(model)
                }
            }
            
            LabeledContent("Status API Key") {
                if APIConfig.isConfigured {
                    Label("Terkonfigurasi (.env)", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.caption.bold())
                } else {
                    Label("Belum di-set di .env", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption.bold())
                }
            }
            
            Button {
                Task {
                    await viewModel.generateInsight()
                }
            } label: {
                HStack {
                    Spacer()
                    if viewModel.isLoading {
                        ProgressView()
                            .padding(.trailing, 8)
                        Text("Menghubungi Gemini API...")
                            .fontWeight(.semibold)
                    } else {
                        Image(systemName: "sparkles")
                        Text("Generate Insight via Gemini")
                            .fontWeight(.semibold)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(viewModel.isLoading || !APIConfig.isConfigured)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        } header: {
            Text("Kontrol API Gemini")
        } footer: {
            if let err = viewModel.errorMessage {
                Text(err)
                    .foregroundStyle(.red)
            }
        }
    }
    
    // 2. Hasil Insight Gemini
    private var resultSection: some View {
        Section {
            if let output = viewModel.insightOutput {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(output.urgency)
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(urgencyColor(output.urgency))
                            .clipShape(Capsule())
                        
                        Spacer()
                        
                        Text("Gemini Response")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(output.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(output.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                    
                    Divider()
                    
                    Text("Tindakan yang Disarankan:")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    ForEach(output.recommendedActions, id: \.self) { action in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.red)
                                .font(.caption)
                                .padding(.top, 2)
                            Text(action)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .padding(.vertical, 4)
            } else {
                ContentUnavailableView {
                    Label("Belum Ada Insight", systemImage: "sparkles.rectangle.stack")
                } description: {
                    Text("Tekan tombol di atas untuk mengirim data dummy ke Gemini API dan melihat hasilnya.")
                }
                .listRowBackground(Color.clear)
            }
        } header: {
            Text("Hasil Caregiver Insight")
        }
    }
    
    // 3. Ringkasan Data Dummy & Hit Rules
    private var dummyDataSection: some View {
        Section {
            if let input = viewModel.promptInput {
                LabeledContent("Subjek Pantauan", value: input.parentDisplayName)
                LabeledContent("Status Evaluasi", value: input.overallStatus)
                LabeledContent("Concern State", value: input.concernState)
                LabeledContent("Periode Data", value: input.reportPeriod)
                
                if let rules = input.triggeredRulesSummary, !rules.isEmpty {
                    DisclosureGroup("Rule yang Terpenuhi (HIT) (\(rules.count))") {
                        ForEach(rules, id: \.self) { ruleStr in
                            Text("• \(ruleStr)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                DisclosureGroup("Fakta Terukur dari Data (\(input.facts.count))") {
                    ForEach(input.facts, id: \.self) { fact in
                        Text("• \(fact)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Ringkasan Data Dummy (Input)")
        }
    }
    
    // 4. API Audit Log
    private var auditLogSection: some View {
        Section {
            if viewModel.apiLogs.isEmpty {
                Text("Belum ada request yang dikirim.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.apiLogs, id: \.id) { log in
                    logRow(log)
                }
            }
        } header: {
            HStack {
                Text("API Call Audit Log")
                Spacer()
                if !viewModel.apiLogs.isEmpty {
                    Button("Clear") {
                        viewModel.clearLogs()
                    }
                    .font(.caption)
                }
            }
        } footer: {
            Text("Menampilkan status HTTP, waktu respons, dan payload langsung dari Google AI Studio endpoint.")
        }
    }
    
    private func logRow(_ log: APILogEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(log.isSuccess ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(log.statusText)
                        .font(.caption.bold())
                        .foregroundStyle(log.isSuccess ? .green : .red)
                }
                
                Spacer()
                
                Text("\(log.durationMs) ms")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                
                Text(log.timestamp.formatted(date: .omitted, time: .standard))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Text(log.endpointMasked)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
            
            DisclosureGroup("Lihat Request & Response Payload") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Request Body:")
                        .font(.caption2.bold())
                    ScrollView(.horizontal) {
                        Text(log.requestPayload)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                    
                    Text("Response Body:")
                        .font(.caption2.bold())
                    ScrollView(.horizontal) {
                        Text(log.displayResponse)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(log.isSuccess ? Color.secondary : Color.red)
                    }
                }
                .padding(.top, 4)
            }
            .font(.caption2)
        }
        .padding(.vertical, 4)
    }
    
    private func urgencyColor(_ urgency: String) -> Color {
        switch urgency.uppercased() {
        case "CAUTION": return .orange
        case "WARNING": return .red
        case "URGENT": return .purple
        default: return .blue
        }
    }
}

#Preview {
    LLMInsightView()
}
