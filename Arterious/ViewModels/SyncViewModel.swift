import Foundation
import Observation
import UIKit

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
            if let code = syncState.inviteCode, syncState.status == .accepted {
                await fetchParentSnapshot(code: code)
            }
        }
    }

    // MARK: - Generate Share Link (Bidirectional)

    /// Generates CloudKit invite link for the current role (Child or Parent) and returns URL for Share Sheet.
    @discardableResult
    func requestShareLink() async -> URL? {
        if let existing = inviteURL, syncState.status == .pending {
            return existing
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Generate 8-digit code
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        let code = String((0..<8).map { _ in chars.randomElement()! })
        guard let url = URL(string: "arterious://invite?code=\(code)") else {
            errorMessage = "Gagal membuat link undangan."
            return nil
        }

        inviteURL = url
        syncState = SyncState(
            role: syncState.role,
            inviteCode: code,
            status: .pending,
            partnerName: nil,
            lastSyncDate: nil
        )
        persistState()

        // Register in CloudKit FIRST, then start polling
        do {
            _ = try await cloudKit.generateInviteLink(code: code, senderRole: syncState.role, senderName: UIDevice.current.name)
            if syncState.role == .parent {
                await pushParentHealthData(code: code)
            }
        } catch {
            self.errorMessage = "Gagal mendaftarkan undangan di CloudKit: \(error.localizedDescription)"
            // Don't start polling if CloudKit registration failed
            return url
        }

        startPollingForAcceptance(code: code)
        return url
    }

    // MARK: - Handle Deep Link (Bidirectional)

    /// Called when the app is opened via arterious://invite?code=XXXX or code entered manually.
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

        do {
            let details = try await cloudKit.fetchInviteDetails(code: code)
            if details.senderRole == "parent" {
                // Sender is Parent -> Receiver is Child
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
                    do {
                        try await cloudKit.acceptInvite(code: code)
                    } catch {
                        self.errorMessage = "Gagal menerima undangan: \(error.localizedDescription)"
                    }
                    await subscribeAndFetch(code: code)
                }
            } else {
                // Sender is Child -> Receiver is Parent
                syncState = SyncState(
                    role: .parent,
                    inviteCode: code,
                    status: .accepted,
                    partnerName: details.senderName,
                    lastSyncDate: Date()
                )
                persistState()

                // CRITICAL: Request HealthKit auth and push data inline (not in background)
                Task {
                    try? await healthKit.requestAuthorization()
                    do {
                        try await cloudKit.acceptInvite(code: code)
                    } catch {
                        self.errorMessage = "Gagal konfirmasi ke CloudKit: \(error.localizedDescription)"
                    }
                    await pushParentHealthData(code: code)
                    startParentPushLoop(code: code)
                }
            }
        } catch {
            errorMessage = "Gagal memproses kode undangan CloudKit: \(error.localizedDescription)"
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
        } catch {
            errorMessage = "Gagal mengirim data ke CloudKit: \(error.localizedDescription)"
        }
    }

    // MARK: - Poll Until Partner Accepts

    @MainActor
    private func handleInviteAccepted(code: String) async {
        syncState.status = .accepted
        persistState()
        if syncState.role == .child {
            await subscribeAndFetch(code: code)
        } else {
            await pushParentHealthData(code: code)
            startParentPushLoop(code: code)
        }
    }

    private func startPollingForAcceptance(code: String) {
        pollTask?.cancel()
        pollTask = Task {
            // 1. Check immediately
            if let status = try? await cloudKit.checkInviteStatus(code: code),
               status == "accepted" {
                await handleInviteAccepted(code: code)
                return
            }

            // 2. Rapid polling for first 60 seconds (every 3 seconds) for instant connection
            for _ in 0..<20 {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                if let status = try? await cloudKit.checkInviteStatus(code: code),
                   status == "accepted" {
                    await handleInviteAccepted(code: code)
                    return
                }
            }

            // 3. Normal polling afterwards (every 10 seconds for up to 10 minutes)
            for _ in 0..<60 {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { return }
                if let status = try? await cloudKit.checkInviteStatus(code: code),
                   status == "accepted" {
                    await handleInviteAccepted(code: code)
                    return
                }
            }
        }
    }

    // MARK: - Child: Subscribe + Fetch

    func subscribeAndFetch(code: String) async {
        try? await cloudKit.subscribeToParentUpdates(inviteCode: code)
        await fetchParentSnapshot(code: code)
    }

    /// Called when a silent push notification arrives (via AppDelegate/scene).
    func handleRemoteNotification() async {
        guard syncState.role == .child,
              let code = syncState.inviteCode else { return }
        await fetchParentSnapshot(code: code)
    }

    func fetchParentSnapshot(code: String) async {
        do {
            var fetchedAny = false

            // 1. Try fetching structured HealthRecord first
            if let hr = try await cloudKit.fetchLatestHealthRecord(inviteCode: code) {
                self.healthRecord = hr
                self.parentName = hr.parentName
                self.lastSyncDate = hr.updatedAt
                self.syncState.partnerName = hr.parentName
                self.syncState.lastSyncDate = hr.updatedAt
                self.syncState.status = .accepted
                fetchedAny = true
            }

            // 2. Also fetch DailyHealthSummary snapshot
            if let result = try await cloudKit.fetchParentSnapshot(inviteCode: code) {
                parentSnapshot = result.summary
                parentName = result.parentName
                lastSyncDate = result.updatedAt
                syncState.partnerName = result.parentName
                syncState.lastSyncDate = result.updatedAt
                syncState.status = .accepted

                // If HealthRecord wasn't in CloudKit, generate from summary
                if self.healthRecord == nil {
                    self.healthRecord = HealthRecord.create(from: result.summary, inviteCode: code, parentName: result.parentName)
                }
                fetchedAny = true
            }

            if fetchedAny {
                errorMessage = nil
            } else {
                errorMessage = "Belum ada data kesehatan terkirim dari HP Orang Tua."
            }

            persistState()
            onSnapshotUpdated?()
        } catch {
            errorMessage = "Gagal mengambil data dari CloudKit: \(error.localizedDescription)"
            persistState()
            onSnapshotUpdated?()
        }
    }

    // MARK: - Refresh on Foreground (called by child on app open)

    func refreshIfNeeded() async {
        switch syncState.role {
        case .child:
            guard let code = syncState.inviteCode else { return }
            if syncState.status == .accepted {
                await fetchParentSnapshot(code: code)
            } else {
                // Direct immediate check first
                if let status = try? await cloudKit.checkInviteStatus(code: code), status == "accepted" {
                    await handleInviteAccepted(code: code)
                } else {
                    // Re-start polling loop
                    startPollingForAcceptance(code: code)
                }
            }
        case .parent:
            guard let code = syncState.inviteCode else { return }
            if syncState.status == .accepted {
                await pushParentHealthData(code: code)
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
