//
//  LLMInsightViewModel.swift
//  Arterious
//
//  ViewModel untuk mengelola flow integrasi LLM (Gemini):
//  Memuat dummy data scenario, mengirim prompt ke Gemini API,
//  dan menyajikan hasil insight serta log jaringan secara reaktif.
//

import Foundation
import Observation

@Observable
@MainActor
final class LLMInsightViewModel {
    
    // MARK: - State
    
    /// Input terstruktur yang dirakit dari dummy health records & rule engine
    var promptInput: LLMInsightInput?
    
    /// Hasil insight yang dihasilkan oleh Gemini API
    var insightOutput: LLMInsightOutput?
    
    /// Daftar log pemanggilan API untuk transparansi audit
    var apiLogs: [APILogEntry] = []
    
    /// Model Gemini yang dipilih untuk generate insight
    var selectedModel: GeminiModel = APIConfig.activeModel
    
    /// Status pemanggilan API
    var isLoading: Bool = false
    
    /// Pesan error jika terjadi kegagalan
    var errorMessage: String?
    
    // MARK: - Dependencies
    
    private let geminiService: GeminiService
    
    // MARK: - Initialization
    
    init(geminiService: GeminiService? = nil) {
        self.geminiService = geminiService ?? GeminiService.shared
        loadDummyScenario()
    }
    
    // MARK: - Actions
    
    /// Muat data skenario awal dari JSON / rule engine
    func loadDummyScenario() {
        // Coba assemble secara dinamis dari rule yang HIT, fallback ke prompt.json
        if let assembled = MockDataLoader.assemblePromptFromHitRules() {
            self.promptInput = assembled
        } else {
            self.promptInput = MockDataLoader.loadPrompt()
        }
    }
    
    /// Eksekusi pemanggilan Gemini API menggunakan prompt input saat ini
    func generateInsight() async {
        guard let input = promptInput else {
            self.errorMessage = "Data prompt belum dimuat."
            return
        }
        
        guard APIConfig.isConfigured else {
            self.errorMessage = "API Key belum terpasang di .env (GEMINI_API_KEY). Pastikan Configuration/.env sudah terisi."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let (output, log) = try await geminiService.generateInsight(
                input: input,
                model: selectedModel
            )
            self.insightOutput = output
            self.apiLogs.insert(log, at: 0) // Simpan log paling baru di atas
        } catch {
            self.errorMessage = error.localizedDescription
            let failedLog = APILogEntry(
                timestamp: Date(),
                model: selectedModel.rawValue,
                endpointMasked: "\(APIConfig.baseURL)/models/\(selectedModel.rawValue)...",
                httpStatus: nil,
                durationMs: 0,
                requestPayload: "Error during request",
                responsePayload: nil,
                errorMessage: error.localizedDescription,
                isSuccess: false
            )
            self.apiLogs.insert(failedLog, at: 0)
        }
        
        isLoading = false
    }
    
    /// Bersihkan riwayat log
    func clearLogs() {
        apiLogs.removeAll()
    }
}
