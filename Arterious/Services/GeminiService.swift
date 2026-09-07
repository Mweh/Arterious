//
//  GeminiService.swift
//  Arterious
//
//  Service untuk memanggil Google Generative Language API (Gemini).
//  Mendukung structured JSON output dan audit logging lengkap.
//

import Foundation

// MARK: - API Audit Log Model

/// Catatan log setiap pemanggilan API Gemini untuk transparansi
struct APILogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let model: String
    let endpointMasked: String
    let httpStatus: Int?
    let durationMs: Int
    let requestPayload: String
    let responsePayload: String?
    let errorMessage: String?
    let isSuccess: Bool
    
    var statusText: String {
        if let code = httpStatus {
            return "\(code) \(code == 200 ? "OK" : "Error")"
        }
        return errorMessage != nil ? "Failed" : "Pending"
    }
    
    var displayResponse: String {
        responsePayload ?? errorMessage ?? "No payload"
    }
}

// MARK: - Gemini API Request & Response Schemas

private struct GeminiRequestBody: Encodable {
    struct Content: Encodable {
        struct Part: Encodable {
            let text: String
        }
        let parts: [Part]
    }
    struct GenerationConfig: Encodable {
        let responseMimeType: String
        let temperature: Double
    }
    
    let contents: [Content]
    let generationConfig: GenerationConfig
}

private struct GeminiResponseBody: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable {
                let text: String
            }
            let parts: [Part]
        }
        let content: Content
    }
    let candidates: [Candidate]?
}

// MARK: - Gemini Service Error

enum GeminiServiceError: LocalizedError {
    case apiKeyMissing
    case invalidURL
    case networkError(String)
    case httpError(statusCode: Int, message: String)
    case emptyResponse
    case jsonDecodingError(String)
    
    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "API Key Gemini belum diatur di .env (GEMINI_API_KEY)."
        case .invalidURL:
            return "URL endpoint Gemini tidak valid."
        case .networkError(let msg):
            return "Koneksi jaringan gagal: \(msg)"
        case .httpError(let code, let msg):
            return "Gemini API HTTP Error \(code): \(msg)"
        case .emptyResponse:
            return "Gemini tidak mengembalikan teks jawaban (empty response)."
        case .jsonDecodingError(let msg):
            return "Gagal mem-parsing output JSON dari Gemini: \(msg)"
        }
    }
}

// MARK: - Gemini Service

final class GeminiService: Sendable {
    
    static let shared = GeminiService()
    
    private init() {}
    
    /// Mengirim structured prompt ke Gemini API dan mengembalikan LLMInsightOutput
    func generateInsight(
        input: LLMInsightInput,
        model: GeminiModel? = nil
    ) async throws -> (output: LLMInsightOutput, log: APILogEntry) {
        
        let targetModel = model ?? APIConfig.activeModel
        let apiKey = APIConfig.apiKey
        guard !apiKey.isEmpty else {
            throw GeminiServiceError.apiKeyMissing
        }
        
        guard let url = APIConfig.endpointURL(for: targetModel) else {
            throw GeminiServiceError.invalidURL
        }
        
        let endpointMasked = "\(APIConfig.baseURL)/models/\(targetModel.rawValue):generateContent?key=\(apiKey.prefix(6))...\(apiKey.suffix(4))"
        let startTime = Date()
        
        // 1. Format System Instruction & Prompt Payload
        let promptJSON = try encodeInputJSON(input)
        let systemInstruction = """
        Kamu adalah sistem AI pembuat insight untuk caregiver lansia (anak yang merawat orang tua).
        Tugas: Analisis data facts dan triggered rules terukur, lalu berikan insight yang tenang, empatik, objektif, dan ringkas.
        
        ATURAN KETAT:
        1. JANGAN mendiagnosis penyakit spesifik (misal: gagal jantung, insomnia, aritmia).
        2. JANGAN menyatakan penyebab pasti.
        3. JANGAN menyarankan perubahan dosis atau jadwal obat.
        4. HANYA gunakan recommended_actions yang diizinkan dari input allowed_actions.
        5. Kembalikan HANYA JSON valid sesuai schema berikut:
        {
          "title": "string",
          "summary": "string (maksimal 4 kalimat)",
          "recommended_actions": ["string", "string"],
          "urgency": "CAUTION"
        }
        """
        
        let userPromptText = """
        \(systemInstruction)
        
        Berikut data input terstruktur:
        \(promptJSON)
        """
        
        let requestBody = GeminiRequestBody(
            contents: [
                .init(parts: [.init(text: userPromptText)])
            ],
            generationConfig: .init(
                responseMimeType: "application/json",
                temperature: 0.2
            )
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        request.timeoutInterval = 30
        
        // 2. Eksekusi Network Call
        var httpStatusCode: Int? = nil
        var rawResponseString: String? = nil
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)
            
            if let httpResponse = response as? HTTPURLResponse {
                httpStatusCode = httpResponse.statusCode
            }
            
            rawResponseString = String(data: data, encoding: .utf8)
            
            guard let statusCode = httpStatusCode, (200...299).contains(statusCode) else {
                let errMessage = rawResponseString ?? "Unknown server response"
                throw GeminiServiceError.httpError(statusCode: httpStatusCode ?? 500, message: errMessage)
            }
            
            // 3. Parse Gemini Outer Envelope
            let geminiResponse = try JSONDecoder().decode(GeminiResponseBody.self, from: data)
            guard let candidateText = geminiResponse.candidates?.first?.content.parts.first?.text,
                  !candidateText.isEmpty else {
                throw GeminiServiceError.emptyResponse
            }
            
            // 4. Parse Structured Output (LLMInsightOutput)
            guard let innerData = candidateText.data(using: .utf8) else {
                throw GeminiServiceError.jsonDecodingError("Invalid text encoding")
            }
            
            let insightOutput = try JSONDecoder().decode(LLMInsightOutput.self, from: innerData)
            
            let log = APILogEntry(
                timestamp: startTime,
                model: targetModel.rawValue,
                endpointMasked: endpointMasked,
                httpStatus: httpStatusCode,
                durationMs: durationMs,
                requestPayload: promptJSON,
                responsePayload: candidateText,
                errorMessage: nil,
                isSuccess: true
            )
            
            return (insightOutput, log)
            
        } catch let err as GeminiServiceError {
            throw err
        } catch {
            let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)
            let log = APILogEntry(
                timestamp: startTime,
                model: targetModel.rawValue,
                endpointMasked: endpointMasked,
                httpStatus: httpStatusCode,
                durationMs: durationMs,
                requestPayload: promptJSON,
                responsePayload: rawResponseString,
                errorMessage: error.localizedDescription,
                isSuccess: false
            )
            throw GeminiServiceError.networkError(error.localizedDescription)
        }
    }
    
    private func encodeInputJSON(_ input: LLMInsightInput) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(input)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
