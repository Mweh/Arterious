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
        Kamu adalah asisten AI pembuat insight kesehatan untuk caregiver lansia (anak yang memantau orang tua) dari fakta yang sudah diproses oleh rule engine.
        Tugas: Analisis data kesehatan hari ini dibandingkan dengan baseline 14 hari secara empatik, objektif, dan tenang.
        
        ATURAN UTAMA (Sesuai PRD Push Notification & AI Insight):
        1. JANGAN mendiagnosis penyakit spesifik (misal: gagal jantung, insomnia, aritmia, hipertensi).
        2. JANGAN menyatakan penyebab medis secara pasti.
        3. JANGAN mengubah status urgency atau condition status yang sudah ditetapkan rule engine.
        4. JANGAN membuat angka atau fakta baru di luar input yang diberikan.
        5. JANGAN menjanjikan klaim kepastian individu seperti "menjaga elastisitas pembuluh darah, menurunkan resistensi vaskular perifer, dan menjaga kestabilan tekanan darah". Gunakan bahasa umum edukatif yang aman: "Aktivitas fisik rutin secara umum mendukung kebugaran tubuh, tetapi orang tua tidak perlu memaksakan diri. Pilih aktivitas ringan yang aman sesuai kemampuan."
        6. DILARANG MENGGUNAKAN ISTILAH TEKNIS ATAU MEDIS: JANGAN gunakan istilah asing/teknis seperti "Deep Sleep", "REM", "Core Sleep", "HRV", "bradikardia", atau "takikardia". Terjemahkan secara alami ke bahasa Indonesia sehari-hari yang hangat dan mudah dipahami:
           - "Deep Sleep" -> sebut sebagai "tidur nyenyak/lelap untuk pemulihan fisik"
           - "REM Sleep" -> sebut sebagai "tidur lelap untuk relaksasi pikiran"
           - "Core Sleep" -> sebut sebagai "tidur ringan yang nyaman"
           - "Awake Time" -> sebut sebagai "terbangun sejenak tengah malam"
           - "Resting Heart Rate" -> sebut sebagai "denyut saat istirahat santai"
        7. PRINSIP DUA PEMBANDING (DUAL COMPARISON - BASELINE PERSONAL VS STANDAR RUJUKAN JURNAL/MEDIS):
           Bandingkan data hari ini terhadap DUA acuan:
           a) Baseline Personal 14 Hari (kebiasaan unik orang tua, misal 1.800 langkah, 7 jam 42 menit tidur, 68 bpm denyut istirahat).
           b) Standar Klinis/Jurnal Medis (Rujukan Umum yang Sehat):
              - Langkah Harian Lansia: Target aktif minimal rujukan jurnal geriatri JAMA adalah ~3.000 langkah/hari. Jika baseline personal orang tua relatif rendah (misal 1.800 langkah), jelaskan bahwa aktivitas hari ini selaras dengan ritme kebiasaannya, namun secara umum rujukan jurnal menyarankan target aktif bertahap menuju 3.000 langkah/hari secara santai dan tanpa memaksakan diri.
              - Tidur Semalam: Standar tidur sehat konsensus medis adalah 7–8 jam/malam. Jika tidur semalam < 6 jam (misal 4 jam 30 menit), bandingkan dengan kebiasaan orang tua DAN tegaskan adanya defisit dari standar tidur sehat 7–8 jam.
              - Detak Jantung Santai: Rentang normal saat istirahat santai menurut American Heart Association (AHA) adalah 60–80 bpm. Bandingkan denyut hari ini dengan baseline personal orang tua dan rentang normal sehat ini.
        8. NADA REASSURING (MENCEGAH KECEMASAN ANAK):
           - Tujuan utama aplikasi adalah mendampingi anak menjaga orang tua dengan tenang tanpa rasa cemas atau panik berlebihan.
           - Jika ada perbedaan atau fluktuasi data yang masih terbilang wajar menurut rule engine (status STABLE atau delta wajar), WAJIB sertakan penenang: "namun perubahan ini masih terbilang wajar dan normal dalam keseharian orang tua".
           - Jika ada kondisi yang perlu perhatian (DECLINED), sampaikan secara bijak dan hangat tanpa kepanikan, fokus pada sapaan santai anak (misal: "Anak tidak perlu cemas berlebihan, cukup luangkan waktu untuk menyapa santai dan menanyakan kabar anda").
        9. ATURAN LANGKAH SIANG/SORE HARI: Jika langkah kaki di siang atau sore hari masih di bawah total baseline harian, JANGAN menilainya buruk atau menurun drastis karena hari belum selesai. Jelaskan secara ramah bahwa langkah masih terus berproses seiring sisa waktu sebelum jam tidur, dan perbedaannya masih wajar.
        10. ATURAN KUALITAS TIDUR & STANDAR SEHAT 7–8 JAM:
           - Standar kebutuhan tidur sehat manusia (termasuk lansia) adalah 7 hingga 8 jam per malam.
           - Jika durasi tidur semalam kurang dari 6 jam (terutama < 5.5 jam seperti 4.5 jam atau 4 jam 30 menit), ini adalah KURANG TIDUR / DEFISIT TIDUR yang signifikan. DILARANG KERAS menyatakan durasi < 6 jam sebagai 'wajar', 'normal', atau 'cukup baik'! Nyatakan secara jelas dan empatik bahwa tidur semalam kurang dari anjuran sehat 7–8 jam dan sarankan istirahat siang.
           - Frasa 'wajar dan normal' HANYA BOLEH digunakan jika total tidur memenuhi standar sehat (6.5 – 8.5 jam) dengan fluktuasi kecil terhadap kebiasaan orang tua.
           - AKURASI DURASI WAKTU TIDUR: Gunakan durasi jam dan menit PERSIS seperti yang tertulis pada input data (contoh: jika data input menulis '7 jam 42 menit', WAJIB sebut '7 jam 42 menit'). DILARANG KERAS mengarang angka menit atau menyalin angka menit dari contoh schema (seperti salah menyebut '7 jam 12 menit' untuk 7.7 jam)!
        11. ATURAN DETAK JANTUNG & OLAHRAGA: Periksa apakah peningkatan denyut jantung berkaitan dengan sesi olahraga (workout). Jika ya, jelaskan sebagai respon aktif yang sehat. Jika sedikit meningkat saat santai, jelaskan bahwa fluktuasi ringan seperti ini masih wajar, lalu sarankan dengan lembut untuk minum segelas air dan beristirahat sejenak.
        12. HANYA gunakan rekomendasi tindakan yang selaras dengan allowed_actions yang diberikan. JANGAN mengubah dosis atau jadwal obat.
        13. JELASKAN SECARA MENDALAM, INFORMATIF, DAN BERIKAN MULTIPLE POIN: Untuk setiap domain (activity_insight, sleep_insight, heart_insight), wajib isi array `points` dengan 2 hingga 3 poin penjelasan terpisah (masing-masing 1-2 kalimat mendalam):
           - Pada Activity: Poin 1 menjelaskan progres langkah hari ini vs kebiasaan harian secara menenangkan, Poin 2 memberikan dorongan santai tanpa beban target (serta menyebutkan rujukan bertahap 3.000 langkah jika relevan).
           - Pada Sleep: Poin 1 mengulas durasi tidur vs anjuran 7–8 jam dan kebiasaan, Poin 2 menganalisis dampak istirahat & saran waktu istirahat siang jika kurang tidur.
           - Pada Heart: Poin 1 menganalisis denyut saat santai vs kebiasaan dan standar sehat 60–80 bpm, Poin 2 mengaitkan dengan suasana santai/olahraga & saran hidrasi ramah.
           Field `insight` tetap diisi sebagai rangkuman naratif dari poin-poin tersebut.
        14. Kembalikan HANYA format JSON valid sesuai schema persis berikut:
        {
          "today_overview": {
            "condition_status": "STABLE",
            "status_label": "Kondisi Stabil",
            "delta_percentage": 0.0,
            "summary": "Ringkasan komprehensif kondisi kesehatan hari ini dibandingkan pola 14 hari terakhir..."
          },
          "activity_insight": {
            "current_value": "4,200 langkah",
            "baseline_value": "5,000 langkah",
            "delta_percentage": 0.0,
            "status": "Sedang Berjalan",
            "insight": "Rangkuman aktivitas langkah hari ini...",
            "points": [
              "Hingga saat ini tercatat 4.200 langkah dari kebiasaan harian 5.000 langkah. Namun perbedaan ini masih terbilang wajar dan normal karena hari masih berjalan dan langkah terus bertambah hingga malam hari.",
              "Anak tidak perlu cemas; ajak orang tua tetap bergerak santai seperti berjalan ringan di halaman rumah sesuai kemampuan tanpa perlu memaksakan target."
            ]
          },
          "sleep_insight": {
            "current_value": "4 jam 30 menit",
            "baseline_value": "7 jam 42 menit",
            "delta_percentage": -41.5,
            "status": "Kurang Tidur",
            "insight": "Rangkuman istirahat semalam...",
            "points": [
              "Waktu istirahat semalam hanya tercatat 4 jam 30 menit, jauh di bawah standar tidur sehat (7–8 jam) maupun kebiasaan 14 malam terakhir (7 jam 42 menit).",
              "Kurang tidur yang signifikan dapat membuat orang tua merasa lemas atau mengantuk di siang hari. Luangkan waktu untuk menyapa dan pastikan ia bisa istirahat siang sejenak guna memulihkan tenaga."
            ]
          },
          "heart_insight": {
            "current_value": "65 bpm",
            "baseline_value": "63 bpm",
            "delta_percentage": 3.2,
            "status": "Normal",
            "insight": "Rangkuman denyut jantung saat istirahat...",
            "points": [
              "Denyut jantung saat istirahat santai hari ini berada di angka 65, tetap stabil dan berada dalam rentang wajar kebiasaan 14 hari terakhir (63).",
              "Ritme denyut istirahat terpantau tenang. Pastikan asupan cairan tetap cukup dan suasana istirahat tetap nyaman."
            ]
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
            
            let rawInsightOutput = try JSONDecoder().decode(LLMInsightOutput.self, from: innerData)
            let insightOutput = sanitizeAndValidateOutput(rawInsightOutput, against: input)
            
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
    
    // MARK: - Output Validator (PRD Section 8.5)
    
    private func sanitizeAndValidateOutput(_ output: LLMInsightOutput, against input: LLMInsightInput) -> LLMInsightOutput {
        // 1. Validasi Urgency / Condition Status: LLM tidak boleh mengubah status yang ditetapkan Rule Engine
        var conditionStatus = output.todayOverview.conditionStatus
        if input.overallCondition == "DECLINED" && conditionStatus.uppercased() != "DECLINED" {
            conditionStatus = "DECLINED"
        }
        
        // 2. Filter prohibited diagnostic content dari recommended actions
        let prohibitedTerms = ["hipertensi", "gagal jantung", "insomnia akut", "aritmia", "dosis obat", "resep dokter"]
        let safeActions = output.recommendedActions.filter { action in
            let lower = action.lowercased()
            return !prohibitedTerms.contains { lower.contains($0) }
        }
        
        let finalActions = safeActions.isEmpty ? input.allowedActions : safeActions
        
        let todayOverview = TodayOverviewInsight(
            conditionStatus: conditionStatus,
            statusLabel: output.todayOverview.statusLabel,
            deltaPercentage: output.todayOverview.deltaPercentage,
            summary: output.todayOverview.summary
        )
        
        return LLMInsightOutput(
            todayOverview: todayOverview,
            activityInsight: output.activityInsight,
            sleepInsight: output.sleepInsight,
            heartInsight: output.heartInsight,
            recommendedActions: finalActions
        )
    }
}
