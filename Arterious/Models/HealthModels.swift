import Foundation

enum MetricType: String, CaseIterable, Identifiable {
    case heartRate = "Heart Rate"
    case restingHeartRate = "Resting Heart Rate"
    case steps = "Steps"
    case sleep = "Sleep Duration"
    
    var id: String { rawValue }
    
    var unitString: String {
        switch self {
        case .heartRate, .restingHeartRate:
            return "BPM"
        case .steps:
            return "steps"
        case .sleep:
            return "hrs"
        }
    }
    
    var iconName: String {
        switch self {
        case .heartRate:
            return "heart.fill"
        case .restingHeartRate:
            return "waveform.path.ecg"
        case .steps:
            return "figure.walk"
        case .sleep:
            return "bed.double.fill"
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
    var latestHeartRate: Double?
    var restingHeartRate: Double?
    var stepCount: Double?
    var sleepHours: Double?
    
    static var placeholder: DailyHealthSummary {
        DailyHealthSummary(
            date: Date(),
            latestHeartRate: 72,
            restingHeartRate: 64,
            stepCount: 4200,
            sleepHours: 7.2
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
