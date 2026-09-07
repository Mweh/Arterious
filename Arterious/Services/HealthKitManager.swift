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
        types.insert(HKObjectType.workoutType())
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
        async let latestHRData = fetchLatestHeartRateWithTime()
        async let sleepData = fetchLastNightSleep()
        async let workoutData = fetchRecentWorkout()
        
        let (sleepHours, sleepDetails) = await sleepData
        let (latestHR, latestHRDate) = await latestHRData
        let (isWorkoutActive, workoutName) = await workoutData
        
        return await DailyHealthSummary(
            date: Date(),
            latestHeartRate: latestHR,
            latestHeartRateDate: latestHRDate,
            isWorkoutActive: isWorkoutActive,
            recentWorkoutName: workoutName,
            restingHeartRate: restingHR,
            stepCount: steps,
            sleepHours: sleepHours,
            sleepDetails: sleepDetails
        )
    }
    
    func fetchHistoricalSummaries(days: Int = 14) async -> [DailyHealthSummary] {
        guard isHealthKitAvailable else {
            return generateMockHistory(days: days)
        }
        
        let calendar = Calendar.current
        var summaries: [DailyHealthSummary] = []
        let today = calendar.startOfDay(for: Date())
        
        for dayOffset in 1...days {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                let summary = await fetchSummary(for: date)
                summaries.append(summary)
            }
        }
        
        return summaries
    }
    
    // MARK: - Private HealthKit Queries
    
    private func fetchTodaySteps() async -> Double? {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return nil }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
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
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
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
    
    func fetchLatestHeartRateWithTime() async -> (value: Double?, timestamp: Date?) {
        guard isHealthKitAvailable,
              let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return (nil, nil)
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: (nil, nil))
                    return
                }
                let unit = HKUnit.count().unitDivided(by: .minute())
                let bpm = sample.quantity.doubleValue(for: unit)
                continuation.resume(returning: (bpm, sample.endDate))
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchLatestHeartRate() async -> Double? {
        let (value, _) = await fetchLatestHeartRateWithTime()
        return value
    }
    
    func fetchRecentWorkout() async -> (isActive: Bool, workoutName: String?) {
        guard isHealthKitAvailable else { return (false, nil) }
        
        let workoutType = HKObjectType.workoutType()
        let calendar = Calendar.current
        let now = Date()
        guard let twoHoursAgo = calendar.date(byAdding: .hour, value: -2, to: now) else {
            return (false, nil)
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: twoHoursAgo, end: now, options: [])
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                guard let workout = samples?.first as? HKWorkout else {
                    continuation.resume(returning: (false, nil))
                    return
                }
                // Cek apakah workout berlangsung dalam rentang waktu terdekat (aktif atau baru selesai <15 menit)
                let isRecent = abs(workout.endDate.timeIntervalSince(now)) < 900 || workout.endDate >= now
                let name = self.formatWorkoutType(workout.workoutActivityType)
                continuation.resume(returning: (isRecent, name))
            }
            healthStore.execute(query)
        }
    }
    
    nonisolated private func formatWorkoutType(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .walking: return "Jalan Santai / Kaki"
        case .running: return "Lari"
        case .cycling: return "Bersepeda"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "Latihan Kekuatan"
        case .yoga, .mindAndBody: return "Yoga / Relaksasi"
        case .swimming: return "Berenang"
        default: return "Olahraga Fisik"
        }
    }
    
    // MARK: - Real-time Observation
    
    func startHeartRateObserver(onUpdate: @escaping @Sendable () -> Void) -> HKQuery? {
        guard isHealthKitAvailable,
              let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return nil
        }
        
        let query = HKObserverQuery(sampleType: heartRateType, predicate: nil) { _, completionHandler, error in
            defer { completionHandler() }
            if error == nil {
                onUpdate()
            }
        }
        healthStore.execute(query)
        return query
    }
    
    func stopHeartRateObserver(_ query: HKQuery) {
        healthStore.stop(query)
    }
    
    private func fetchLastNightSleep() async -> (hours: Double?, details: SleepDetails?) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return (nil, nil) }
        
        let calendar = Calendar.current
        let now = Date()
        guard let yesterdayNoon = calendar.date(byAdding: .hour, value: -24, to: now) else { return (nil, nil) }
        let predicate = HKQuery.predicateForSamples(withStart: yesterdayNoon, end: now, options: [])
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample], !samples.isEmpty else {
                    continuation.resume(returning: (nil, nil))
                    return
                }
                
                let parsed = self.parseSleepSamples(samples)
                continuation.resume(returning: parsed)
            }
            healthStore.execute(query)
        }
    }
    
    nonisolated private func parseSleepSamples(_ samples: [HKCategorySample]) -> (hours: Double?, details: SleepDetails?) {
        let sortedSamples = samples.sorted { $0.startDate < $1.startDate }
        guard let firstStart = sortedSamples.first?.startDate,
              let lastEnd = sortedSamples.last?.endDate else {
            return (nil, nil)
        }
        
        let bedtime = firstStart
        let wakeTime = lastEnd
        let timeInBedSeconds = max(0.0, wakeTime.timeIntervalSince(bedtime))
        
        var coreSeconds = 0.0
        var deepSeconds = 0.0
        var remSeconds = 0.0
        var asleepUnspecifiedSeconds = 0.0
        var awakeSeconds = 0.0
        var awakeEpisodes: [AwakeEpisode] = []
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        for sample in sortedSamples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate)
            if #available(iOS 16.0, *) {
                switch sample.value {
                case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                    coreSeconds += duration
                case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                    deepSeconds += duration
                case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                    remSeconds += duration
                case HKCategoryValueSleepAnalysis.awake.rawValue:
                    awakeSeconds += duration
                    let mins = Int(duration / 60.0)
                    if mins >= 5 {
                        awakeEpisodes.append(AwakeEpisode(
                            startTimeFormatted: timeFormatter.string(from: sample.startDate),
                            durationMinutes: mins
                        ))
                    }
                default:
                    if sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue {
                        asleepUnspecifiedSeconds += duration
                    }
                }
            } else {
                if sample.value == HKCategoryValueSleepAnalysis.awake.rawValue {
                    awakeSeconds += duration
                } else if sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue {
                    asleepUnspecifiedSeconds += duration
                }
            }
        }
        
        let totalSleepSeconds = coreSeconds + deepSeconds + remSeconds + asleepUnspecifiedSeconds
        guard totalSleepSeconds > 0 else {
            return (nil, nil)
        }
        
        let totalSleepHours = totalSleepSeconds / 3600.0
        let totalSleepMinutes = totalSleepSeconds / 60.0
        let timeInBedMinutes = max(totalSleepMinutes, timeInBedSeconds / 60.0)
        let efficiency = timeInBedMinutes > 0 ? min(100.0, (totalSleepMinutes / timeInBedMinutes) * 100.0) : 88.4
        let awakeMinutes = awakeSeconds / 60.0
        
        let details = SleepDetails(
            bedtime: bedtime,
            wakeTime: wakeTime,
            totalSleepMinutes: totalSleepMinutes,
            timeInBedMinutes: timeInBedMinutes,
            sleepEfficiency: efficiency,
            awakeMinutes: awakeMinutes,
            awakeEpisodes: awakeEpisodes,
            remMinutes: remSeconds > 0 ? (remSeconds / 60.0) : nil,
            coreMinutes: coreSeconds > 0 ? (coreSeconds / 60.0) : nil,
            deepMinutes: deepSeconds > 0 ? (deepSeconds / 60.0) : nil
        )
        
        return (totalSleepHours, details)
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
        
        var sleepHours: Double?
        var sleepDetails: SleepDetails?
        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            if let prevNoon = calendar.date(byAdding: .hour, value: -12, to: startOfDay),
               let nextNoon = calendar.date(byAdding: .hour, value: 12, to: startOfDay) {
                let sleepPredicate = HKQuery.predicateForSamples(withStart: prevNoon, end: nextNoon, options: [])
                (sleepHours, sleepDetails) = await withCheckedContinuation { continuation in
                    let query = HKSampleQuery(sampleType: sleepType, predicate: sleepPredicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, _ in
                        guard let categorySamples = samples as? [HKCategorySample], !categorySamples.isEmpty else {
                            continuation.resume(returning: (nil, nil))
                            return
                        }
                        let parsed = self.parseSleepSamples(categorySamples)
                        continuation.resume(returning: parsed)
                    }
                    self.healthStore.execute(query)
                }
            }
        }
        
        return DailyHealthSummary(
            date: date,
            latestHeartRate: nil,
            restingHeartRate: restingHR,
            stepCount: stepCount,
            sleepHours: sleepHours,
            sleepDetails: sleepDetails
        )
    }
    
    // MARK: - Mock History (for Simulator & Previews)
    
    private func generateMockHistory(days: Int) -> [DailyHealthSummary] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return (1...days).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let sleepDur = Double.random(in: 6.5...8.0)
            let sleepMins = sleepDur * 60.0
            let awakeMins = Double.random(in: 30...55)
            let bedDate = calendar.date(byAdding: .hour, value: -8, to: date)
            let wakeDate = calendar.date(byAdding: .minute, value: Int(sleepMins + awakeMins), to: bedDate ?? date)
            
            let mockDetails = SleepDetails(
                bedtime: bedDate,
                wakeTime: wakeDate,
                totalSleepMinutes: sleepMins,
                timeInBedMinutes: sleepMins + awakeMins,
                sleepEfficiency: min(95.0, (sleepMins / (sleepMins + awakeMins)) * 100.0),
                awakeMinutes: awakeMins,
                awakeEpisodes: [
                    AwakeEpisode(startTimeFormatted: "02:30", durationMinutes: Int(awakeMins / 2)),
                    AwakeEpisode(startTimeFormatted: "04:15", durationMinutes: Int(awakeMins / 2))
                ],
                remMinutes: sleepMins * 0.22,
                coreMinutes: sleepMins * 0.55,
                deepMinutes: sleepMins * 0.18
            )
            
            return DailyHealthSummary(
                date: date,
                latestHeartRate: Double.random(in: 68...75),
                restingHeartRate: Double.random(in: 60...66),
                stepCount: Double.random(in: 3500...6000),
                sleepHours: sleepDur,
                sleepDetails: mockDetails
            )
        }
    }
}
