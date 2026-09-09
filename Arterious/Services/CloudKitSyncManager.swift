import Foundation
import CloudKit
import UIKit

// MARK: - CloudKit Record Constants

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
    // ParentHealthSnapshot & HealthRecord
    static let snapshotJSON = "snapshotJSON"
    static let parentName = "parentName"
    static let updatedAt = "updatedAt"
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

    let container: CKContainer
    private let publicDB: CKDatabase
    private let privateDB: CKDatabase
    private let sharedDB: CKDatabase

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Custom record zone in Private Database required by Apple for CKShare
    private let healthZone = CKRecordZone(zoneName: "ArteriousHealthZone")

    private lazy var dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f
    }()

    private init() {
        container = CKContainer(identifier: "iCloud.com.helloworld.arterious")
        publicDB = container.publicCloudDatabase
        privateDB = container.privateCloudDatabase
        sharedDB = container.sharedCloudDatabase

        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - iCloud Availability Check

    /// Verifies that the user is signed into iCloud before performing any CloudKit operation.
    func ensureCloudKitAvailable() async throws {
        let status = try await container.accountStatus()
        guard status == .available else {
            throw SyncError.cloudKitUnavailable
        }
    }

    // MARK: - Native Apple CKShare (One-Way: Read-Only)

    private var cachedShare: CKShare?
    private var hasCreatedHealthZone: Bool = false

    /// Ensures the custom record zone exists in the Parent's Private Database.
    func ensureHealthZoneCreated() async throws {
        if hasCreatedHealthZone { return }
        try await ensureCloudKitAvailable()
        do {
            _ = try await privateDB.save(healthZone)
            hasCreatedHealthZone = true
        } catch let error as CKError where error.code == .serverRecordChanged || error.code == .zoneNotFound {
            hasCreatedHealthZone = true
        } catch {
            hasCreatedHealthZone = true
        }
    }

    /// Prepares or retrieves the native `CKShare` for the parent's health record.
    /// Default permission is strictly `.allowReadOnly` (One-Way: child can only view).
    func getOrCreateNativeShare(parentName: String) async throws -> CKShare {
        if let cached = cachedShare, cached.url != nil {
            return cached
        }

        try await ensureHealthZoneCreated()

        let rootID = CKRecord.ID(recordName: "CurrentHealthRecord", zoneID: healthZone.zoneID)

        // 1. Fetch or prepare root record in privateDB
        let rootRecord: CKRecord
        if let existing = try? await privateDB.record(for: rootID) {
            rootRecord = existing
            // Return existing share if already attached
            if let shareRef = rootRecord.share,
               let existingShare = try? await privateDB.record(for: shareRef.recordID) as? CKShare {
                self.cachedShare = existingShare
                return existingShare
            }
        } else {
            rootRecord = CKRecord(recordType: CKRecordType.healthRecord, recordID: rootID)
            rootRecord[CKField.parentName] = parentName
            rootRecord[CKField.updatedAt] = Date()
        }

        // 2. Create new native CKShare attached to the root record
        let share = CKShare(rootRecord: rootRecord)
        share[CKShare.SystemFieldKey.title] = "Data Kesehatan \(parentName)"
        share.publicPermission = .readOnly // Strictly One-Way Read-Only!

        let modifyOp = CKModifyRecordsOperation(recordsToSave: [rootRecord, share], recordIDsToDelete: nil)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            modifyOp.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            privateDB.add(modifyOp)
        }

        self.cachedShare = share
        return share
    }

    /// Child accepts the native iCloud share link (https://www.icloud.com/share/...)
    func acceptNativeShare(url: URL) async throws -> (parentName: String, share: CKShare) {
        try await ensureCloudKitAvailable()

        let metadata = try await container.shareMetadata(for: url)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let op = CKAcceptSharesOperation(shareMetadatas: [metadata])
            op.acceptSharesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            container.add(op)
        }

        let name = metadata.ownerIdentity.nameComponents?.formatted() ?? "Orang Tua"
        return (name, metadata.share)
    }

    /// Checks the parent's native CKShare to see if any child/participant has actually accepted the invitation.
    func checkActiveParticipants() async -> (hasAccepted: Bool, partnerName: String?) {
        guard let share = try? await getOrCreateNativeShare(parentName: "Saya") else {
            return (false, nil)
        }

        // Fetch fresh share from privateDB to get latest participant acceptance statuses
        guard let freshShare = (try? await privateDB.record(for: share.recordID)) as? CKShare else {
            return (false, nil)
        }
        self.cachedShare = freshShare

        for participant in freshShare.participants {
            if participant.role != .owner && participant.acceptanceStatus == .accepted {
                let name = participant.userIdentity.nameComponents?.givenName ?? "Anak"
                return (true, name)
            }
        }
        return (false, nil)
    }

    /// Revokes the share and cleans up records when parent disconnects
    func revokeParentShare() async {
        if let share = cachedShare {
            try? await privateDB.deleteRecord(withID: share.recordID)
            self.cachedShare = nil
        }
    }

    /// Child fetches the parent's health record from the Shared Database (`sharedCloudDatabase`).
    func fetchSharedHealthData() async throws -> (summary: DailyHealthSummary, parentName: String, updatedAt: Date)? {
        try await ensureCloudKitAvailable()

        let sharedZones = try await sharedDB.allRecordZones()
        for zone in sharedZones {
            let rootID = CKRecord.ID(recordName: "CurrentHealthRecord", zoneID: zone.zoneID)
            if let record = try? await sharedDB.record(for: rootID) {
                if let jsonString = record[CKField.snapshotJSON] as? String,
                   let jsonData = jsonString.data(using: .utf8),
                   let summary = try? decoder.decode(DailyHealthSummary.self, from: jsonData) {
                    let name = record[CKField.parentName] as? String ?? "Orang Tua"
                    let date = record[CKField.updatedAt] as? Date ?? Date()
                    return (summary, name, date)
                }
            }
        }
        return nil
    }

    // MARK: - Parent: Push Health Data to Private Database & Public fallback

    /// Saves the parent's latest health summary to the private custom zone (for CKShare)
    /// and updates the shared snapshot.
    func pushHealthSnapshot(_ summary: DailyHealthSummary, inviteCode: String = "SHARED", parentName: String) async throws {
        try await ensureCloudKitAvailable()

        let jsonData = try encoder.encode(summary)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw SyncError.encodingFailed
        }

        // 1. Save to Private Zone (for CKShare participants)
        do {
            try await ensureHealthZoneCreated()
            let rootID = CKRecord.ID(recordName: "CurrentHealthRecord", zoneID: healthZone.zoneID)
            let privRecord: CKRecord
            if let existing = try? await privateDB.record(for: rootID) {
                privRecord = existing
            } else {
                privRecord = CKRecord(recordType: CKRecordType.healthRecord, recordID: rootID)
            }
            privRecord[CKField.snapshotJSON] = jsonString
            privRecord[CKField.parentName] = parentName
            privRecord[CKField.updatedAt] = Date()
            _ = try await privateDB.save(privRecord)
        } catch {
            print("⚠️ Private zone snapshot save error: \(error.localizedDescription)")
        }

        // 2. Also save to PublicDB for seamless compatibility
        let publicRecordID = CKRecord.ID(recordName: "ParentHealthSnapshot_\(inviteCode)")
        let publicRecord: CKRecord
        if let existing = try? await publicDB.record(for: publicRecordID) {
            publicRecord = existing
        } else {
            publicRecord = CKRecord(recordType: CKRecordType.parentHealthSnapshot, recordID: publicRecordID)
        }

        publicRecord[CKField.snapshotJSON] = jsonString
        publicRecord[CKField.parentName] = parentName
        publicRecord[CKField.updatedAt] = Date()
        _ = try await publicDB.save(publicRecord)
    }

    /// Saves or updates a HealthRecord for the current day.
    func pushHealthRecord(_ record: HealthRecord) async throws {
        try await ensureCloudKitAvailable()

        let dateString = dateFormatter.string(from: record.recordDate)

        // 1. Save to Private Zone (CKShare)
        do {
            try await ensureHealthZoneCreated()
            let privRecordID = CKRecord.ID(recordName: "HealthRecord_\(dateString)", zoneID: healthZone.zoneID)
            let privRecord: CKRecord
            if let existing = try? await privateDB.record(for: privRecordID) {
                privRecord = existing
            } else {
                privRecord = CKRecord(recordType: CKRecordType.healthRecord, recordID: privRecordID)
            }
            populateRecord(privRecord, with: record)
            _ = try await privateDB.save(privRecord)
        } catch {
            print("⚠️ Private zone record save error: \(error.localizedDescription)")
        }

        // 2. Save to PublicDB (fallback)
        let recordID = CKRecord.ID(recordName: "HealthRecord_\(record.inviteCode)_\(dateString)")
        let ckRecord: CKRecord
        if let existing = try? await publicDB.record(for: recordID) {
            ckRecord = existing
        } else {
            ckRecord = CKRecord(recordType: CKRecordType.healthRecord, recordID: recordID)
        }
        populateRecord(ckRecord, with: record)
        _ = try await publicDB.save(ckRecord)
    }

    private func populateRecord(_ ckRecord: CKRecord, with record: HealthRecord) {
        ckRecord[CKField.inviteCode] = record.inviteCode
        ckRecord[CKField.recordDate] = record.recordDate
        ckRecord[CKField.parentName] = record.parentName
        if let hr = record.heartRate ?? record.restingHeartRate { ckRecord[CKField.restingHeartRate] = hr }
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
    }

    // MARK: - Child: Fetch Latest HealthRecord

    func fetchLatestHealthRecord(inviteCode: String) async throws -> HealthRecord? {
        try await ensureCloudKitAvailable()

        // 1. Try fetching from Shared Database first (native CKShare)
        if let sharedData = try? await fetchSharedHealthData() {
            return HealthRecord.create(from: sharedData.summary, inviteCode: inviteCode, parentName: sharedData.parentName)
        }

        // 2. Fallback to publicDB query
        let predicate = NSPredicate(format: "inviteCode == %@", inviteCode)
        let query = CKQuery(recordType: CKRecordType.healthRecord, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: CKField.updatedAt, ascending: false)]

        guard let result = try? await publicDB.records(matching: query, resultsLimit: 1),
              let (_, recordResult) = result.matchResults.first,
              let record = try? recordResult.get() else {
            return nil
        }

        return parseHealthRecord(from: record, fallbackInviteCode: inviteCode)
    }

    // MARK: - Child: Fetch HealthRecord History

    func fetchHealthRecordHistory(inviteCode: String, days: Int = 7) async throws -> [HealthRecord] {
        try await ensureCloudKitAvailable()

        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: Date()))!
        let predicate = NSPredicate(format: "inviteCode == %@ AND recordDate >= %@", inviteCode, startDate as NSDate)
        let query = CKQuery(recordType: CKRecordType.healthRecord, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: CKField.recordDate, ascending: true)]

        guard let result = try? await publicDB.records(matching: query, resultsLimit: days + 1) else {
            return []
        }

        return result.matchResults.compactMap { (_, recordResult) in
            guard let record = try? recordResult.get() else { return nil }
            return parseHealthRecord(from: record, fallbackInviteCode: inviteCode)
        }
    }

    // MARK: - Parse CKRecord → HealthRecord

    private func parseHealthRecord(from record: CKRecord, fallbackInviteCode: String) -> HealthRecord {
        let hrPoints = (record[CKField.recentHeartRatePoints] as? String ?? "")
            .split(separator: ",").compactMap { Double($0) }
        let sleepPoints = (record[CKField.recentSleepPoints] as? String ?? "")
            .split(separator: ",").compactMap { Double($0) }
        let stepPoints = (record[CKField.recentStepPoints] as? String ?? "")
            .split(separator: ",").compactMap { Double($0) }

        return HealthRecord(
            inviteCode: record[CKField.inviteCode] as? String ?? fallbackInviteCode,
            recordDate: record[CKField.recordDate] as? Date ?? Date(),
            parentName: record[CKField.parentName] as? String ?? "Parent",
            heartRate: record[CKField.restingHeartRate] as? Double,
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

    func fetchParentSnapshot(inviteCode: String) async throws -> (summary: DailyHealthSummary, parentName: String, updatedAt: Date)? {
        // 1. Try shared DB first
        if let shared = try? await fetchSharedHealthData() {
            return shared
        }

        // 2. Fallback to publicDB
        guard let record = try? await fetchSnapshotRecord(inviteCode: inviteCode) else { return nil }
        guard let jsonString = record[CKField.snapshotJSON] as? String,
              let jsonData = jsonString.data(using: .utf8) else { return nil }
        let summary = try decoder.decode(DailyHealthSummary.self, from: jsonData)
        let parentName = record[CKField.parentName] as? String ?? "Parent"
        let updatedAt = record[CKField.updatedAt] as? Date ?? Date()
        return (summary, parentName, updatedAt)
    }

    // MARK: - Real-Time Subscriptions

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

    func removeParentSubscription() async {
        try? await publicDB.deleteSubscription(withID: subscriptionID)
    }

    // MARK: - Legacy Deep Link Support

    func fetchInviteDetails(code: String) async throws -> InviteDetails {
        let record = try await fetchInviteRecord(code: code)
        return InviteDetails(
            code: code,
            status: record[CKField.status] as? String ?? "pending",
            senderRole: record[CKField.senderRole] as? String ?? "child",
            senderName: record[CKField.senderName] as? String ?? "Keluarga"
        )
    }

    func acceptInvite(code: String) async throws {
        let record = try await fetchInviteRecord(code: code)
        record[CKField.status] = "accepted"
        _ = try await publicDB.save(record)
    }

    private func fetchInviteRecord(code: String) async throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: "SharingInvite_\(code)")
        if let record = try? await publicDB.record(for: recordID) {
            return record
        }
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

enum SyncError: LocalizedError, Equatable {
    case inviteNotFound
    case snapshotNotFound
    case encodingFailed
    case invalidURL
    case cloudKitUnavailable

    var errorDescription: String? {
        switch self {
        case .inviteNotFound: return "Link sharing tidak ditemukan atau sudah kadaluarsa."
        case .snapshotNotFound: return "Data orang tua belum tersedia."
        case .encodingFailed: return "Gagal memproses data kesehatan."
        case .invalidURL: return "Gagal membuat tautan sharing."
        case .cloudKitUnavailable: return "iCloud tidak tersedia. Pastikan kamu sudah login di Settings."
        }
    }
}
