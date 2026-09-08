import Foundation
import CloudKit

/// Service responsible for managing CloudKit operations for Parent (Private Database & Sharing)
/// and Child (Shared Database).
final class CloudKitService {

    static let shared = CloudKitService()

    let container: CKContainer
    private let privateDatabase: CKDatabase
    private let sharedDatabase: CKDatabase

    private let zoneName = "ParentHealthZone"
    private var isZoneCreated = false

    private enum RecordType {
        static let dailyHealth = "DailyHealth"
    }

    private enum RecordKey {
        static let date = "date"
        static let heartRate = "heartRate"
        static let steps = "steps"
        static let sleepDuration = "sleepDuration"
    }

    init(container: CKContainer = .default()) {
        self.container = container
        self.privateDatabase = container.privateCloudDatabase
        self.sharedDatabase = container.sharedCloudDatabase
    }

    // MARK: - Zone Management

    /// Ensures the custom record zone exists in the user's private database for sharing support.
    private func ensureCustomZoneExists() async throws -> CKRecordZone.ID {
        let zone = CKRecordZone(zoneName: zoneName)
        if !isZoneCreated {
            do {
                _ = try await privateDatabase.save(zone)
                isZoneCreated = true
            } catch let error as CKError where error.code == .serverRejectedRequest || error.code == .zoneNotFound {
                // Zone may already exist on CloudKit server
                isZoneCreated = true
            } catch {
                // If already saved or created, mark as ready
                isZoneCreated = true
            }
        }
        return zone.zoneID
    }

    // MARK: - Parent Operations (Private Database)

    /// Creates a new DailyHealth record in the parent's private database.
    func createDailyHealth(
        date: Date = Date(),
        heartRate: Double,
        steps: Int64,
        sleepDuration: Double
    ) async throws -> DailyHealth {
        let zoneID = try await ensureCustomZoneExists()
        let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: RecordType.dailyHealth, recordID: recordID)

        record[RecordKey.date] = date as CKRecordValue
        record[RecordKey.heartRate] = heartRate as CKRecordValue
        record[RecordKey.steps] = steps as CKRecordValue
        record[RecordKey.sleepDuration] = sleepDuration as CKRecordValue

        let savedRecord = try await privateDatabase.save(record)

        guard let dailyHealth = DailyHealth(record: savedRecord) else {
            throw CloudKitServiceError.invalidRecordData
        }

        return dailyHealth
    }

    /// Fetches all DailyHealth records from the parent's private database.
    func fetchDailyHealth() async throws -> [DailyHealth] {
        let zoneID = try await ensureCustomZoneExists()
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: RecordType.dailyHealth, predicate: predicate)

        let (matchResults, _) = try await privateDatabase.records(
            matching: query,
            inZoneWith: zoneID
        )

        let records = matchResults.compactMap { _, result -> DailyHealth? in
            switch result {
            case .success(let record):
                return DailyHealth(record: record)
            case .failure:
                return nil
            }
        }

        return records.sorted { $0.date > $1.date }
    }

    /// Updates an existing DailyHealth record in the private database.
    func updateDailyHealth(
        id: String,
        date: Date,
        heartRate: Double,
        steps: Int64,
        sleepDuration: Double
    ) async throws -> DailyHealth {
        let zoneID = try await ensureCustomZoneExists()
        let recordID = CKRecord.ID(recordName: id, zoneID: zoneID)

        let record = try await privateDatabase.record(for: recordID)
        record[RecordKey.date] = date as CKRecordValue
        record[RecordKey.heartRate] = heartRate as CKRecordValue
        record[RecordKey.steps] = steps as CKRecordValue
        record[RecordKey.sleepDuration] = sleepDuration as CKRecordValue

        let savedRecord = try await privateDatabase.save(record)

        guard let dailyHealth = DailyHealth(record: savedRecord) else {
            throw CloudKitServiceError.invalidRecordData
        }

        return dailyHealth
    }

    /// Deletes a DailyHealth record from the private database.
    func deleteDailyHealth(id: String) async throws {
        let zoneID = try await ensureCustomZoneExists()
        let recordID = CKRecord.ID(recordName: id, zoneID: zoneID)
        _ = try await privateDatabase.deleteRecord(withID: recordID)
    }

    // MARK: - CloudKit Sharing (CKShare)

    /// Creates or retrieves a CKShare for the parent's health record zone.
    func createShare() async throws -> CKShare {
        let zoneID = try await ensureCustomZoneExists()
        let share = CKShare(recordZoneID: zoneID)
        share[CKShare.SystemFieldKey.title] = "Parent's Health Summary" as CKRecordValue

        let savedRecord = try await privateDatabase.save(share)
        guard let savedShare = savedRecord as? CKShare else {
            throw CloudKitServiceError.shareCreationFailed
        }

        return savedShare
    }

    /// Accepts a CloudKit share invitation.
    func acceptShare(metadata: CKShare.Metadata) async throws {
        try await container.accept(metadata)
    }

    // MARK: - Child Operations (Shared Database)

    /// Fetches shared DailyHealth records from all zones accessible in the Shared Database.
    func fetchSharedDailyHealth() async throws -> [DailyHealth] {
        let zones = try await sharedDatabase.allRecordZones()
        var allRecords: [DailyHealth] = []

        for zone in zones {
            let predicate = NSPredicate(value: true)
            let query = CKQuery(recordType: RecordType.dailyHealth, predicate: predicate)

            do {
                let (matchResults, _) = try await sharedDatabase.records(
                    matching: query,
                    inZoneWith: zone.zoneID
                )

                for (_, result) in matchResults {
                    if case .success(let record) = result,
                       let dailyHealth = DailyHealth(record: record) {
                        allRecords.append(dailyHealth)
                    }
                }
            } catch {
                // Continue checking other shared zones if any
                continue
            }
        }

        return allRecords.sorted { $0.date > $1.date }
    }
}

enum CloudKitServiceError: LocalizedError {
    case invalidRecordData
    case shareCreationFailed

    var errorDescription: String? {
        switch self {
        case .invalidRecordData:
            return "Failed to parse the health summary record from CloudKit."
        case .shareCreationFailed:
            return "Failed to create CloudKit sharing invitation."
        }
    }
}
