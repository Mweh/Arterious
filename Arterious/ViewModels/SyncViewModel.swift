import Foundation
import Observation
import UIKit
import CloudKit

@Observable
@MainActor
final class SyncViewModel {

    // MARK: - State

    var syncState: SyncState = SyncState(role: .child, inviteCode: nil, status: .none, partnerName: nil, lastSyncDate: nil)
    var isLoading: Bool = false
    var errorMessage: String?
    var inviteURL: URL?
    var parentSnapshot: DailyHealthSummary?
    var healthRecord: HealthRecord?
    var parentName: String = "Nama Ortu 1"
    var lastSyncDate: Date?

    /// Holds the active native Apple CKShare for presentation in UICloudSharingController
    var nativeShare: CKShare?

    var cloudKitContainer: CKContainer {
        cloudKit.container
    }

    var onSnapshotUpdated: (() -> Void)?

    private let cloudKit: CloudKitSyncManager
    private let healthKit: HealthKitManager
    private var pollTask: Task<Void, Never>?
    private var parentPushTask: Task<Void, Never>?

    // MARK: - Persistence Keys

    private let syncStateKey = "arterious.syncState"

    init(cloudKit: CloudKitSyncManager = .shared,
         healthKit: HealthKitManager = .shared) {
        self.cloudKit = cloudKit
        self.healthKit = healthKit
        loadPersistedState()
    }

    // MARK: - Role Management

    func switchRole(to newRole: SyncRole) async {
        syncState.role = newRole
        persistState()

        if newRole == .parent {
            // ONLY parent requests Apple Health access
            try? await healthKit.requestAuthorization()
            if let code = syncState.inviteCode, syncState.status == .accepted {
                await pushParentHealthData(code: code)
                startParentPushLoop(code: code)
            }
        } else {
            // Child NEVER requests Apple Health access
            parentPushTask?.cancel()
            parentPushTask = nil
            if syncState.status == .accepted {
                await fetchSharedParentSnapshot()
            }
        }
    }

    // MARK: - Native Apple CKShare (One-Way: Read-Only)

    /// Prepares a native `CKShare` and uploads the latest HealthKit data.
    /// Returns the `CKShare` to be presented in `UICloudSharingController`.
    func requestNativeShare() async -> CKShare? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let name = UIDevice.current.name.isEmpty ? "Orang Tua" : UIDevice.current.name
            let share = try await cloudKit.getOrCreateNativeShare(parentName: name)
            self.nativeShare = share

            // Pre-push current health data to private zone
            let summary = await healthKit.fetchTodaySummary()
            let history = await healthKit.fetchHistoricalSummaries(days: 7)
            let record = HealthRecord.create(from: summary, inviteCode: "SHARED", parentName: name, history: history)

            try await cloudKit.pushHealthRecord(record)
            try await cloudKit.pushHealthSnapshot(summary, inviteCode: "SHARED", parentName: name)

            self.syncState.status = .pending
            self.syncState.inviteCode = "SHARED"
            self.lastSyncDate = Date()
            persistState()

            self.inviteURL = share.url
            print("✅ Native CKShare ready: \(share.url?.absoluteString ?? "no url")")
            return share
        } catch {
            print("❌ requestNativeShare error: \(error)")
            self.errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Convenience wrapper for views requesting a share link directly
    func requestShareLink() async -> URL? {
        if let share = await requestNativeShare() {
            self.inviteURL = share.url
            return share.url
        }
        return nil
    }

    // MARK: - Handle Deep Link & Native iCloud Share URLs

    /// Handles incoming links: either native iCloud share URL (https://www.icloud.com/share/...)
    /// or custom deep links (arterious://invite?code=...).
    func handleIncomingShareURL(url: URL) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let urlString = url.absoluteString

        // Check if it's an Apple iCloud Share URL
        if urlString.contains("icloud.com/share") || url.host?.contains("icloud.com") == true {
            do {
                let (pName, share) = try await cloudKit.acceptNativeShare(url: url)
                self.syncState = SyncState(
                    role: .child,
                    inviteCode: "SHARED",
                    status: .accepted,
                    partnerName: pName,
                    lastSyncDate: Date()
                )
                self.parentName = pName
                self.nativeShare = share
                persistState()

                // Fetch parent's health record from shared database
                await fetchSharedParentSnapshot()
            } catch {
                print("❌ acceptNativeShare error: \(error)")
                self.errorMessage = "Gagal menerima undangan sharing: \(error.localizedDescription)"
            }
            return
        }

        // Custom deep link fallback
        await handleIncomingInvite(url: url)
    }

    /// Legacy / deep link fallback
    func handleIncomingInvite(url: URL) async {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              !code.isEmpty else {
            errorMessage = "Link undangan tidak valid."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let details = (try? await cloudKit.fetchInviteDetails(code: code)) ?? InviteDetails(
            code: code,
            status: "accepted",
            senderRole: syncState.role == .parent ? "child" : "parent",
            senderName: "Keluarga"
        )

        if details.senderRole == "parent" || syncState.role == .child {
            syncState = SyncState(
                role: .child,
                inviteCode: code,
                status: .accepted,
                partnerName: details.senderName,
                lastSyncDate: Date()
            )
            self.parentName = details.senderName
            persistState()

            Task {
                try? await cloudKit.acceptInvite(code: code)
                await subscribeAndFetch(code: code)
            }
        } else {
            syncState = SyncState(
                role: .parent,
                inviteCode: code,
                status: .accepted,
                partnerName: details.senderName,
                lastSyncDate: Date()
            )
            persistState()

            Task {
                try? await healthKit.requestAuthorization()
                try? await cloudKit.acceptInvite(code: code)
                await pushParentHealthData(code: code)
                startParentPushLoop(code: code)
            }
        }
    }

    // MARK: - Parent: Periodic Push Loop (every 60 seconds)

    private func startParentPushLoop(code: String) {
        parentPushTask?.cancel()
        parentPushTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { break }
                await pushParentHealthData(code: code)
            }
        }
    }

    func pushParentHealthData(code: String) async {
        let summary = await healthKit.fetchTodaySummary()
        let history = await healthKit.fetchHistoricalSummaries(days: 7)
        let name = UIDevice.current.name.isEmpty ? "Orang Tua" : UIDevice.current.name

        let record = HealthRecord.create(from: summary, inviteCode: code, parentName: name, history: history)

        do {
            try await cloudKit.pushHealthSnapshot(summary, inviteCode: code, parentName: name)
            try await cloudKit.pushHealthRecord(record)

            lastSyncDate = Date()
            syncState.lastSyncDate = lastSyncDate
            healthRecord = record
            errorMessage = nil
            persistState()
            print("✅ Successfully pushed HealthRecord for code: \(code) on date: \(record.formattedDate)")
        } catch {
            print("❌ Push parent health data error: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Child: Fetch Shared Parent Snapshot

    func fetchSharedParentSnapshot() async {
        do {
            // 1. Try native CKShare shared database first
            if let result = try await cloudKit.fetchSharedHealthData() {
                parentSnapshot = result.summary
                parentName = result.parentName
                lastSyncDate = result.updatedAt
                healthRecord = HealthRecord.create(from: result.summary, inviteCode: syncState.inviteCode ?? "SHARED", parentName: result.parentName)
                syncState.partnerName = result.parentName
                syncState.lastSyncDate = result.updatedAt
                syncState.status = .accepted
                persistState()
                onSnapshotUpdated?()
                return
            }

            // 2. Fallback to public database if inviteCode is present
            if let code = syncState.inviteCode {
                await fetchParentSnapshot(code: code)
            }
        } catch {
            print("⚠️ fetchSharedParentSnapshot error: \(error)")
            if let code = syncState.inviteCode {
                await fetchParentSnapshot(code: code)
            }
        }
    }

    func subscribeAndFetch(code: String) async {
        try? await cloudKit.subscribeToParentUpdates(inviteCode: code)
        await fetchParentSnapshot(code: code)
    }

    func fetchParentSnapshot(code: String) async {
        do {
            if let hr = try await cloudKit.fetchLatestHealthRecord(inviteCode: code) {
                self.healthRecord = hr
                self.parentName = hr.parentName
                self.lastSyncDate = hr.updatedAt
                self.syncState.partnerName = hr.parentName
                self.syncState.lastSyncDate = hr.updatedAt
                self.syncState.status = .accepted
            }

            if let result = try await cloudKit.fetchParentSnapshot(inviteCode: code) {
                parentSnapshot = result.summary
                parentName = result.parentName
                lastSyncDate = result.updatedAt
                syncState.partnerName = result.parentName
                syncState.lastSyncDate = result.updatedAt
                syncState.status = .accepted

                if self.healthRecord == nil {
                    self.healthRecord = HealthRecord.create(from: result.summary, inviteCode: code, parentName: result.parentName)
                }
            }

            errorMessage = nil
            persistState()
            onSnapshotUpdated?()
        } catch {
            persistState()
            onSnapshotUpdated?()
        }
    }

    // MARK: - Refresh on Foreground

    func refreshIfNeeded() async {
        switch syncState.role {
        case .child:
            if syncState.status == .accepted {
                await fetchSharedParentSnapshot()
            }
        case .parent:
            if let code = syncState.inviteCode, syncState.status == .accepted {
                startParentPushLoop(code: code)
            }
        case .unset:
            break
        }
    }

    // MARK: - Disconnect

    func disconnect() async {
        pollTask?.cancel()
        parentPushTask?.cancel()
        if syncState.role == .child {
            await cloudKit.removeParentSubscription()
        }
        syncState = SyncState(role: .child, inviteCode: nil, status: .none, partnerName: nil, lastSyncDate: nil)
        parentSnapshot = nil
        healthRecord = nil
        nativeShare = nil
        inviteURL = nil
        lastSyncDate = nil
        persistState()
    }

    // MARK: - State Persistence

    private func persistState() {
        if let data = try? JSONEncoder().encode(syncState) {
            UserDefaults.standard.set(data, forKey: syncStateKey)
        }
    }

    private func loadPersistedState() {
        guard let data = UserDefaults.standard.data(forKey: syncStateKey),
              let state = try? JSONDecoder().decode(SyncState.self, from: data) else {
            syncState = SyncState(role: .child, inviteCode: nil, status: .none, partnerName: nil, lastSyncDate: nil)
            return
        }
        syncState = state
        if syncState.role == .unset {
            syncState.role = .child
        }
    }
}
