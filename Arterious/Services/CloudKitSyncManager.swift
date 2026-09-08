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
    static let senderRole = "senderRole"
    static let senderName = "senderName"
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

// MARK: - Invite Details Model

struct InviteDetails {
    let code: String
    let status: String
    let senderRole: String
    let senderName: String
}

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

    // MARK: - Generate Invite Link (Bidirectional)

    /// Creates a SharingInvite record in CloudKit and returns a deep link URL.
    func generateInviteLink(senderRole: SyncRole = .child, senderName: String = "Keluarga") async throws -> URL {
        let code = generateCode()
        let recordID = CKRecord.ID(recordName: "SharingInvite_\(code)")
        let record = CKRecord(recordType: CKRecordType.sharingInvite, recordID: recordID)
        record[CKField.inviteCode] = code
        record[CKField.status] = "pending"
        record[CKField.childDeviceID] = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        record[CKField.senderRole] = senderRole == .parent ? "parent" : "child"
        record[CKField.senderName] = senderName

        _ = try await publicDB.save(record)

        guard let url = URL(string: "arterious://invite?code=\(code)") else {
            throw SyncError.invalidURL
        }
        return url
    }

    /// Fetches invite metadata to determine who invited whom
    func fetchInviteDetails(code: String) async throws -> InviteDetails {
        let record = try await fetchInviteRecord(code: code)
        return InviteDetails(
            code: code,
            status: record[CKField.status] as? String ?? "pending",
            senderRole: record[CKField.senderRole] as? String ?? "child",
            senderName: record[CKField.senderName] as? String ?? "Keluarga"
        )
    }

    // MARK: - Accept Invite

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

        let recordID = CKRecord.ID(recordName: "ParentHealthSnapshot_\(inviteCode)")
        let record: CKRecord
        if let existing = try? await publicDB.record(for: recordID) {
            record = existing
        } else {
            record = CKRecord(recordType: CKRecordType.parentHealthSnapshot, recordID: recordID)
            record[CKField.inviteCode] = inviteCode
        }

        record[CKField.snapshotJSON] = jsonString
        record[CKField.parentName] = parentName
        record[CKField.updatedAt] = Date()
        _ = try await publicDB.save(record)
    }

    // MARK: - Parent: Push Structured HealthRecord

    func pushHealthRecord(_ record: HealthRecord) async throws {
        let recordIDString = "HealthRecord_\(record.inviteCode)"
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
        let recordID = CKRecord.ID(recordName: "HealthRecord_\(inviteCode)")
        let record: CKRecord
        if let direct = try? await publicDB.record(for: recordID) {
            record = direct
        } else {
            let predicate = NSPredicate(format: "inviteCode == %@", inviteCode)
            let query = CKQuery(recordType: CKRecordType.healthRecord, predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: CKField.updatedAt, ascending: false)]

            guard let result = try? await publicDB.records(matching: query, resultsLimit: 1),
                  let (_, recordResult) = result.matchResults.first,
                  let r = try? recordResult.get() else {
                return nil
            }
            record = r
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
            heartRateStatus: record[CKField.heartRateStatus] as? String ?? "Belum ada data",
            recentHeartRatePoints: hrPoints,
            sleepHours: record[CKField.sleepHours] as? Double,
            sleepFormatted: record[CKField.sleepFormatted] as? String ?? "-",
            sleepStatus: record[CKField.sleepStatus] as? String ?? "Belum ada data",
            recentSleepPoints: sleepPoints,
            stepCount: (record[CKField.stepCount] as? Int64).map(Int.init),
            stepFormatted: record[CKField.stepFormatted] as? String ?? "-",
            activityStatus: record[CKField.activityStatus] as? String ?? "Belum ada data",
            recentStepPoints: stepPoints,
            summaryTitle: record[CKField.summaryTitle] as? String ?? "Belum ada data hari ini",
            summaryBody: record[CKField.summaryBody] as? String ?? "Data kesehatan belum tercatat di Apple Health hari ini.",
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
        let recordID = CKRecord.ID(recordName: "SharingInvite_\(code)")
        if let record = try? await publicDB.record(for: recordID) {
            return record
        }
        // Fallback for query
        let predicate = NSPredicate(format: "inviteCode == %@", code)
        let query = CKQuery(recordType: CKRecordType.sharingInvite, predicate: predicate)
        if let result = try? await publicDB.records(matching: query, resultsLimit: 1),
           let (_, recordResult) = result.matchResults.first,
           let record = try? recordResult.get() {
            return record
        }
        throw SyncError.inviteNotFound
    }

    private func fetchSnapshotRecord(inviteCode: String) async throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: "ParentHealthSnapshot_\(inviteCode)")
        if let record = try? await publicDB.record(for: recordID) {
            return record
        }
        // Fallback for query
        let predicate = NSPredicate(format: "inviteCode == %@", inviteCode)
        let query = CKQuery(recordType: CKRecordType.parentHealthSnapshot, predicate: predicate)
        if let result = try? await publicDB.records(matching: query, resultsLimit: 1),
           let (_, recordResult) = result.matchResults.first,
           let record = try? recordResult.get() {
            return record
        }
        throw SyncError.snapshotNotFound
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
