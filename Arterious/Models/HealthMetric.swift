import Foundation
import CloudKit

/// A domain model representing a health metric record stored in CloudKit.
struct HealthMetric: Identifiable {

    let id: CKRecord.ID
    let type: String
    let value: Double
    let date: Date

    init(
        id: CKRecord.ID = CKRecord.ID(recordName: UUID().uuidString),
        type: String,
        value: Double,
        date: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.value = value
        self.date = date
    }

    /// Converts a CloudKit `CKRecord` to a `HealthMetric`.
    init?(record: CKRecord) {
        guard let type = record["type"] as? String,
              let value = record["value"] as? Double,
              let date = record["date"] as? Date else {
            return nil
        }

        self.id = record.recordID
        self.type = type
        self.value = value
        self.date = date
    }

    /// Formatted value string for UI display.
    var formattedValue: String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
}
