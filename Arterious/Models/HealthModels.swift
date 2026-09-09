import Foundation

enum MetricType: String, CaseIterable, Identifiable {
    // Heart & HRV
    case heartRate = "Heart Rate"
    case restingHeartRate = "Resting Heart Rate"
    case meanHeartRate24h = "24h Mean HR"
    case heartRateSD24h = "24h HR SD"
    case maxHeartRate24h = "Max HR (Awake)"
    case hrvSDNN14DayMean = "14d HRV SDNN"
    case hrvRMSSD = "HRV RMSSD"
    case hrvDropFromBaseline = "HRV Drop"
    
    // Sleep
    case sleep = "Sleep Duration"
    case sleepEfficiency = "Sleep Efficiency"
    case deepSleepPercentage = "Deep Sleep %"
    case remSleepPercentage = "REM Sleep %"
    case sleepConsistency = "Bedtime Consistency"
    
    // Activity
    case steps = "Daily Steps"
    case activeMinutes = "Active Minutes"
    case exerciseMinutesWeek = "Exercise / Week"
    case activeEnergy = "Active Energy"
    case standHours = "Stand Hours"
    
    var id: String { rawValue }
    
    var unitString: String {
        switch self {
        case .heartRate, .restingHeartRate, .meanHeartRate24h, .heartRateSD24h, .maxHeartRate24h:
            return "BPM"
        case .hrvSDNN14DayMean, .hrvRMSSD, .hrvDropFromBaseline:
            return "ms"
        case .sleep:
            return "hrs"
        case .sleepEfficiency, .deepSleepPercentage, .remSleepPercentage:
            return "%"
        case .sleepConsistency, .activeMinutes, .exerciseMinutesWeek:
            return "mins"
        case .steps:
            return "steps"
        case .activeEnergy:
            return "kcal"
        case .standHours:
            return "hrs"
        }
    }
    
    var iconName: String {
        switch self {
        case .heartRate:
            return "heart.fill"
        case .restingHeartRate:
            return "waveform.path.ecg"
        case .meanHeartRate24h:
            return "heart.square.fill"
        case .heartRateSD24h:
            return "chart.bar.fill"
        case .maxHeartRate24h:
            return "bolt.heart.fill"
        case .hrvSDNN14DayMean:
            return "heart.text.square.fill"
        case .hrvRMSSD:
            return "waveform.path.ecg.profile"
        case .hrvDropFromBaseline:
            return "arrow.down.heart.fill"
        case .sleep:
            return "bed.double.fill"
        case .sleepEfficiency:
            return "percent"
        case .deepSleepPercentage:
            return "moon.fill"
        case .remSleepPercentage:
            return "brain.head.profile"
        case .sleepConsistency:
            return "clock.arrow.2.circlepath"
        case .steps:
            return "figure.walk"
        case .activeMinutes:
            return "timer"
        case .exerciseMinutesWeek:
            return "figure.run"
        case .activeEnergy:
            return "flame.fill"
        case .standHours:
            return "figure.stand"
        }
    }
}

enum WellnessStatus: String {
    case good = "Steady & Well"
    case fair = "Minor Changes"
    case needsAttention = "Worth Checking In"
    
    var iconName: String {
        switch self {
        case .good:
            return "checkmark.circle.fill"
        case .fair:
            return "info.circle.fill"
        case .needsAttention:
            return "exclamationmark.triangle.fill"
        }
    }
}

/// Episode terbangun di malam hari
struct AwakeEpisode: Codable, Identifiable {
    var id: String { "\(startTimeFormatted)-\(durationMinutes)" }
    let startTimeFormatted: String // Contoh: "02:30"
    let durationMinutes: Int       // Contoh: 25
}

/// Rincian metrik tidur semalam sesuai standar HealthKit & PRD §5.1, §7.1
struct SleepDetails: Codable {
    let bedtime: Date?
    let wakeTime: Date?
    let totalSleepMinutes: Double
    let timeInBedMinutes: Double
    let sleepEfficiency: Double     // Persentase (totalSleep / timeInBed) * 100
    let awakeMinutes: Double
    let awakeEpisodes: [AwakeEpisode]
    let remMinutes: Double?
    let coreMinutes: Double?
    let deepMinutes: Double?
    
    var formattedBedtime: String {
        guard let bedtime = bedtime else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: bedtime)
    }
    
    var formattedWakeTime: String {
        guard let wakeTime = wakeTime else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: wakeTime)
    }
    
    var formattedEfficiency: String {
        String(format: "%.1f%%", sleepEfficiency)
    }
}

struct DailyHealthSummary: Identifiable {
    var id: Date { date }
    let date: Date
    
    // Heart & HRV Metrics
    var latestHeartRate: Double?
    var latestHeartRateDate: Date?
    var isWorkoutActive: Bool = false
    var recentWorkoutName: String? = nil
    var restingHeartRate: Double?
    var minHeartRate24h: Double?
    var meanHeartRate24h: Double?
    var heartRateSD24h: Double?
    var maxHeartRate24h: Double?
    var hrvSDNN14DayMean: Double?
    var hrvRMSSD: Double?
    var hrvDropFromBaseline: Double?
    
    // Sleep Metrics
    var sleepHours: Double?
    var sleepEfficiency: Double?
    var deepSleepPercentage: Double?
    var remSleepPercentage: Double?
    var sleepBedtimeSDMinutes: Double?
    var deepSleepMinutes: Double?
    var remSleepMinutes: Double?
    var coreSleepMinutes: Double?
    var awakeSleepMinutes: Double?
    var sleepDetails: SleepDetails?
    
    // Activity Metrics
    var stepCount: Double?
    var activeMinutesToday: Double?
    var exerciseMinutesWeek: Double?
    var activeEnergyKcalToday: Double?
    var standHoursToday: Int?
    
    static var empty: DailyHealthSummary {
        DailyHealthSummary(date: Date())
    }

    static var placeholder: DailyHealthSummary {
        DailyHealthSummary(
            date: Date(),
            latestHeartRate: 74,
            latestHeartRateDate: Date(),
            isWorkoutActive: false,
            recentWorkoutName: nil,
            restingHeartRate: 64,
            meanHeartRate24h: 70,
            heartRateSD24h: 8.5,
            maxHeartRate24h: 112,
            hrvSDNN14DayMean: 48,
            hrvRMSSD: 42,
            hrvDropFromBaseline: -2.5,
            sleepHours: 7.2,
            sleepEfficiency: 88.4,
            deepSleepPercentage: 22,
            remSleepPercentage: 24,
            sleepBedtimeSDMinutes: 18,
            deepSleepMinutes: 70,
            remSleepMinutes: 90,
            coreSleepMinutes: 240,
            awakeSleepMinutes: 35,
            sleepDetails: SleepDetails(
                bedtime: Calendar.current.date(bySettingHour: 22, minute: 45, second: 0, of: Date()),
                wakeTime: Calendar.current.date(bySettingHour: 6, minute: 10, second: 0, of: Date()),
                totalSleepMinutes: 432,
                timeInBedMinutes: 445,
                sleepEfficiency: 88.4,
                awakeMinutes: 35,
                awakeEpisodes: [
                    AwakeEpisode(startTimeFormatted: "02:40", durationMinutes: 20)
                ],
                remMinutes: 90,
                coreMinutes: 240,
                deepMinutes: 70
            ),
            stepCount: 4200,
            activeMinutesToday: 35,
            exerciseMinutesWeek: 140,
            activeEnergyKcalToday: 320,
            standHoursToday: 10
        )
    }
}

struct HealthTrend: Identifiable {
    var id: MetricType { metric }
    let metric: MetricType
    let baselineValue: Double
    let currentValue: Double
    let percentageChange: Double
    let isSignificantDeviation: Bool
}

struct CautionInsight: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let suggestedAction: String
    let dateDetected: Date
}

struct ParentProfile: Identifiable {
    let id = UUID()
    var name: String
    var relationship: String
    var age: Int
}

/// Model representasi data Baseline 14 Hari yang dihitung dari Apple HealthKit
struct HealthBaseline {
    let periodDays: Int = 14
    let steps: Double               // Rata-rata langkah 14 hari
    let sleepHours: Double          // Rata-rata tidur (jam) 14 hari
    let restingHeartRate: Double    // Rata-rata resting heart rate 14 hari
    var sleepEfficiency: Double = 88.4   // Median efisiensi tidur (%) dari baseline PRD
    var awakeMinutes: Double = 50.0      // Median waktu terbangun (menit) dari baseline PRD
    var bedtimeString: String = "22:45"  // Median jam tidur dari baseline PRD
    var wakeTimeString: String = "06:10" // Median jam bangun dari baseline PRD
    
    var formattedSteps: String { "\(Int(steps)) langkah" }
    var formattedSleep: String { String(format: "%.1f jam", sleepHours) }
    var formattedRHR: String { "\(Int(restingHeartRate)) BPM" }
    var formattedEfficiency: String { String(format: "%.1f%%", sleepEfficiency) }
}

// MARK: - HealthRecord (Structured CloudKit & Local Model)

struct HealthRecord: Codable, Identifiable {
    var id: String { "\(inviteCode)_\(formattedDate)" }
    let inviteCode: String
    let recordDate: Date
    let parentName: String

    // Heart Rate (Regular Heart Rate is primary)
    let heartRate: Double?
    let restingHeartRate: Double?
    let heartRateStatus: String // e.g. "Dalam rentang normal"
    let recentHeartRatePoints: [Double] // 5-7 points for mini sparkline

    var displayHeartRate: Double? {
        heartRate ?? restingHeartRate
    }

    // Sleep
    let sleepHours: Double?
    let sleepFormatted: String // e.g. "7j 40m"
    let sleepStatus: String // e.g. "Kualitas tidur baik"
    let recentSleepPoints: [Double]

    // Activity / Steps
    let stepCount: Int?
    let stepFormatted: String // e.g. "4.280"
    let activityStatus: String // e.g. "Lebih baik dari biasanya"
    let recentStepPoints: [Double]

    // Summary Insights
    let summaryTitle: String // e.g. "Kondisi terpantau"
    let summaryBody: String // e.g. "Detak jantung, waktu tidur, dan jumlah langkah hari ini tercatat dari Apple Health."

    let updatedAt: Date

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: recordDate)
    }

    var displayDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: recordDate)
    }

    static var previewMock: HealthRecord {
        HealthRecord(
            inviteCode: "SAMPLE",
            recordDate: Date(),
            parentName: "Nama Ortu 1",
            heartRate: 72,
            restingHeartRate: 72,
            heartRateStatus: "Dalam rentang normal",
            recentHeartRatePoints: [70, 71, 68, 73, 75, 72, 72],
            sleepHours: 7.66,
            sleepFormatted: "7j 40m",
            sleepStatus: "Kualitas tidur baik",
            recentSleepPoints: [6.8, 7.2, 8.0, 7.5, 7.1, 7.8, 7.66],
            stepCount: 4280,
            stepFormatted: "4.280",
            activityStatus: "Lebih baik dari biasanya",
            recentStepPoints: [3800, 4100, 4500, 3900, 4200, 4300, 4280],
            summaryTitle: "Kondisi terpantau",
            summaryBody: "Detak jantung, waktu tidur, dan jumlah langkah hari ini tercatat dari Apple Health.",
            updatedAt: Date()
        )
    }

    static func create(
        from summary: DailyHealthSummary,
        inviteCode: String,
        parentName: String,
        history: [DailyHealthSummary] = []
    ) -> HealthRecord {
        // 1. Heart Rate (Utamakan regular Heart Rate, fallback ke resting)
        let hr = summary.latestHeartRate ?? summary.restingHeartRate
        let hrStatus: String
        if let h = hr {
            hrStatus = h < 60 ? "Sedikit rendah" : (h > 100 ? "Sedikit tinggi" : "Dalam rentang normal")
        } else {
            hrStatus = "Belum ada data"
        }

        // 2. Sleep
        let sleep = summary.sleepHours
        let sleepFormatted: String
        let sleepStatus: String
        if let s = sleep, s > 0 {
            let hours = Int(s)
            let mins = Int(((s - Double(hours)) * 60).rounded())
            sleepFormatted = "\(hours)j \(mins)m"
            sleepStatus = s >= 7.0 ? "Kualitas tidur baik" : "Perlu istirahat lebih"
        } else {
            sleepFormatted = "-"
            sleepStatus = "Belum ada data"
        }

        // 3. Step Count
        let steps = summary.stepCount.map { Int($0) }
        let stepFormatted: String
        let actStatus: String
        if let st = steps {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = "."
            stepFormatted = formatter.string(from: NSNumber(value: st)) ?? "\(st)"
            actStatus = st >= 4000 ? "Lebih baik dari biasanya" : (st > 0 ? "Cenderung santai hari ini" : "Belum mulai beraktivitas")
        } else {
            stepFormatted = "-"
            actStatus = "Belum ada data"
        }

        // Sparklines: Real points only!
        var hrPoints: [Double] = history.compactMap { $0.latestHeartRate ?? $0.restingHeartRate }
        if let h = hr { hrPoints.append(h) }

        var sleepPoints: [Double] = history.compactMap(\.sleepHours)
        if let s = sleep, s > 0 { sleepPoints.append(s) }

        var stepPoints: [Double] = history.compactMap(\.stepCount)
        if let st = summary.stepCount { stepPoints.append(st) }

        let hasAnyData = (hr != nil) || (sleep != nil && sleep! > 0) || (steps != nil)
        let sumTitle = hasAnyData ? "Kondisi terpantau" : "Belum ada data hari ini"
        let sumBody = hasAnyData
            ? "Detak jantung, waktu tidur, dan jumlah langkah hari ini tercatat dari Apple Health."
            : "Data detak jantung, tidur, dan langkah belum tersedia di Apple Health hari ini."

        return HealthRecord(
            inviteCode: inviteCode,
            recordDate: summary.date,
            parentName: parentName,
            heartRate: hr,
            restingHeartRate: summary.restingHeartRate ?? hr,
            heartRateStatus: hrStatus,
            recentHeartRatePoints: hrPoints,
            sleepHours: sleep,
            sleepFormatted: sleepFormatted,
            sleepStatus: sleepStatus,
            recentSleepPoints: sleepPoints,
            stepCount: steps,
            stepFormatted: stepFormatted,
            activityStatus: actStatus,
            recentStepPoints: stepPoints,
            summaryTitle: sumTitle,
            summaryBody: sumBody,
            updatedAt: Date()
        )
    }
}

// MARK: - Sync Models

enum SyncRole: String, Codable {
    case child
    case parent
    case unset
}

enum SyncStatus: String, Codable {
    case none
    case pending
    case accepted
}

struct SyncState: Codable {
    var role: SyncRole
    var inviteCode: String?
    var status: SyncStatus
    var partnerName: String?
    var lastSyncDate: Date?
    
    static var empty: SyncState {
        SyncState(role: .unset, inviteCode: nil, status: .none, partnerName: nil, lastSyncDate: nil)
    }
}

// MARK: - DailyHealthSummary Codable

extension DailyHealthSummary: Codable {
    enum CodingKeys: String, CodingKey {
        case date
        case latestHeartRate, latestHeartRateDate, isWorkoutActive, recentWorkoutName, restingHeartRate, minHeartRate24h, meanHeartRate24h, heartRateSD24h, maxHeartRate24h
        case hrvSDNN14DayMean, hrvRMSSD, hrvDropFromBaseline
        case sleepHours, sleepEfficiency, deepSleepPercentage, remSleepPercentage, sleepBedtimeSDMinutes
        case deepSleepMinutes, remSleepMinutes, coreSleepMinutes, awakeSleepMinutes, sleepDetails
        case stepCount, activeMinutesToday, exerciseMinutesWeek, activeEnergyKcalToday, standHoursToday
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decode(Date.self, forKey: .date)
        latestHeartRate = try c.decodeIfPresent(Double.self, forKey: .latestHeartRate)
        latestHeartRateDate = try c.decodeIfPresent(Date.self, forKey: .latestHeartRateDate)
        isWorkoutActive = try c.decodeIfPresent(Bool.self, forKey: .isWorkoutActive) ?? false
        recentWorkoutName = try c.decodeIfPresent(String.self, forKey: .recentWorkoutName)
        restingHeartRate = try c.decodeIfPresent(Double.self, forKey: .restingHeartRate)
        minHeartRate24h = try c.decodeIfPresent(Double.self, forKey: .minHeartRate24h)
        meanHeartRate24h = try c.decodeIfPresent(Double.self, forKey: .meanHeartRate24h)
        heartRateSD24h = try c.decodeIfPresent(Double.self, forKey: .heartRateSD24h)
        maxHeartRate24h = try c.decodeIfPresent(Double.self, forKey: .maxHeartRate24h)
        hrvSDNN14DayMean = try c.decodeIfPresent(Double.self, forKey: .hrvSDNN14DayMean)
        hrvRMSSD = try c.decodeIfPresent(Double.self, forKey: .hrvRMSSD)
        hrvDropFromBaseline = try c.decodeIfPresent(Double.self, forKey: .hrvDropFromBaseline)
        sleepHours = try c.decodeIfPresent(Double.self, forKey: .sleepHours)
        sleepEfficiency = try c.decodeIfPresent(Double.self, forKey: .sleepEfficiency)
        deepSleepPercentage = try c.decodeIfPresent(Double.self, forKey: .deepSleepPercentage)
        remSleepPercentage = try c.decodeIfPresent(Double.self, forKey: .remSleepPercentage)
        sleepBedtimeSDMinutes = try c.decodeIfPresent(Double.self, forKey: .sleepBedtimeSDMinutes)
        deepSleepMinutes = try c.decodeIfPresent(Double.self, forKey: .deepSleepMinutes)
        remSleepMinutes = try c.decodeIfPresent(Double.self, forKey: .remSleepMinutes)
        coreSleepMinutes = try c.decodeIfPresent(Double.self, forKey: .coreSleepMinutes)
        awakeSleepMinutes = try c.decodeIfPresent(Double.self, forKey: .awakeSleepMinutes)
        sleepDetails = try c.decodeIfPresent(SleepDetails.self, forKey: .sleepDetails)
        stepCount = try c.decodeIfPresent(Double.self, forKey: .stepCount)
        activeMinutesToday = try c.decodeIfPresent(Double.self, forKey: .activeMinutesToday)
        exerciseMinutesWeek = try c.decodeIfPresent(Double.self, forKey: .exerciseMinutesWeek)
        activeEnergyKcalToday = try c.decodeIfPresent(Double.self, forKey: .activeEnergyKcalToday)
        standHoursToday = try c.decodeIfPresent(Int.self, forKey: .standHoursToday)
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(date, forKey: .date)
        try c.encodeIfPresent(latestHeartRate, forKey: .latestHeartRate)
        try c.encodeIfPresent(latestHeartRateDate, forKey: .latestHeartRateDate)
        try c.encode(isWorkoutActive, forKey: .isWorkoutActive)
        try c.encodeIfPresent(recentWorkoutName, forKey: .recentWorkoutName)
        try c.encodeIfPresent(restingHeartRate, forKey: .restingHeartRate)
        try c.encodeIfPresent(minHeartRate24h, forKey: .minHeartRate24h)
        try c.encodeIfPresent(meanHeartRate24h, forKey: .meanHeartRate24h)
        try c.encodeIfPresent(heartRateSD24h, forKey: .heartRateSD24h)
        try c.encodeIfPresent(maxHeartRate24h, forKey: .maxHeartRate24h)
        try c.encodeIfPresent(hrvSDNN14DayMean, forKey: .hrvSDNN14DayMean)
        try c.encodeIfPresent(hrvRMSSD, forKey: .hrvRMSSD)
        try c.encodeIfPresent(hrvDropFromBaseline, forKey: .hrvDropFromBaseline)
        try c.encodeIfPresent(sleepHours, forKey: .sleepHours)
        try c.encodeIfPresent(sleepEfficiency, forKey: .sleepEfficiency)
        try c.encodeIfPresent(deepSleepPercentage, forKey: .deepSleepPercentage)
        try c.encodeIfPresent(remSleepPercentage, forKey: .remSleepPercentage)
        try c.encodeIfPresent(sleepBedtimeSDMinutes, forKey: .sleepBedtimeSDMinutes)
        try c.encodeIfPresent(deepSleepMinutes, forKey: .deepSleepMinutes)
        try c.encodeIfPresent(remSleepMinutes, forKey: .remSleepMinutes)
        try c.encodeIfPresent(coreSleepMinutes, forKey: .coreSleepMinutes)
        try c.encodeIfPresent(awakeSleepMinutes, forKey: .awakeSleepMinutes)
        try c.encodeIfPresent(sleepDetails, forKey: .sleepDetails)
        try c.encodeIfPresent(stepCount, forKey: .stepCount)
        try c.encodeIfPresent(activeMinutesToday, forKey: .activeMinutesToday)
        try c.encodeIfPresent(exerciseMinutesWeek, forKey: .exerciseMinutesWeek)
        try c.encodeIfPresent(activeEnergyKcalToday, forKey: .activeEnergyKcalToday)
        try c.encodeIfPresent(standHoursToday, forKey: .standHoursToday)
    }
}
