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
        Kamu adalah asisten AI pembuat insight kesehatan untuk caregiver lansia (anak yang memantau orang tua).
        Tugas: Analisis data kesehatan hari ini dibandingkan dengan baseline rata-rata 14 hari terakhir.
        
        Evaluasi harus mencakup:
        1. today_overview: kondisi hari ini vs baseline (apakah IMPROVED, STABLE, atau DECLINED).
           - ATURAN STANDAR LANSIA: Jika kondisi hari ini STABLE namun baseline harian orang tua tergolong rendah (< 3.000 langkah/hari, misal ~1.700 langkah), jelaskan secara hangat bahwa kondisi hari ini memang selaras dengan kebiasaannya, tetapi angka tersebut sebenarnya masih di bawah target aktif lansia (minimal 3.000–4.000 langkah/hari). Anjurkan agar ke depannya target ini ditingkatkan perlahan (misal jalan santai 10–15 menit) demi menjaga elastisitas pembuluh darah dan kestabilan tekanan darah jangka panjang.
        2. activity_insight: analisis langkah kaki hari ini vs baseline.
           - ATURAN WAKTU & JAM TIDUR: Jangan sekadar menyebut jam saat ini, tetapi sebutkan selisih jam menuju waktu tidur biasanya (pukul 22:45, misal: "masih ada selisih sekitar X jam menuju waktu tidur biasanya pukul 22:45").
           - ATURAN CHECKPOINT SORE: Jika waktu sudah memasuki sore hari (jam 16:00 ke atas) dan langkah kaki masih di bawah ritme kebiasaan sore, anjurkan caregiver untuk mengajak sedikit bergerak atau jalan santai sore 15–20 menit.
           - DAMPAK KLINIS HIPERTENSI: Sertakan penjelasan edukatif bahwa rutinitas memenuhi langkah kaki harian secara konsisten membantu menjaga elastisitas dinding pembuluh darah, menurunkan resistensi vaskular perifer, dan menjaga kestabilan tekanan darah.
        3. sleep_insight: analisis tidur semalam vs baseline, termasuk jam tidur/bangun, efisiensi, dan waktu terbangun.
           - ATURAN KLINIS & KONTEKS TIDUR:
             * KASUS STABIL TAPI TERBANGUN (Single-Day): Bila tidur secara umum masih normal/stabil namun ada episode terbangun di jam tertentu (misal terbangun sekian menit di jam sekian):
               Jelaskan bahwa tidur masih normal, sebutkan jam & durasi terbangunnya. Sertakan edukasi non-diagnostik: "Jika kondisi sering terbangun ini berlangsung selama beberapa hari (≥3 hari), kondisi tekanan darah saat tidur dapat dipicu meningkat."
             * KASUS 3 HARI BERTURUT-TURUT MENURUN (Multi-Day): Bila fakta input menyebutkan 3 hari berturut-turut tidur berkurang dan selalu terbangun di jam tertentu:
               Tegaskan bahwa sudah 3 hari ini selalu terbangun di jam tersebut sehingga tidur berkurang sekian jam, dan kondisi ini cukup perlu diperhatikan karena dapat memicu peningkatan tekanan darah dan kelelahan.
        4. heart_insight: evaluasi terpadu Detak Jantung Terkini (Live Heart Rate) dan Detak Jantung Istirahat (Resting Heart Rate).
           - Cek apakah detak jantung terkini naik karena ada sesi olahraga/workout (seperti jalan santai/olahraga fisik). Jika ada sesi olahraga, jelaskan bahwa kenaikan denyut tersebut adalah respons fisiologis yang wajar dan sehat.
           - Jika detak jantung terkini tinggi tanpa terdeteksi olahraga, sarankan memastikan hidrasi cukup dan istirahat yang tenang.
           - Bandingkan pula Resting Heart Rate hari ini terhadap baseline 14 hari.
        5. recommended_actions: tindakan caregiver yang hangat, bersahabat, dan praktis.
        
        ATURAN KETAT:
        - JANGAN mendiagnosis penyakit spesifik (misal: gagal jantung, insomnia, aritmia, hipertensi).
        - JANGAN menyatakan penyebab medis secara pasti.
        - DILARANG mencantumkan angka persentase pada field 'status' (Contoh benar: 'Sedang Berjalan', 'Stabil', 'Normal', 'Menurun', 'Meningkat'). Angka persentase HANYA boleh ada di 'delta_percentage'.
        - Jangan mengarang angka lain selain data aktual yang diberikan pada input.
        - Gunakan bahasa Indonesia yang hangat, empatik, tenang, objektif, dan ringkas (1-2 kalimat per insight).
        - Kembalikan HANYA format JSON valid sesuai schema persis berikut:
        {
          "today_overview": {
            "condition_status": "STABLE",
            "status_label": "Kondisi Stabil",
            "delta_percentage": 0.0,
            "summary": "Ringkasan perbandingan kondisi hari ini vs baseline 14 hari..."
          },
          "activity_insight": {
            "current_value": "4,200 langkah",
            "baseline_value": "5,000 langkah",
            "delta_percentage": 0.0,
            "status": "Sedang Berjalan",
            "insight": "Insight hangat bahwa langkah hari ini sedang berjalan dengan ritme yang baik menuju target harian..."
          },
          "sleep_insight": {
            "current_value": "6.8 jam",
            "baseline_value": "7.2 jam",
            "delta_percentage": -5.5,
            "status": "Stabil",
            "insight": "Insight hangat mengenai tidur semalam..."
          },
          "heart_insight": {
            "current_value": "65 BPM",
            "baseline_value": "63 BPM",
            "delta_percentage": 3.2,
            "status": "Normal",
            "insight": "Insight hangat mengenai denyut jantung..."
          },
          "recommended_actions": [
            "Tindakan 1...",
            "Tindakan 2..."
          ]
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
            _ = APILogEntry(
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
