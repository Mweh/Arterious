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
