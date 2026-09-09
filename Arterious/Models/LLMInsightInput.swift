//
//  LLMInsightInput.swift
//  Arterious
//
//  Structured input schema untuk LLM Gemini.
//  Mengirimkan perbandingan angka numerik riil hari ini vs baseline 14 hari
//  beserta status evaluasi rule engine untuk Activity, Sleep, dan Heart.
//

import Foundation

/// Data metrik spesifik yang dikirimkan ke prompt LLM
struct MetricDataPoint: Codable {
    let domain: String
    let currentValueFormatted: String
    let baselineValueFormatted: String
    let deltaPercentage: Double
    let status: String // "IMPROVED", "STABLE", "DECLINED"
    
    enum CodingKeys: String, CodingKey {
        case domain
        case currentValueFormatted = "current_value_formatted"
        case baselineValueFormatted = "baseline_value_formatted"
        case deltaPercentage = "delta_percentage"
        case status
    }
}

/// Style configuration untuk output LLM
struct LLMInsightStyle: Codable {
    let tone: String
    let maxSentences: Int
    
    enum CodingKeys: String, CodingKey {
        case tone
        case maxSentences = "max_sentences"
    }
}

/// Structured input yang dikirim ke LLM Gemini
struct LLMInsightInput: Codable {
    let task: String
    let language: String
    let parentDisplayName: String
    let reportPeriod: String
    let overallCondition: String // "IMPROVED", "STABLE", "DECLINED"
    let overallSummaryPrompt: String
    let activity: MetricDataPoint
    let sleep: MetricDataPoint
    let heart: MetricDataPoint
    let facts: [String]
    let allowedActions: [String]
    let prohibitedContent: [String]
    let style: LLMInsightStyle
    
    enum CodingKeys: String, CodingKey {
        case task
        case language
        case parentDisplayName = "parent_display_name"
        case reportPeriod = "report_period"
        case overallCondition = "overall_condition"
        case overallSummaryPrompt = "overall_summary_prompt"
        case activity
        case sleep
        case heart
        case facts
        case allowedActions = "allowed_actions"
        case prohibitedContent = "prohibited_content"
        case style
    }
}
