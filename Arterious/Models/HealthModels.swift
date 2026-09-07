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
    var latestHeartRate: Double?
    var latestHeartRateDate: Date?
    var isWorkoutActive: Bool = false
    var recentWorkoutName: String? = nil
    var restingHeartRate: Double?
    var stepCount: Double?
    var sleepHours: Double?
    var sleepDetails: SleepDetails?
    
    static var placeholder: DailyHealthSummary {
        DailyHealthSummary(
            date: Date(),
            latestHeartRate: 74,
            latestHeartRateDate: Date(),
            isWorkoutActive: false,
            recentWorkoutName: nil,
            restingHeartRate: 64,
            stepCount: 4200,
            sleepHours: 7.2,
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
            )
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
