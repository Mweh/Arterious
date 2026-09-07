//
//  LLMInsightOutput.swift
//  Arterious
//
//  Validated output schema dari LLM sesuai PRD §12.3.
//  Ini adalah response yang dikembalikan oleh Gemini API setelah di-parse.
//

import Foundation

/// Output LLM yang wajib tervalidasi — sesuai PRD §12.3
///
/// Contoh dari PRD:
/// ```json
/// {
///   "title": "Perubahan pola perlu diperhatikan",
///   "summary": "Dalam tiga hari terakhir, tidur Ibu lebih pendek...",
///   "recommended_actions": [
///     "Hubungi Ibu hari ini dan tanyakan keluhan.",
///     "Jika tersedia, bantu ukur tekanan darah dengan tensimeter."
///   ],
///   "urgency": "CAUTION"
/// }
/// ```
struct LLMInsightOutput: Codable {
    let title: String
    let summary: String
    let recommendedActions: [String]
    let urgency: String
    
    enum CodingKeys: String, CodingKey {
        case title
        case summary
        case recommendedActions = "recommended_actions"
        case urgency
    }
}
