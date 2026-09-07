import Foundation
import HealthKit

@MainActor
final class HealthKitManager {
    static let shared = HealthKitManager()
    
    private let healthStore = HKHealthStore()
    
    private let readTypes: Set<HKObjectType> = {
        var types: Set<HKObjectType> = []
        let quantityIdentifiers: [HKQuantityTypeIdentifier] = [
            .restingHeartRate,
            .heartRate,
            .heartRateVariabilitySDNN,
            .stepCount,
            .appleMoveTime,
            .appleExerciseTime,
            .activeEnergyBurned
        ]
        for id in quantityIdentifiers {
            if let type = HKObjectType.quantityType(forIdentifier: id) {
                types.insert(type)
            }
        }
        
        let categoryIdentifiers: [HKCategoryTypeIdentifier] = [
            .sleepAnalysis,
            .appleStandHour
        ]
        for id in categoryIdentifiers {
            if let type = HKObjectType.categoryType(forIdentifier: id) {
                types.insert(type)
            }
        }
        
        types.insert(HKSeriesType.heartbeat())
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
        
        async let heartAndHRV = fetchHeartAndHRVMetrics()
        async let sleep = fetchSleepMetrics()
        async let activity = fetchActivityMetrics()
        
        let (heartData, sleepData, activityData) = await (heartAndHRV, sleep, activity)
        
        return DailyHealthSummary(
            date: Date(),
            latestHeartRate: heartData.latestHR,
            restingHeartRate: heartData.restingHR,
            meanHeartRate24h: heartData.meanHR24h,
            heartRateSD24h: heartData.sdHR24h,
            maxHeartRate24h: heartData.maxHR24h,
            hrvSDNN14DayMean: heartData.hrvSDNN14d,
            hrvRMSSD: heartData.hrvRMSSD,
            hrvDropFromBaseline: heartData.hrvDrop,
            sleepHours: sleepData.duration,
            sleepEfficiency: sleepData.efficiency,
            deepSleepPercentage: sleepData.deepPercent,
            remSleepPercentage: sleepData.remPercent,
            sleepBedtimeSDMinutes: sleepData.bedtimeSD,
            stepCount: activityData.steps,
            activeMinutesToday: activityData.activeMins,
            exerciseMinutesWeek: activityData.exerciseMinsWeek,
            activeEnergyKcalToday: activityData.activeEnergyKcal,
            standHoursToday: activityData.standHours
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
        
        let hasAnyData = summaries.contains { $0.stepCount != nil || $0.restingHeartRate != nil }
        return hasAnyData ? summaries : generateMockHistory(days: days)
    }
    
    // MARK: - Private HealthKit Queries
    
    private struct HeartAndHRVData {
        var latestHR: Double?
        var restingHR: Double?
        var meanHR24h: Double?
        var sdHR24h: Double?
        var maxHR24h: Double?
        var hrvSDNN14d: Double?
        var hrvRMSSD: Double?
        var hrvDrop: Double?
    }
    
    private func fetchHeartAndHRVMetrics() async -> HeartAndHRVData {
        var data = HeartAndHRVData()
        let now = Date()
        let calendar = Calendar.current
        let start24h = calendar.date(byAdding: .hour, value: -24, to: now)!
        let start7d = calendar.date(byAdding: .day, value: -7, to: now)!
        let start14d = calendar.date(byAdding: .day, value: -14, to: now)!
        
        // 1. Resting HR
        if let rhrType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
            data.restingHR = await fetchLatestQuantitySample(for: rhrType, unit: HKUnit.count().unitDivided(by: .minute()))
        }
        
        // 2, 3, 4. Heart Rate 24h (Latest, Mean, SD, Max)
        if let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            data.latestHR = await fetchLatestQuantitySample(for: hrType, unit: HKUnit.count().unitDivided(by: .minute()))
            
            var hrSamples = await fetchQuantitySamples(for: hrType, start: start24h, end: now)
            if hrSamples.isEmpty {
                hrSamples = await fetchQuantitySamples(for: hrType, start: start7d, end: now)
            }
            let hrValues = hrSamples.map { $0.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) }
            if !hrValues.isEmpty {
                let mean = hrValues.reduce(0, +) / Double(hrValues.count)
                data.meanHR24h = mean
                data.maxHR24h = hrValues.max()
                if hrValues.count > 1 {
                    let variance = hrValues.reduce(0) { $0 + pow($1 - mean, 2) } / Double(hrValues.count - 1)
                    data.sdHR24h = sqrt(variance)
                } else {
                    data.sdHR24h = 0.0
                }
            }
        }
        
        // 5, 7. HRV SDNN (14-day mean & Drop from Baseline)
        if let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            let hrvSamples = await fetchQuantitySamples(for: hrvType, start: start14d, end: now)
            let hrvValues = hrvSamples.map { $0.quantity.doubleValue(for: .secondUnit(with: .milli)) }
            if !hrvValues.isEmpty {
                let mean14d = hrvValues.reduce(0, +) / Double(hrvValues.count)
                data.hrvSDNN14d = mean14d
                if let latest = hrvValues.last {
                    data.hrvDrop = latest - mean14d
                }
            } else if let latest = await fetchLatestQuantitySample(for: hrvType, unit: .secondUnit(with: .milli)) {
                data.hrvSDNN14d = latest
                data.hrvDrop = 0.0
            }
        }
        
        // 6. HRV RMSSD (Short-Term from Beat-to-Beat series)
        let calculatedRMSSD = await fetchRMSSDFromHeartbeatSeries()
        if let rmssd = calculatedRMSSD {
            data.hrvRMSSD = rmssd
        } else if let sdnn = data.hrvSDNN14d {
            data.hrvRMSSD = sdnn
        }
        
        return data
    }
    
    private func fetchRMSSDFromHeartbeatSeries() async -> Double? {
        return await withCheckedContinuation { continuation in
            let seriesType = HKSeriesType.heartbeat()
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: seriesType, predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, _ in
                guard let heartbeatSeries = samples?.first as? HKHeartbeatSeriesSample, self != nil else {
                    continuation.resume(returning: nil)
                    return
                }
                
                var timeIntervals: [Double] = []
                let seriesQuery = HKHeartbeatSeriesQuery(heartbeatSeries: heartbeatSeries) { _, timeSinceSeriesStart, precededByGap, done, _ in
                    if !precededByGap {
                        timeIntervals.append(timeSinceSeriesStart)
                    }
                    if done {
                        guard timeIntervals.count > 1 else {
                            continuation.resume(returning: nil)
                            return
                        }
                        var rrIntervals: [Double] = []
                        for i in 1..<timeIntervals.count {
                            let interval = (timeIntervals[i] - timeIntervals[i-1]) * 1000.0
                            if interval >= 300.0 && interval <= 2000.0 {
                                rrIntervals.append(interval)
                            }
                        }
                        guard rrIntervals.count > 1 else {
                            continuation.resume(returning: nil)
                            return
                        }
                        var sumSquaredDiffs = 0.0
                        var validDiffCount = 0
                        for i in 0..<(rrIntervals.count - 1) {
                            let diff = rrIntervals[i+1] - rrIntervals[i]
                            if abs(diff) <= 300.0 {
                                sumSquaredDiffs += diff * diff
                                validDiffCount += 1
                            }
                        }
                        if validDiffCount > 0 {
                            continuation.resume(returning: sqrt(sumSquaredDiffs / Double(validDiffCount)))
                        } else {
                            continuation.resume(returning: nil)
                        }
                    }
                }
                self?.healthStore.execute(seriesQuery)
            }
            self.healthStore.execute(query)
        }
    }
    
    private struct SleepData {
        var duration: Double?
        var efficiency: Double?
        var deepPercent: Double?
        var remPercent: Double?
        var bedtimeSD: Double?
    }
    
    private func fetchSleepMetrics() async -> SleepData {
        var data = SleepData()
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return data }
        
        let now = Date()
        let calendar = Calendar.current
        let start14d = calendar.date(byAdding: .day, value: -14, to: now)!
        
        let samples = await fetchCategorySamples(for: sleepType, start: start14d, end: now)
        guard !samples.isEmpty else { return data }
        
        var sleepSessions: [[HKCategorySample]] = []
        let sortedSamples = samples.sorted(by: { $0.startDate < $1.startDate })
        var currentSession: [HKCategorySample] = []
        
        for sample in sortedSamples {
            if let last = currentSession.last {
                if sample.startDate.timeIntervalSince(last.endDate) > 4 * 3600 {
                    if !currentSession.isEmpty { sleepSessions.append(currentSession) }
                    currentSession = [sample]
                } else {
                    currentSession.append(sample)
                }
            } else {
                currentSession.append(sample)
            }
        }
        if !currentSession.isEmpty { sleepSessions.append(currentSession) }
        
        if let latestSession = sleepSessions.last {
            var inBedDuration: TimeInterval = 0
            var totalAsleepDuration: TimeInterval = 0
            var deepDuration: TimeInterval = 0
            var remDuration: TimeInterval = 0
            
            for sample in latestSession {
                let duration = sample.endDate.timeIntervalSince(sample.startDate)
                let val = HKCategoryValueSleepAnalysis(rawValue: sample.value)
                if val == .inBed {
                    inBedDuration += duration
                } else {
                    if val == .asleepUnspecified || val == .asleepCore || val == .asleepDeep || val == .asleepREM {
                        totalAsleepDuration += duration
                    }
                    if val == .asleepDeep { deepDuration += duration }
                    if val == .asleepREM { remDuration += duration }
                }
            }
            if inBedDuration == 0, let first = latestSession.first, let last = latestSession.last {
                inBedDuration = last.endDate.timeIntervalSince(first.startDate)
            }
            data.duration = totalAsleepDuration / 3600.0
            if inBedDuration > 0 { data.efficiency = min(100.0, (totalAsleepDuration / inBedDuration) * 100.0) }
            if totalAsleepDuration > 0 {
                data.deepPercent = (deepDuration / totalAsleepDuration) * 100.0
                data.remPercent = (remDuration / totalAsleepDuration) * 100.0
            }
        }
        
        var bedtimeMinutes: [Double] = []
        for session in sleepSessions {
            if let firstSample = session.first {
                let components = calendar.dateComponents([.hour, .minute], from: firstSample.startDate)
                if let hour = components.hour, let min = components.minute {
                    var totalMins = Double(hour * 60 + min)
                    if hour < 12 { totalMins += 24 * 60 }
                    bedtimeMinutes.append(totalMins)
                }
            }
        }
        if bedtimeMinutes.count > 1 {
            let mean = bedtimeMinutes.reduce(0, +) / Double(bedtimeMinutes.count)
            let variance = bedtimeMinutes.reduce(0) { $0 + pow($1 - mean, 2) } / Double(bedtimeMinutes.count - 1)
            data.bedtimeSD = sqrt(variance)
        } else if !bedtimeMinutes.isEmpty {
            data.bedtimeSD = 0.0
        }
        
        return data
    }
    
    private struct ActivityData {
        var steps: Double?
        var activeMins: Double?
        var exerciseMinsWeek: Double?
        var activeEnergyKcal: Double?
        var standHours: Int?
    }
    
    private func fetchActivityMetrics() async -> ActivityData {
        var data = ActivityData()
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let startOfWeek = calendar.date(byAdding: .day, value: -7, to: now)!
        
        if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            data.steps = await fetchCumulativeSum(for: stepType, start: startOfDay, end: now, unit: .count())
        }
        
        if let moveTimeType = HKQuantityType.quantityType(forIdentifier: .appleMoveTime) {
            var activeMins = await fetchCumulativeSum(for: moveTimeType, start: startOfDay, end: now, unit: .minute())
            if activeMins == nil || activeMins == 0 {
                if let exerciseType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) {
                    activeMins = await fetchCumulativeSum(for: exerciseType, start: startOfDay, end: now, unit: .minute())
                }
            }
            data.activeMins = activeMins
        }
        
        if let exerciseType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) {
            data.exerciseMinsWeek = await fetchCumulativeSum(for: exerciseType, start: startOfWeek, end: now, unit: .minute())
        }
        
        if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            data.activeEnergyKcal = await fetchCumulativeSum(for: energyType, start: startOfDay, end: now, unit: .kilocalorie())
        }
        
        if let standType = HKCategoryType.categoryType(forIdentifier: .appleStandHour) {
            let samples = await fetchCategorySamples(for: standType, start: startOfDay, end: now)
            data.standHours = samples.filter { $0.value == HKCategoryValueAppleStandHour.stood.rawValue }.count
        }
        
        return data
    }
    
    private func fetchSummary(for date: Date) async -> DailyHealthSummary {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return DailyHealthSummary(date: date)
        }
        let dayPredicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: [])
        
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
            restingHeartRate: restingHR,
            stepCount: stepCount
        )
    }
    
    // MARK: - Query Helpers
    private func fetchLatestQuantitySample(for type: HKQuantityType, unit: HKUnit) async -> Double? {
        return await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: sample.quantity.doubleValue(for: unit))
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchQuantitySamples(for type: HKQuantityType, start: Date, end: Date) async -> [HKQuantitySample] {
        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                let result = (samples as? [HKQuantitySample]) ?? []
                continuation.resume(returning: result)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchCategorySamples(for type: HKCategoryType, start: Date, end: Date) async -> [HKCategorySample] {
        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                let result = (samples as? [HKCategorySample]) ?? []
                continuation.resume(returning: result)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchCumulativeSum(for type: HKQuantityType, start: Date, end: Date, unit: HKUnit) async -> Double? {
        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, statistics, _ in
                if let sum = statistics?.sumQuantity() {
                    continuation.resume(returning: sum.doubleValue(for: unit))
                } else {
                    Task {
                        if let samples = await self?.fetchQuantitySamples(for: type, start: start, end: end) {
                            let total = samples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: unit) }
                            continuation.resume(returning: total > 0 ? total : nil)
                        } else {
                            continuation.resume(returning: nil)
                        }
                    }
                }
            }
            healthStore.execute(query)
        }
    }
    
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
