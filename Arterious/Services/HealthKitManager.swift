import Foundation
import HealthKit

@MainActor
final class HealthKitManager {
    static let shared = HealthKitManager()
    
    private let healthStore = HKHealthStore()
    
    private let readTypes: Set<HKObjectType> = {
        var types: Set<HKObjectType> = []
        if let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRate)
        }
        if let restingHeartRate = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
            types.insert(restingHeartRate)
        }
        if let walkingHeartRate = HKQuantityType.quantityType(forIdentifier: .walkingHeartRateAverage) {
            types.insert(walkingHeartRate)
        }
        if let steps = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            types.insert(steps)
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        return types
    }()
    
    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
    
    func requestAuthorization() async throws {
        guard isHealthKitAvailable else { return }
        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
    }
    
    func fetchTodaySummary() async -> DailyHealthSummary {
        guard isHealthKitAvailable else {
            return DailyHealthSummary.placeholder
        }
        
        async let steps = fetchTodaySteps()
        async let restingHR = fetchTodayRestingHeartRate()
        async let latestHR = fetchLatestHeartRate()
        async let sleepHours = fetchLastNightSleepDuration()
        
        return await DailyHealthSummary(
            date: Date(),
            latestHeartRate: latestHR,
            restingHeartRate: restingHR,
            stepCount: steps,
            sleepHours: sleepHours
        )
    }
    
    func fetchHistoricalSummaries(days: Int = 14) async -> [DailyHealthSummary] {
        guard isHealthKitAvailable else {
            return generateMockHistory(days: days)
        }
        
        let calendar = Calendar.current
        var summaries: [DailyHealthSummary] = []
        let today = calendar.startOfDay(for: Date())
        
        for dayOffset in (1...days).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let summary = await fetchSummary(for: date)
            summaries.append(summary)
        }
        
        // If HealthKit returned all nil values (e.g. running in simulator without sample data)
        let hasAnyData = summaries.contains { $0.stepCount != nil || $0.restingHeartRate != nil }
        return hasAnyData ? summaries : generateMockHistory(days: days)
    }
    
    // MARK: - Private HealthKit Queries
    
    private func fetchTodaySteps() async -> Double? {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return nil }
        
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                let count = statistics?.sumQuantity()?.doubleValue(for: .count())
                continuation.resume(returning: count)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchTodayRestingHeartRate() async -> Double? {
        guard let restingType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return nil }
        
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: restingType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, statistics, _ in
                let unit = HKUnit.count().unitDivided(by: .minute())
                let value = statistics?.averageQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchLatestHeartRate() async -> Double? {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return nil }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.startOfDay(for: Date()), end: Date(), options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let unit = HKUnit.count().unitDivided(by: .minute())
                continuation.resume(returning: sample.quantity.doubleValue(for: unit))
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchLastNightSleepDuration() async -> Double? {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        
        let calendar = Calendar.current
        let now = Date()
        guard let yesterdayNoon = calendar.date(byAdding: .hour, value: -24, to: now) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: yesterdayNoon, end: now, options: [])
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // Filter asleep states (asleepUnspecified, asleepCore, asleepDeep, asleepREM)
                let asleepSamples = samples.filter { sample in
                    if #available(iOS 16.0, *) {
                        return sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                               sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                               sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue ||
                               sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                    } else {
                        return sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue
                    }
                }
                
                let totalSeconds = asleepSamples.reduce(0.0) { sum, sample in
                    sum + sample.endDate.timeIntervalSince(sample.startDate)
                }
                
                let hours = totalSeconds > 0 ? (totalSeconds / 3600.0) : nil
                continuation.resume(returning: hours)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchSummary(for date: Date) async -> DailyHealthSummary {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return DailyHealthSummary(date: date)
        }
        
        let dayPredicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        var stepCount: Double?
        if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            stepCount = await withCheckedContinuation { continuation in
                let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: dayPredicate, options: .cumulativeSum) { _, stats, _ in
                    continuation.resume(returning: stats?.sumQuantity()?.doubleValue(for: .count()))
                }
                self.healthStore.execute(query)
            }
        }
        
        var restingHR: Double?
        if let restingType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
            restingHR = await withCheckedContinuation { continuation in
                let query = HKStatisticsQuery(quantityType: restingType, quantitySamplePredicate: dayPredicate, options: .discreteAverage) { _, stats, _ in
                    let unit = HKUnit.count().unitDivided(by: .minute())
                    continuation.resume(returning: stats?.averageQuantity()?.doubleValue(for: unit))
                }
                self.healthStore.execute(query)
            }
        }
        
        return DailyHealthSummary(
            date: date,
            latestHeartRate: nil,
            restingHeartRate: restingHR,
            stepCount: stepCount,
            sleepHours: nil
        )
    }
    
    // MARK: - Mock History (for Simulator & Previews)
    
    private func generateMockHistory(days: Int) -> [DailyHealthSummary] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return (1...days).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            return DailyHealthSummary(
                date: date,
                latestHeartRate: Double.random(in: 68...75),
                restingHeartRate: Double.random(in: 60...66),
                stepCount: Double.random(in: 3500...6000),
                sleepHours: Double.random(in: 6.5...8.0)
            )
        }
    }
}
