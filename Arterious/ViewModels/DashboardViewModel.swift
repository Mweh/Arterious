import Foundation
import Observation

@Observable
@MainActor
final class DashboardViewModel {
    var parentName: String = "Mom"
    var todaySummary: DailyHealthSummary = DailyHealthSummary.placeholder
    var historicalSummaries: [DailyHealthSummary] = []
    var cautionInsight: CautionInsight?
    var wellnessStatus: WellnessStatus = .good
    var isLoading: Bool = false
    var errorMessage: String?
    
    private let healthKitManager: HealthKitManager
    
    init(healthKitManager: HealthKitManager = .shared) {
        self.healthKitManager = healthKitManager
    }
    
    func loadDashboardData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await healthKitManager.requestAuthorization()
            
            async let today = healthKitManager.fetchTodaySummary()
            async let history = healthKitManager.fetchHistoricalSummaries(days: 14)
            
            self.todaySummary = await today
            self.historicalSummaries = await history
            
            evaluateWellnessAndCaution(today: self.todaySummary, history: self.historicalSummaries)
        } catch {
            self.errorMessage = "Unable to read HealthKit data. Please check health permissions in Settings."
        }
        
        isLoading = false
    }
    
    func baselineSteps(days: Int = 14) -> Double? {
        let validSteps = historicalSummaries.compactMap(\.stepCount)
        guard !validSteps.isEmpty else { return nil }
        return validSteps.reduce(0, +) / Double(validSteps.count)
    }
    
    func baselineRestingHeartRate(days: Int = 14) -> Double? {
        let validHR = historicalSummaries.compactMap(\.restingHeartRate)
        guard !validHR.isEmpty else { return nil }
        return validHR.reduce(0, +) / Double(validHR.count)
    }
    
    func baselineSleep(days: Int = 14) -> Double? {
        let validSleep = historicalSummaries.compactMap(\.sleepHours)
        guard !validSleep.isEmpty else { return nil }
        return validSleep.reduce(0, +) / Double(validSleep.count)
    }
    
    // MARK: - Trend Analysis & Caution Detection
    
    private func evaluateWellnessAndCaution(today: DailyHealthSummary, history: [DailyHealthSummary]) {
        var cautionsFound: [String] = []
        
        // 1. Check Resting Heart Rate elevation
        if let currentRHR = today.restingHeartRate, let baseRHR = baselineRestingHeartRate(), baseRHR > 0 {
            let rhrIncrease = currentRHR - baseRHR
            if rhrIncrease >= 7.0 {
                cautionsFound.append("resting heart rate is \(Int(round(rhrIncrease))) BPM above her recent baseline")
            }
        }
        
        // 2. Check Step Count significant drop
        if let currentSteps = today.stepCount, let baseSteps = baselineSteps(), baseSteps > 1500 {
            let stepsDropPercent = ((baseSteps - currentSteps) / baseSteps) * 100.0
            if stepsDropPercent >= 35.0 {
                cautionsFound.append("daily steps are noticeably lower than usual")
            }
        }
        
        // 3. Check Sleep duration reduction
        if let currentSleep = today.sleepHours, let baseSleep = baselineSleep(), baseSleep > 5.0 {
            let sleepDropHours = baseSleep - currentSleep
            if sleepDropHours >= 1.5 {
                cautionsFound.append("slept less than her usual average")
            }
        }
        
        // Synthesize into gentle family reminder
        if !cautionsFound.isEmpty {
            self.wellnessStatus = cautionsFound.count >= 2 ? .needsAttention : .fair
            
            let messageDetails = cautionsFound.joined(separator: ", and ")
            self.cautionInsight = CautionInsight(
                title: "\(parentName)'s Routine Shifted",
                message: "\(parentName)'s \(messageDetails). Why not check in with a quick phone call to see how her day is going?",
                suggestedAction: "Call \(parentName)",
                dateDetected: Date()
            )
        } else {
            self.wellnessStatus = .good
            self.cautionInsight = nil
        }
    }
}
