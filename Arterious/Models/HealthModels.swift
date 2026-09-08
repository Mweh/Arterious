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

struct DailyHealthSummary: Identifiable {
    var id: Date { date }
    let date: Date
    
    // Heart & HRV Metrics
    var latestHeartRate: Double?
    var restingHeartRate: Double?
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
    
    // Activity Metrics
    var stepCount: Double?
    var activeMinutesToday: Double?
    var exerciseMinutesWeek: Double?
    var activeEnergyKcalToday: Double?
    var standHoursToday: Int?
    
    static var placeholder: DailyHealthSummary {
        DailyHealthSummary(
            date: Date(),
            latestHeartRate: 72,
            restingHeartRate: 64,
            meanHeartRate24h: 70,
            heartRateSD24h: 8.5,
            maxHeartRate24h: 112,
            hrvSDNN14DayMean: 48,
            hrvRMSSD: 42,
            hrvDropFromBaseline: -2.5,
            sleepHours: 7.2,
            sleepEfficiency: 88,
            deepSleepPercentage: 22,
            remSleepPercentage: 24,
            sleepBedtimeSDMinutes: 18,
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

// MARK: - HealthRecord (Structured CloudKit & Local Model)

struct HealthRecord: Codable, Identifiable {
    var id: String { "\(inviteCode)_\(formattedDate)" }
    let inviteCode: String
    let recordDate: Date
    let parentName: String

    // Heart Rate
    let restingHeartRate: Double?
    let heartRateStatus: String // e.g. "Dalam rentang normal"
    let recentHeartRatePoints: [Double] // 5-7 points for mini sparkline

    // Sleep
    let sleepHours: Double?
    let sleepFormatted: String // e.g. "7j 40m"
    let sleepStatus: String // e.g. "Kualitas tidur baik"
    let recentSleepPoints: [Double]

    // Activity
    let stepCount: Int?
    let stepFormatted: String // e.g. "4.280"
    let activityStatus: String // e.g. "Lebih baik dari biasanya"
    let recentStepPoints: [Double]

    // Summary Insights
    let summaryTitle: String // e.g. "Kondisi cukup stabil"
    let summaryBody: String // e.g. "Pola tidur baik, detak jantung dalam rentang normal, dan aktivitas sedikit lebih baik dari biasanya."

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
            summaryTitle: "Kondisi cukup stabil",
            summaryBody: "Pola tidur baik, detak jantung dalam rentang normal, dan aktivitas sedikit lebih baik dari biasanya.",
            updatedAt: Date()
        )
    }

    static func create(
        from summary: DailyHealthSummary,
        inviteCode: String,
        parentName: String,
        history: [DailyHealthSummary] = []
    ) -> HealthRecord {
        let rhr = summary.restingHeartRate ?? 70
        let rhrStatus = rhr < 60 ? "Sedikit rendah" : (rhr > 85 ? "Sedikit tinggi" : "Dalam rentang normal")

        let sleep = summary.sleepHours ?? 7.0
        let hours = Int(sleep)
        let mins = Int((sleep - Double(hours)) * 60)
        let sleepFormatted = "\(hours)j \(mins)m"
        let sleepStatus = sleep >= 7.0 ? "Kualitas tidur baik" : "Perlu istirahat lebih"

        let steps = Int(summary.stepCount ?? 4000)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        let stepFormatted = formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
        let actStatus = steps >= 4000 ? "Lebih baik dari biasanya" : "Cenderung santai hari ini"

        // Sparklines
        var hrPoints: [Double] = history.compactMap(\.restingHeartRate).suffix(6)
        if let r = summary.restingHeartRate { hrPoints.append(r) }
        if hrPoints.count < 3 { hrPoints = [68, 70, 72, 71, 72] }

        var sleepPoints: [Double] = history.compactMap(\.sleepHours).suffix(6)
        if let s = summary.sleepHours { sleepPoints.append(s) }
        if sleepPoints.count < 3 { sleepPoints = [7.0, 7.2, 7.5, 7.6] }

        var stepPoints: [Double] = history.compactMap(\.stepCount).suffix(6)
        if let st = summary.stepCount { stepPoints.append(st) }
        if stepPoints.count < 3 { stepPoints = [3500, 4000, 4200, 4280] }

        return HealthRecord(
            inviteCode: inviteCode,
            recordDate: summary.date,
            parentName: parentName,
            restingHeartRate: summary.restingHeartRate,
            heartRateStatus: rhrStatus,
            recentHeartRatePoints: hrPoints,
            sleepHours: summary.sleepHours,
            sleepFormatted: sleepFormatted,
            sleepStatus: sleepStatus,
            recentSleepPoints: sleepPoints,
            stepCount: steps,
            stepFormatted: stepFormatted,
            activityStatus: actStatus,
            recentStepPoints: stepPoints,
            summaryTitle: "Kondisi cukup stabil",
            summaryBody: "Pola tidur baik, detak jantung dalam rentang normal, dan aktivitas sedikit lebih baik dari biasanya.",
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
        case latestHeartRate, restingHeartRate, meanHeartRate24h, heartRateSD24h, maxHeartRate24h
        case hrvSDNN14DayMean, hrvRMSSD, hrvDropFromBaseline
        case sleepHours, sleepEfficiency, deepSleepPercentage, remSleepPercentage, sleepBedtimeSDMinutes
        case stepCount, activeMinutesToday, exerciseMinutesWeek, activeEnergyKcalToday, standHoursToday
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decode(Date.self, forKey: .date)
        latestHeartRate = try c.decodeIfPresent(Double.self, forKey: .latestHeartRate)
        restingHeartRate = try c.decodeIfPresent(Double.self, forKey: .restingHeartRate)
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
        try c.encodeIfPresent(restingHeartRate, forKey: .restingHeartRate)
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
        try c.encodeIfPresent(stepCount, forKey: .stepCount)
        try c.encodeIfPresent(activeMinutesToday, forKey: .activeMinutesToday)
        try c.encodeIfPresent(exerciseMinutesWeek, forKey: .exerciseMinutesWeek)
        try c.encodeIfPresent(activeEnergyKcalToday, forKey: .activeEnergyKcalToday)
        try c.encodeIfPresent(standHoursToday, forKey: .standHoursToday)
    }
}
