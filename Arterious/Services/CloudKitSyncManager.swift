import Foundation
import CloudKit
import UIKit

// MARK: - CloudKit Record Type Constants

private enum CKRecordType {
    static let sharingInvite = "SharingInvite"
    static let parentHealthSnapshot = "ParentHealthSnapshot"
    static let healthRecord = "HealthRecord"
}

private enum CKField {
    // SharingInvite
    static let inviteCode = "inviteCode"
    static let status = "status"
    static let childDeviceID = "childDeviceID"
    // ParentHealthSnapshot
    static let snapshotJSON = "snapshotJSON"
    static let parentName = "parentName"
    static let updatedAt = "updatedAt"
    // HealthRecord
    static let recordDate = "recordDate"
    static let restingHeartRate = "restingHeartRate"
    static let heartRateStatus = "heartRateStatus"
    static let recentHeartRatePoints = "recentHeartRatePoints"
    static let sleepHours = "sleepHours"
    static let sleepFormatted = "sleepFormatted"
    static let sleepStatus = "sleepStatus"
    static let recentSleepPoints = "recentSleepPoints"
    static let stepCount = "stepCount"
    static let stepFormatted = "stepFormatted"
    static let activityStatus = "activityStatus"
    static let recentStepPoints = "recentStepPoints"
    static let summaryTitle = "summaryTitle"
    static let summaryBody = "summaryBody"
}

private let subscriptionID = "parent-health-updates"

// MARK: - CloudKitSyncManager

final class CloudKitSyncManager {
    static let shared = CloudKitSyncManager()

    private let container: CKContainer
    private let publicDB: CKDatabase
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        container = CKContainer(identifier: "iCloud.com.helloworld.arterious")
        publicDB = container.publicCloudDatabase
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Child: Generate Invite Link

    /// Creates a SharingInvite record in CloudKit and returns a deep link URL.
    func generateInviteLink() async throws -> URL {
        let code = generateCode()
        let record = CKRecord(recordType: CKRecordType.sharingInvite)
        record[CKField.inviteCode] = code
        record[CKField.status] = "pending"
        record[CKField.childDeviceID] = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"

        _ = try await publicDB.save(record)

        guard let url = URL(string: "arterious://invite?code=\(code)") else {
            throw SyncError.invalidURL
        }
        return url
    }

    // MARK: - Parent: Accept Invite

    /// Looks up a SharingInvite by code and marks it accepted.
    func acceptInvite(code: String) async throws {
        let record = try await fetchInviteRecord(code: code)
        record[CKField.status] = "accepted"
        _ = try await publicDB.save(record)
    }

    // MARK: - Parent: Push Health Snapshot

    /// Encodes a DailyHealthSummary as JSON and saves/updates a ParentHealthSnapshot record.
    func pushHealthSnapshot(_ summary: DailyHealthSummary, inviteCode: String, parentName: String) async throws {
        let jsonData = try encoder.encode(summary)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw SyncError.encodingFailed
        }

        if let existing = try? await fetchSnapshotRecord(inviteCode: inviteCode) {
            existing[CKField.snapshotJSON] = jsonString
            existing[CKField.parentName] = parentName
            existing[CKField.updatedAt] = Date()
            _ = try await publicDB.save(existing)
        } else {
            let record = CKRecord(recordType: CKRecordType.parentHealthSnapshot)
            record[CKField.inviteCode] = inviteCode
            record[CKField.snapshotJSON] = jsonString
            record[CKField.parentName] = parentName
            record[CKField.updatedAt] = Date()
            _ = try await publicDB.save(record)
        }
    }

    // MARK: - Parent: Push Structured HealthRecord

    func pushHealthRecord(_ record: HealthRecord) async throws {
        let recordIDString = "HealthRecord_\(record.inviteCode)_\(record.formattedDate)"
        let recordID = CKRecord.ID(recordName: recordIDString)

        let ckRecord = CKRecord(recordType: CKRecordType.healthRecord, recordID: recordID)
        ckRecord[CKField.inviteCode] = record.inviteCode
        ckRecord[CKField.recordDate] = record.recordDate
        ckRecord[CKField.parentName] = record.parentName
        if let rhr = record.restingHeartRate { ckRecord[CKField.restingHeartRate] = rhr }
        ckRecord[CKField.heartRateStatus] = record.heartRateStatus
        ckRecord[CKField.recentHeartRatePoints] = record.recentHeartRatePoints.map { String($0) }.joined(separator: ",")
        if let s = record.sleepHours { ckRecord[CKField.sleepHours] = s }
        ckRecord[CKField.sleepFormatted] = record.sleepFormatted
        ckRecord[CKField.sleepStatus] = record.sleepStatus
        ckRecord[CKField.recentSleepPoints] = record.recentSleepPoints.map { String($0) }.joined(separator: ",")
        if let steps = record.stepCount { ckRecord[CKField.stepCount] = Int64(steps) }
        ckRecord[CKField.stepFormatted] = record.stepFormatted
        ckRecord[CKField.activityStatus] = record.activityStatus
        ckRecord[CKField.recentStepPoints] = record.recentStepPoints.map { String($0) }.joined(separator: ",")
        ckRecord[CKField.summaryTitle] = record.summaryTitle
        ckRecord[CKField.summaryBody] = record.summaryBody
        ckRecord[CKField.updatedAt] = record.updatedAt

        _ = try await publicDB.save(ckRecord)
    }

    // MARK: - Child: Fetch Latest HealthRecord

    func fetchLatestHealthRecord(inviteCode: String) async throws -> HealthRecord? {
        let predicate = NSPredicate(format: "inviteCode == %@", inviteCode)
        let query = CKQuery(recordType: CKRecordType.healthRecord, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: CKField.updatedAt, ascending: false)]

        let result = try await publicDB.records(matching: query, resultsLimit: 1)
        guard let (_, recordResult) = result.matchResults.first,
              let record = try? recordResult.get() else {
            return nil
        }

        let hrPoints = (record[CKField.recentHeartRatePoints] as? String ?? "")
            .split(separator: ",").compactMap { Double($0) }
        let sleepPoints = (record[CKField.recentSleepPoints] as? String ?? "")
            .split(separator: ",").compactMap { Double($0) }
        let stepPoints = (record[CKField.recentStepPoints] as? String ?? "")
            .split(separator: ",").compactMap { Double($0) }

        return HealthRecord(
            inviteCode: record[CKField.inviteCode] as? String ?? inviteCode,
            recordDate: record[CKField.recordDate] as? Date ?? Date(),
            parentName: record[CKField.parentName] as? String ?? "Parent",
            restingHeartRate: record[CKField.restingHeartRate] as? Double,
            heartRateStatus: record[CKField.heartRateStatus] as? String ?? "Dalam rentang normal",
            recentHeartRatePoints: hrPoints.isEmpty ? [70, 71, 72, 70, 72] : hrPoints,
            sleepHours: record[CKField.sleepHours] as? Double,
            sleepFormatted: record[CKField.sleepFormatted] as? String ?? "7j 0m",
            sleepStatus: record[CKField.sleepStatus] as? String ?? "Kualitas tidur baik",
            recentSleepPoints: sleepPoints.isEmpty ? [7.0, 7.2, 7.5, 7.6] : sleepPoints,
            stepCount: (record[CKField.stepCount] as? Int64).map(Int.init),
            stepFormatted: record[CKField.stepFormatted] as? String ?? "0",
            activityStatus: record[CKField.activityStatus] as? String ?? "Normal",
            recentStepPoints: stepPoints.isEmpty ? [3500, 4000, 4200, 4280] : stepPoints,
            summaryTitle: record[CKField.summaryTitle] as? String ?? "Kondisi stabil",
            summaryBody: record[CKField.summaryBody] as? String ?? "Aktivitas dan pola istirahat berjalan normal.",
            updatedAt: record[CKField.updatedAt] as? Date ?? Date()
        )
    }

    // MARK: - Child: Fetch Parent Snapshot

    /// Fetches the latest ParentHealthSnapshot for a given invite code.
    func fetchParentSnapshot(inviteCode: String) async throws -> (summary: DailyHealthSummary, parentName: String, updatedAt: Date)? {
        guard let record = try? await fetchSnapshotRecord(inviteCode: inviteCode) else { return nil }
        guard let jsonString = record[CKField.snapshotJSON] as? String,
              let jsonData = jsonString.data(using: .utf8) else { return nil }
        let summary = try decoder.decode(DailyHealthSummary.self, from: jsonData)
        let parentName = record[CKField.parentName] as? String ?? "Parent"
        let updatedAt = record[CKField.updatedAt] as? Date ?? Date()
        return (summary, parentName, updatedAt)
    }

    // MARK: - Child: Subscribe to Real-Time Updates

    /// Creates a CKQuerySubscription so child gets a silent push whenever parent updates.
    func subscribeToParentUpdates(inviteCode: String) async throws {
        try? await publicDB.deleteSubscription(withID: subscriptionID)

        let predicate = NSPredicate(format: "inviteCode == %@", inviteCode)
        let subscription = CKQuerySubscription(
            recordType: CKRecordType.parentHealthSnapshot,
            predicate: predicate,
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        notificationInfo.shouldBadge = false
        subscription.notificationInfo = notificationInfo

        _ = try await publicDB.save(subscription)
    }

    // MARK: - Child: Remove Subscription

    func removeParentSubscription() async {
        try? await publicDB.deleteSubscription(withID: subscriptionID)
    }

    // MARK: - Invite Status Poll

    func checkInviteStatus(code: String) async throws -> String {
        let record = try await fetchInviteRecord(code: code)
        return record[CKField.status] as? String ?? "pending"
    }

    // MARK: - Private Helpers

    private func generateCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<8).map { _ in chars.randomElement()! })
    }

    private func fetchInviteRecord(code: String) async throws -> CKRecord {
        let predicate = NSPredicate(format: "inviteCode == %@", code)
        let query = CKQuery(recordType: CKRecordType.sharingInvite, predicate: predicate)
        let result = try await publicDB.records(matching: query, resultsLimit: 1)
        guard let (_, recordResult) = result.matchResults.first,
              let record = try? recordResult.get() else {
            throw SyncError.inviteNotFound
        }
        return record
    }

    private func fetchSnapshotRecord(inviteCode: String) async throws -> CKRecord {
        let predicate = NSPredicate(format: "inviteCode == %@", inviteCode)
        let query = CKQuery(recordType: CKRecordType.parentHealthSnapshot, predicate: predicate)
        let result = try await publicDB.records(matching: query, resultsLimit: 1)
        guard let (_, recordResult) = result.matchResults.first,
              let record = try? recordResult.get() else {
            throw SyncError.snapshotNotFound
        }
        return record
    }
}

// MARK: - Sync Errors

enum SyncError: LocalizedError {
    case inviteNotFound
    case snapshotNotFound
    case encodingFailed
    case invalidURL
    case cloudKitUnavailable

    var errorDescription: String? {
        switch self {
        case .inviteNotFound: return "Invite link tidak ditemukan atau sudah kadaluarsa."
        case .snapshotNotFound: return "Data orang tua belum tersedia."
        case .encodingFailed: return "Gagal memproses data kesehatan."
        case .invalidURL: return "Gagal membuat link undangan."
        case .cloudKitUnavailable: return "iCloud tidak tersedia. Pastikan kamu sudah login di Settings."
        }
    }
}
