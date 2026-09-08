import Foundation
import CloudKit

/// A domain model representing a parent's daily health summary.
struct DailyHealth: Identifiable {

    let id: String
    let date: Date
    let heartRate: Double
    let steps: Int64
    let sleepDuration: Double

    init(
        id: String = UUID().uuidString,
        date: Date = Date(),
        heartRate: Double,
        steps: Int64,
        sleepDuration: Double
    ) {
        self.id = id
        self.date = date
        self.heartRate = heartRate
        self.steps = steps
        self.sleepDuration = sleepDuration
    }

    /// Converts a CloudKit `CKRecord` to `DailyHealth`.
    init?(record: CKRecord) {
        guard let date = record["date"] as? Date,
              let heartRate = record["heartRate"] as? Double,
              let steps = record["steps"] as? Int64,
              let sleepDuration = record["sleepDuration"] as? Double else {
            return nil
        }

        self.id = record.recordID.recordName
        self.date = date
        self.heartRate = heartRate
        self.steps = steps
        self.sleepDuration = sleepDuration
    }

    // MARK: - UI Formatting Helpers

    var formattedHeartRate: String {
        "\(Int(heartRate.rounded())) BPM"
    }

    var formattedSteps: String {
        "\(steps.formatted()) steps"
    }

    var formattedSleepDuration: String {
        String(format: "%.1f hrs", sleepDuration)
    }
}
