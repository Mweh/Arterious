//
//  LLMInsightInput.swift
//  Arterious
//
//  Structured input schema untuk LLM sesuai PRD §12.2.
//  Ini adalah data yang dikirim ke Gemini API untuk generate caregiver insight.
//

import Foundation

/// Style configuration untuk output LLM
struct LLMInsightStyle: Codable {
    let tone: String
    let maxSentences: Int
    
    enum CodingKeys: String, CodingKey {
        case tone
        case maxSentences = "max_sentences"
    }
}

/// Structured input yang dikirim ke LLM — sesuai PRD §12.2
///
/// Contoh dari PRD:
/// ```json
/// {
///   "task": "generate_caregiver_insight",
///   "language": "id-ID",
///   "audience": "anak/caregiver lansia",
///   "parent_display_name": "Ibu",
///   "overall_status": "CAUTION",
///   "concern_state": "NEW_CONCERN",
///   "report_period": "3 hari terakhir",
///   "facts": [...],
///   "allowed_actions": [...],
///   "prohibited_content": [...],
///   "style": { "tone": "...", "max_sentences": 4 }
/// }
/// ```
struct LLMInsightInput: Codable {
    let task: String
    let language: String
    let audience: String
    let parentDisplayName: String
    let overallStatus: String
    let concernState: String
    let reportPeriod: String
    let facts: [String]
    let triggeredRulesSummary: [String]?
    let allowedActions: [String]
    let prohibitedContent: [String]
    let style: LLMInsightStyle
    
    enum CodingKeys: String, CodingKey {
        case task
        case language
        case audience
        case parentDisplayName = "parent_display_name"
        case overallStatus = "overall_status"
        case concernState = "concern_state"
        case reportPeriod = "report_period"
        case facts
        case triggeredRulesSummary = "triggered_rules_summary"
        case allowedActions = "allowed_actions"
        case prohibitedContent = "prohibited_content"
        case style
    }
}
