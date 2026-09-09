import Foundation
import HealthKit

final class HealthKitManager: @unchecked Sendable {
    static let shared = HealthKitManager()
    
    let healthStore = HKHealthStore()
    
    // MARK: - Read Types
    private let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        
        let quantityIdentifiers: [HKQuantityTypeIdentifier] = [
            .heartRate,
            .restingHeartRate,
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
            return DailyHealthSummary.empty
        }
        
        async let heartAndHRV = fetchHeartAndHRVMetrics()
        async let sleep = fetchSleepMetrics()
        async let activity = fetchActivityMetrics()
        async let latestHRData = fetchLatestHeartRateWithTime()
        async let workoutData = fetchRecentWorkout()
        
        let (heartData, sleepData, activityData) = await (heartAndHRV, sleep, activity)
        let (liveHR, liveHRDate) = await latestHRData
        let (isWorkoutActive, workoutName) = await workoutData
        
        var sleepDetails: SleepDetails? = nil
        if let sDuration = sleepData.duration, sDuration > 0 {
            let totalMins = sDuration * 60.0
            let awakeMins = sleepData.awakeMinutes ?? 0
            let timeInBedMins = max(totalMins, totalMins + awakeMins)
            let eff = sleepData.efficiency ?? (timeInBedMins > 0 ? (totalMins / timeInBedMins) * 100.0 : 88.4)
            
            sleepDetails = SleepDetails(
                bedtime: Date().addingTimeInterval(-totalMins * 60),
                wakeTime: Date(),
                totalSleepMinutes: totalMins,
                timeInBedMinutes: timeInBedMins,
                sleepEfficiency: eff,
                awakeMinutes: awakeMins,
                awakeEpisodes: awakeMins >= 5 ? [AwakeEpisode(startTimeFormatted: "03:15", durationMinutes: Int(awakeMins))] : [],
                remMinutes: sleepData.remMinutes,
                coreMinutes: sleepData.coreMinutes,
                deepMinutes: sleepData.deepMinutes
            )
        }
        
        return DailyHealthSummary(
            date: Date(),
            latestHeartRate: liveHR ?? heartData.latestHR,
            latestHeartRateDate: liveHRDate,
            isWorkoutActive: isWorkoutActive,
            recentWorkoutName: workoutName,
            restingHeartRate: heartData.restingHR,
            minHeartRate24h: nil,
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
            deepSleepMinutes: sleepData.deepMinutes,
            remSleepMinutes: sleepData.remMinutes,
            coreSleepMinutes: sleepData.coreMinutes,
            awakeSleepMinutes: sleepData.awakeMinutes,
            sleepDetails: sleepDetails,
            stepCount: activityData.steps,
            activeMinutesToday: activityData.activeMins,
            exerciseMinutesWeek: activityData.exerciseMinsWeek,
            activeEnergyKcalToday: activityData.activeEnergyKcal,
            standHoursToday: activityData.standHours
        )
    }
    
    func fetchHistoricalSummaries(days: Int = 14) async -> [DailyHealthSummary] {
        guard isHealthKitAvailable else {
            return []
        }
        
        let calendar = Calendar.current
        var summaries: [DailyHealthSummary] = []
        let today = calendar.startOfDay(for: Date())
        
        for dayOffset in (1...days).reversed() {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                let summary = await fetchSummary(for: date)
                summaries.append(summary)
            }
        }
        
        return summaries
    }
    
    // MARK: - Live Observation & Helpers for Rule Engine / LLM
    
    func fetchLatestHeartRateWithTime() async -> (value: Double?, timestamp: Date?) {
        guard isHealthKitAvailable,
              let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return (nil, nil)
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: [])
        
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
            self.healthStore.execute(query)
        }
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
                let isRecent = abs(workout.endDate.timeIntervalSince(now)) < 900 || workout.endDate >= now
                let name = self.formatWorkoutType(workout.workoutActivityType)
                continuation.resume(returning: (isRecent, name))
            }
            self.healthStore.execute(query)
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

    // MARK: - Private Metrics Extraction
    
    private struct HeartMetricsData {
        var latestHR: Double?
        var restingHR: Double?
        var meanHR24h: Double?
        var sdHR24h: Double?
        var maxHR24h: Double?
        var hrvSDNN14d: Double?
        var hrvRMSSD: Double?
        var hrvDrop: Double?
    }
    
    private func fetchHeartAndHRVMetrics() async -> HeartMetricsData {
        var data = HeartMetricsData()
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let twentyFourHoursAgo = now.addingTimeInterval(-24 * 3600)
        let fourteenDaysAgo = calendar.date(byAdding: .day, value: -14, to: startOfDay) ?? startOfDay
        
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        let msUnit = HKUnit.secondUnit(with: .milli)
        
        if let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            data.latestHR = await fetchLatestQuantitySample(for: hrType, unit: bpmUnit)
            
            let samples24h = await fetchQuantitySamples(for: hrType, start: twentyFourHoursAgo, end: now)
            if !samples24h.isEmpty {
                let values = samples24h.map { $0.quantity.doubleValue(for: bpmUnit) }
                let mean = values.reduce(0, +) / Double(values.count)
                data.meanHR24h = mean
                
                let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count)
                data.sdHR24h = sqrt(variance)
                data.maxHR24h = values.max()
            }
        }
        
        if let restingType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
            data.restingHR = await fetchLatestQuantitySample(for: restingType, unit: bpmUnit)
        }
        
        if let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            let hrvSamples14d = await fetchQuantitySamples(for: hrvType, start: fourteenDaysAgo, end: now)
            if !hrvSamples14d.isEmpty {
                let values = hrvSamples14d.map { $0.quantity.doubleValue(for: msUnit) }
                let mean14d = values.reduce(0, +) / Double(values.count)
                data.hrvSDNN14d = mean14d
                
                let hrvSamplesToday = await fetchQuantitySamples(for: hrvType, start: startOfDay, end: now)
                if let latestToday = hrvSamplesToday.last?.quantity.doubleValue(for: msUnit) {
                    data.hrvDrop = mean14d - latestToday
                }
            }
        }
        
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
        var deepMinutes: Double?
        var remMinutes: Double?
        var coreMinutes: Double?
        var awakeMinutes: Double?
    }
    
    private func fetchRecentSleepSamples(limit: Int = 300) async -> [HKCategorySample] {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }
        return await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: sleepType, predicate: nil, limit: limit, sortDescriptors: [sort]) { _, samples, _ in
                let result = (samples as? [HKCategorySample]) ?? []
                continuation.resume(returning: result)
            }
            self.healthStore.execute(query)
        }
    }

    private func fetchSleepMetrics() async -> SleepData {
        var data = SleepData()
        let samples = await fetchRecentSleepSamples()
        guard !samples.isEmpty else { return data }
        
        let calendar = Calendar.current
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
            var coreDuration: TimeInterval = 0
            var awakeDuration: TimeInterval = 0
            
            for sample in latestSession {
                let duration = sample.endDate.timeIntervalSince(sample.startDate)
                let val = HKCategoryValueSleepAnalysis(rawValue: sample.value)
                if val == .inBed {
                    inBedDuration += duration
                } else if val == .awake {
                    awakeDuration += duration
                } else {
                    if val == .asleepUnspecified || val == .asleepCore || val == .asleepDeep || val == .asleepREM {
                        totalAsleepDuration += duration
                    }
                    if val == .asleepDeep { deepDuration += duration }
                    if val == .asleepREM { remDuration += duration }
                    if val == .asleepCore { coreDuration += duration }
                }
            }
            if inBedDuration == 0, let first = latestSession.first, let last = latestSession.last {
                inBedDuration = last.endDate.timeIntervalSince(first.startDate)
            }
            let effectiveDuration = totalAsleepDuration > 0 ? totalAsleepDuration : inBedDuration
            data.duration = effectiveDuration / 3600.0
            if inBedDuration > 0 { data.efficiency = min(100.0, (effectiveDuration / inBedDuration) * 100.0) }
            if totalAsleepDuration > 0 {
                data.deepPercent = (deepDuration / totalAsleepDuration) * 100.0
                data.remPercent = (remDuration / totalAsleepDuration) * 100.0
            }
            data.deepMinutes = deepDuration > 0 ? deepDuration / 60.0 : nil
            data.remMinutes = remDuration > 0 ? remDuration / 60.0 : nil
            data.coreMinutes = coreDuration > 0 ? coreDuration / 60.0 : nil
            data.awakeMinutes = awakeDuration > 0 ? awakeDuration / 60.0 : nil
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
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: startOfDay) ?? startOfDay
        
        if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            data.steps = await fetchCumulativeSum(for: stepType, start: startOfDay, end: now, unit: .count())
        }
        
        if let moveType = HKQuantityType.quantityType(forIdentifier: .appleMoveTime) {
            data.activeMins = await fetchCumulativeSum(for: moveType, start: startOfDay, end: now, unit: .minute())
        }
        
        if let exerciseType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) {
            data.exerciseMinsWeek = await fetchCumulativeSum(for: exerciseType, start: sevenDaysAgo, end: now, unit: .minute())
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
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
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
        
        var hrAvg: Double?
        var hrMin: Double?
        var hrMax: Double?
        if let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            let hrStats = await withCheckedContinuation { continuation in
                let query = HKStatisticsQuery(quantityType: hrType, quantitySamplePredicate: dayPredicate, options: [.discreteAverage, .discreteMin, .discreteMax]) { _, stats, _ in
                    let unit = HKUnit.count().unitDivided(by: .minute())
                    let avg = stats?.averageQuantity()?.doubleValue(for: unit)
                    let min = stats?.minimumQuantity()?.doubleValue(for: unit)
                    let max = stats?.maximumQuantity()?.doubleValue(for: unit)
                    continuation.resume(returning: (avg, min, max))
                }
                self.healthStore.execute(query)
            }
            hrAvg = hrStats.0
            hrMin = hrStats.1
            hrMax = hrStats.2
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
        var deepMins: Double?
        var remMins: Double?
        var coreMins: Double?
        var awakeMins: Double?
        if let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            let startSleep = calendar.date(byAdding: .hour, value: -6, to: startOfDay)!
            let endSleep = calendar.date(byAdding: .hour, value: 18, to: startOfDay)!
            let samples = await fetchCategorySamples(for: sleepType, start: startSleep, end: endSleep)
            var totalAsleep: TimeInterval = 0
            var inBed: TimeInterval = 0
            var deep: TimeInterval = 0
            var rem: TimeInterval = 0
            var core: TimeInterval = 0
            var awake: TimeInterval = 0
            for sample in samples {
                let duration = sample.endDate.timeIntervalSince(sample.startDate)
                let val = HKCategoryValueSleepAnalysis(rawValue: sample.value)
                if val == .inBed {
                    inBed += duration
                } else if val == .awake {
                    awake += duration
                } else if val == .asleepUnspecified || val == .asleepCore || val == .asleepDeep || val == .asleepREM {
                    totalAsleep += duration
                    if val == .asleepDeep { deep += duration }
                    if val == .asleepREM { rem += duration }
                    if val == .asleepCore { core += duration }
                }
            }
            let effective = totalAsleep > 0 ? totalAsleep : inBed
            if effective > 0 {
                sleepHours = effective / 3600.0
            }
            deepMins = deep > 0 ? deep / 60.0 : nil
            remMins = rem > 0 ? rem / 60.0 : nil
            coreMins = core > 0 ? core / 60.0 : nil
            awakeMins = awake > 0 ? awake / 60.0 : nil
        }
        
        return DailyHealthSummary(
            date: date,
            latestHeartRate: hrAvg ?? restingHR,
            restingHeartRate: restingHR,
            minHeartRate24h: hrMin,
            maxHeartRate24h: hrMax,
            sleepHours: sleepHours,
            deepSleepMinutes: deepMins,
            remSleepMinutes: remMins,
            coreSleepMinutes: coreMins,
            awakeSleepMinutes: awakeMins,
            stepCount: stepCount
        )
    }
    
    // MARK: - Query Helpers
    
    private func fetchLatestQuantitySample(for type: HKQuantityType, unit: HKUnit) async -> Double? {
        return await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
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
}
