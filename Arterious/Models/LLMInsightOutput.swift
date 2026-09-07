//
//  LLMInsightOutput.swift
//  Arterious
//
//  Output terstruktur dari LLM (Gemini) yang memisahkan Today's Overview
//  serta per-section domain metric (Activity, Sleep, Heart) lengkap dengan angka vs baseline.
//

import Foundation

/// Data perbandingan numerik dan analisis AI untuk masing-masing domain metrik
struct DomainMetricInsight: Codable {
    let currentValue: String
    let baselineValue: String
    let deltaPercentage: Double
    let status: String
    let insight: String
    
    enum CodingKeys: String, CodingKey {
        case currentValue = "current_value"
        case baselineValue = "baseline_value"
        case deltaPercentage = "delta_percentage"
        case status
        case insight
    }
}

/// Ringkasan umum hari ini vs baseline 14 hari
struct TodayOverviewInsight: Codable {
    let conditionStatus: String   // "IMPROVED", "STABLE", "DECLINED"
    let statusLabel: String       // e.g. "Kondisi Stabil", "Penurunan 23%", "Membaik +15%"
    let deltaPercentage: Double?  // Rata-rata atau persentase deviasi dominan
    let summary: String           // Narasi perbandingan keseluruhan terhadap baseline
    
    enum CodingKeys: String, CodingKey {
        case conditionStatus = "condition_status"
        case statusLabel = "status_label"
        case deltaPercentage = "delta_percentage"
        case summary
    }
}

/// Root output LLM terstruktur yang diterima dari Gemini
struct LLMInsightOutput: Codable {
    let todayOverview: TodayOverviewInsight
    let activityInsight: DomainMetricInsight
    let sleepInsight: DomainMetricInsight
    let heartInsight: DomainMetricInsight
    let recommendedActions: [String]
    
    enum CodingKeys: String, CodingKey {
        case todayOverview = "today_overview"
        case activityInsight = "activity_insight"
        case sleepInsight = "sleep_insight"
        case heartInsight = "heart_insight"
        case recommendedActions = "recommended_actions"
    }
}
