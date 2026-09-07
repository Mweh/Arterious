//
//  MockHealthScenarios.swift
//  Arterious
//
//  Pipeline Data & Rule-Based Scenario Engine sesuai PRD:
//  sleep_data.json ──┐
//  activity_data.json┼──→ baseline.json ──→ rule_results.json + rule_catalog.json ──→ prompt.json
//  heart_data.json ──┘
//

import Foundation

// MARK: - Rule & Evaluation Models (PRD Bab 7, 8, 9, 10, 12, 13)

/// Definisi master dari suatu rule di dalam katalog rule-based
struct RuleDefinition: Codable, Identifiable {
    var id: String { ruleId }
    let ruleId: String
    let domain: String
    let name: String
    let condition: String
    let dailyCondition: String
    let severity: Int
    let concernOutcome: String
    let allowedActions: [String]
    
    enum CodingKeys: String, CodingKey {
        case ruleId = "rule_id"
        case domain, name, condition
        case dailyCondition = "daily_condition"
        case severity
        case concernOutcome = "concern_outcome"
        case allowedActions = "allowed_actions"
    }
}

/// Katalog master aturan (Rule Catalog)
struct RuleCatalog: Codable {
    let rules: [RuleDefinition]
    let overallStatusActions: [String: [String]]
    let prohibitedContent: [String]
    
    enum CodingKeys: String, CodingKey {
        case rules
        case overallStatusActions = "overall_status_actions"
        case prohibitedContent = "prohibited_content"
    }
    
    /// Cari rule berdasarkan ID (contoh: "H2", "S17", "A8")
    func rule(for id: String) -> RuleDefinition? {
        rules.first { $0.ruleId.caseInsensitiveCompare(id) == .orderedSame }
    }
    
    /// Ambil kumpulan action dari rule-rule yang HIT + overall status policy
    func resolveActions(for hitRuleIds: [String], status: String) -> [String] {
        var actions: [String] = []
        
        // 1. Actions dari masing-masing rule yang HIT
        for id in hitRuleIds {
            if let r = rule(for: id) {
                for act in r.allowedActions where !actions.contains(act) {
                    actions.append(act)
                }
            }
        }
        
        // 2. Actions dari status level policy (CAUTION, WARNING, dll.)
        if let statusActs = overallStatusActions[status] {
            for act in statusActs where !actions.contains(act) {
                actions.append(act)
            }
        }
        
        return actions
    }
}

/// Item rule yang aktif/terpenuhi (HIT) hasil evaluasi data
struct TriggeredRule: Codable, Identifiable {
    var id: String { ruleId }
    let ruleId: String
    let name: String?
    let condition: String
    let metOnDates: [String]?
    let severity: Int
    let derivedAction: String?
    
    enum CodingKeys: String, CodingKey {
        case ruleId = "rule_id"
        case name, condition
        case metOnDates = "met_on_dates"
        case severity
        case derivedAction = "derived_action"
    }
}

/// Evaluasi per domain (sleep, activity, heart)
struct DomainEvaluation: Codable {
    let domain: String
    let dailyCondition: String
    let absoluteStatus: String?
    let relativeStatus: String?
    let triggeredRules: [TriggeredRule]
    let concernOutcome: String
    let maxSeverity: Int
    
    enum CodingKeys: String, CodingKey {
        case domain
        case dailyCondition = "daily_condition"
        case absoluteStatus = "absolute_status"
        case relativeStatus = "relative_status"
        case triggeredRules = "triggered_rules"
        case concernOutcome = "concern_outcome"
        case maxSeverity = "max_severity"
    }
}

/// Hasil lengkap evaluasi Rule Engine
struct RuleEvaluationResult: Codable {
    let sleepEvaluation: DomainEvaluation
    let activityEvaluation: DomainEvaluation
    let heartEvaluation: DomainEvaluation
    let overallCareStatus: String
    let overallConcernState: String
    let multiDomainFlag: Bool
    let domainsAffected: [String]
    let hitRuleIds: [String]
    
    enum CodingKeys: String, CodingKey {
        case sleepEvaluation = "sleep_evaluation"
        case activityEvaluation = "activity_evaluation"
        case heartEvaluation = "heart_evaluation"
        case overallCareStatus = "overall_care_status"
        case overallConcernState = "overall_concern_state"
        case multiDomainFlag = "multi_domain_flag"
        case domainsAffected = "domains_affected"
        case hitRuleIds = "hit_rule_ids"
    }
    
    /// Gabungan seluruh rule yang HIT dari semua domain
    var allTriggeredRules: [TriggeredRule] {
        sleepEvaluation.triggeredRules + activityEvaluation.triggeredRules + heartEvaluation.triggeredRules
    }
}

// MARK: - Raw Health Record Structs (PRD §2)

/// Record tidur harian
struct SleepRecord: Codable, Identifiable {
    var id: String { date }
    let date: String
    let bedtime: String
    let wakeTime: String
    let totalSleepMinutes: Int
    let timeInBedMinutes: Int
    let awakeMinutes: Int
    let sleepEfficiencyPct: Double
    let remMinutes: Int
    let coreMinutes: Int
    let deepMinutes: Int
    let bedtimeDeviationMinutes: Int
    let wakeTimeDeviationMinutes: Int
    let sleepDurationDeviationMinutes: Int
    
    enum CodingKeys: String, CodingKey {
        case date, bedtime
        case wakeTime = "wake_time"
        case totalSleepMinutes = "total_sleep_minutes"
        case timeInBedMinutes = "time_in_bed_minutes"
        case awakeMinutes = "awake_minutes"
        case sleepEfficiencyPct = "sleep_efficiency_pct"
        case remMinutes = "rem_minutes"
        case coreMinutes = "core_minutes"
        case deepMinutes = "deep_minutes"
        case bedtimeDeviationMinutes = "bedtime_deviation_minutes"
        case wakeTimeDeviationMinutes = "wake_time_deviation_minutes"
        case sleepDurationDeviationMinutes = "sleep_duration_deviation_minutes"
    }
}

/// Record aktivitas harian
struct ActivityRecord: Codable, Identifiable {
    var id: String { date }
    let date: String
    let steps: Int
    let stepsPctOfBaseline: Double
    let stepsAt1200: Int
    let stepsAt1800: Int
    let exerciseMinutes: Int
    let walkingDistanceKm: Double
    let walkingSpeedMps: Double
    let walkingSpeedPctChange: Double
    let walkingSteadinessEvent: Bool
    let workoutActive: Bool
    let workoutType: String?
    let watchWearHours: Double
    
    enum CodingKeys: String, CodingKey {
        case date, steps
        case stepsPctOfBaseline = "steps_pct_of_baseline"
        case stepsAt1200 = "steps_at_1200"
        case stepsAt1800 = "steps_at_1800"
        case exerciseMinutes = "exercise_minutes"
        case walkingDistanceKm = "walking_distance_km"
        case walkingSpeedMps = "walking_speed_mps"
        case walkingSpeedPctChange = "walking_speed_pct_change"
        case walkingSteadinessEvent = "walking_steadiness_event"
        case workoutActive = "workout_active"
        case workoutType = "workout_type"
        case watchWearHours = "watch_wear_hours"
    }
}

/// Record heart & safety harian
struct HeartRecord: Codable, Identifiable {
    var id: String { date }
    let date: String
    let restingHrBpm: Double
    let restingHrDeltaBpm: Double
    let walkingHrAvgBpm: Double
    let hrvSdnnMs: Double
    let hrvPctChange: Double
    let respiratoryRate: Double?
    let oxygenSaturationPct: Double?
    let highHrEvent: Bool
    let lowHrEvent: Bool
    let irregularRhythmEvent: Bool
    let fallEvent: Bool
    
    enum CodingKeys: String, CodingKey {
        case date
        case restingHrBpm = "resting_hr_bpm"
        case restingHrDeltaBpm = "resting_hr_delta_bpm"
        case walkingHrAvgBpm = "walking_hr_avg_bpm"
        case hrvSdnnMs = "hrv_sdnn_ms"
        case hrvPctChange = "hrv_pct_change"
        case respiratoryRate = "respiratory_rate"
        case oxygenSaturationPct = "oxygen_saturation_pct"
        case highHrEvent = "high_hr_event"
        case lowHrEvent = "low_hr_event"
        case irregularRhythmEvent = "irregular_rhythm_event"
        case fallEvent = "fall_event"
    }
}

/// Helper wrapper untuk list records
struct RecordWrapper<T: Codable>: Codable {
    let records: [T]
}

// MARK: - Mock Data Loader & Prompt Assembler

enum MockDataLoader {
    
    // MARK: - Generic Loading with Multi-path Support
    
    static func load<T: Decodable>(_ filename: String, as type: T.Type) -> T? {
        guard let data = loadRawData(filename) else {
            print("⚠️ MockDataLoader: File \(filename).json tidak ditemukan.")
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            print("⚠️ MockDataLoader: Gagal decode \(filename).json: \(error)")
            return nil
        }
    }
    
    static func loadRawData(_ filename: String) -> Data? {
        let cleanName = filename.replacingOccurrences(of: ".json", with: "")
        
        // 1. Coba dari Bundle.main
        if let bundleURL = Bundle.main.url(forResource: cleanName, withExtension: "json"),
           let data = try? Data(contentsOf: bundleURL) {
            return data
        }
        
        // 2. Coba dari direktori file proyek via compile-time #filePath
        let baseDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let candidateFolders = ["Data", "Rule", "Scenario"]
        
        for folder in candidateFolders {
            let fileURL = baseDir.appendingPathComponent(folder).appendingPathComponent("\(cleanName).json")
            if FileManager.default.fileExists(atPath: fileURL.path),
               let data = try? Data(contentsOf: fileURL) {
                return data
            }
        }
        
        // 3. Coba dari Current Working Directory
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for folder in candidateFolders {
            let fileURL = cwd.appendingPathComponent("Arterious/LLMIntegration/\(folder)/\(cleanName).json")
            if FileManager.default.fileExists(atPath: fileURL.path),
               let data = try? Data(contentsOf: fileURL) {
                return data
            }
        }
        
        return nil
    }
    
    // MARK: - Data Loaders
    
    static func loadSleepData() -> [SleepRecord] {
        load("sleep_data", as: RecordWrapper<SleepRecord>.self)?.records ?? []
    }
    
    static func loadActivityData() -> [ActivityRecord] {
        load("activity_data", as: RecordWrapper<ActivityRecord>.self)?.records ?? []
    }
    
    static func loadHeartData() -> [HeartRecord] {
        load("heart_data", as: RecordWrapper<HeartRecord>.self)?.records ?? []
    }
    
    static func loadRuleCatalog() -> RuleCatalog? {
        load("rule_catalog", as: RuleCatalog.self)
    }
    
    static func loadRuleResults() -> RuleEvaluationResult? {
        load("rule_results", as: RuleEvaluationResult.self)
    }
    
    static func loadPrompt() -> LLMInsightInput? {
        load("prompt", as: LLMInsightInput.self)
    }
    
    // MARK: - Dynamic Prompt Assembly from Hit Rules
    
    /// Merakit LLMInsightInput secara dinamis berdasarkan rule yang HIT
    /// Menjamin bahwa allowed_actions, facts, dan triggered_rules_summary
    /// murni berasal dari rule engine yang aktif (H1, H2, S17, A8, dll.)
    static func assemblePromptFromHitRules(
        parentDisplayName: String = "Ibu",
        reportPeriod: String = "3 hari terakhir"
    ) -> LLMInsightInput? {
        guard let evaluation = loadRuleResults(),
              let catalog = loadRuleCatalog() else {
            return nil
        }
        
        // 1. Kumpulkan facts dari rule yang HIT
        var facts: [String] = []
        var triggeredSummary: [String] = []
        var allowedActions: [String] = []
        
        for triggered in evaluation.allTriggeredRules {
            let ruleId = triggered.ruleId
            facts.append("[\(ruleId)] \(triggered.condition)")
            
            if let definition = catalog.rule(for: ruleId) {
                triggeredSummary.append("\(ruleId): \(definition.condition)")
                for action in definition.allowedActions where !allowedActions.contains(action) {
                    allowedActions.append(action)
                }
            } else {
                triggeredSummary.append("\(ruleId): \(triggered.condition)")
            }
            
            if let derived = triggered.derivedAction, !allowedActions.contains(derived) {
                allowedActions.append(derived)
            }
        }
        
        // 2. Tambahkan action dari overall status policy (misal CAUTION)
        if let statusActions = catalog.overallStatusActions[evaluation.overallCareStatus] {
            for act in statusActions where !allowedActions.contains(act) {
                allowedActions.append(act)
            }
        }
        
        return LLMInsightInput(
            task: "generate_caregiver_insight",
            language: "id-ID",
            audience: "anak/caregiver lansia",
            parentDisplayName: parentDisplayName,
            overallStatus: evaluation.overallCareStatus,
            concernState: evaluation.overallConcernState,
            reportPeriod: reportPeriod,
            facts: facts,
            triggeredRulesSummary: triggeredSummary,
            allowedActions: allowedActions,
            prohibitedContent: catalog.prohibitedContent,
            style: LLMInsightStyle(tone: "tenang, empatik, objektif, ringkas", maxSentences: 4)
        )
    }
}
