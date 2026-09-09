import Foundation
import Observation
import UIKit
import CloudKit
import UserNotifications

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
    var historicalSummaries: [DailyHealthSummary] = []
    var parentName: String = "Nama Ortu 1"
    var lastSyncDate: Date?

    /// Deep link trigger to open parent share flow when requested by child
    var shouldShowParentShareFlow: Bool = false
    var pendingParentShareName: String = "Anak"

    /// Role mismatch alert state when opening a link intended for the other role
    var showRoleMismatchAlert: Bool = false
    var roleMismatchMessage: String = ""
    var pendingRoleSwitchTarget: SyncRole? = nil

    /// Banner toast state for child when share is accepted
    var showAcceptedBanner: Bool = false
    var bannerMessage: String = ""

    /// Detected clipboard invite URL for prompt
    var detectedClipboardURL: URL? = nil
    var showDetectedClipboardPrompt: Bool = false

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

    init(cloudKit: CloudKitSyncManager? = nil,
         healthKit: HealthKitManager? = nil) {
        self.cloudKit = cloudKit ?? .shared
        self.healthKit = healthKit ?? .shared
        loadPersistedState()
    }

    // MARK: - Role Management

    func switchRole(to newRole: SyncRole) async {
        syncState.role = newRole
        persistState()

        if newRole == .parent {
            // ONLY parent requests Apple Health access
            try? await healthKit.requestAuthorization()
            await loadParentLocalHealthData()
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

    // MARK: - Parent: Local HealthKit Data Loading

    func loadParentLocalHealthData() async {
        if healthKit.isHealthKitAvailable {
            try? await healthKit.requestAuthorization()
        }
        let summary = await healthKit.fetchTodaySummary()
        let history = await healthKit.fetchHistoricalSummaries(days: 7)
        let record = HealthRecord.create(
            from: summary,
            inviteCode: syncState.inviteCode ?? "LOCAL",
            parentName: "Saya",
            history: history
        )
        self.healthRecord = record
        self.historicalSummaries = history
        self.lastSyncDate = Date()
        print("✅ [SyncViewModel] Loaded real parent health data: HR=\(record.displayHeartRate ?? -1), Steps=\(record.stepCount ?? -1), Sleep=\(record.sleepHours ?? -1)")
    }

    // MARK: - Native Apple CKShare (One-Way: Read-Only)

    /// Prepares a native `CKShare` and uploads the latest HealthKit data.
    /// Returns the `CKShare` to be presented in `UICloudSharingController` or Share Sheet.
    func requestNativeShare() async -> CKShare? {
        if let existing = self.nativeShare, existing.url != nil {
            return existing
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let name = UIDevice.current.name.isEmpty ? "Orang Tua" : UIDevice.current.name
            let share = try await cloudKit.getOrCreateNativeShare(parentName: name)
            self.nativeShare = share
            self.inviteURL = share.url
            self.syncState.status = .pending
            self.syncState.inviteCode = "SHARED"
            self.lastSyncDate = Date()
            persistState()

            // Pre-push current health data in background asynchronously so share link is immediately ready!
            Task(priority: .background) { [weak self] in
                guard let self else { return }
                let summary = await self.healthKit.fetchTodaySummary()
                let history = await self.healthKit.fetchHistoricalSummaries(days: 7)
                let record = HealthRecord.create(from: summary, inviteCode: "SHARED", parentName: name, history: history)
                try? await self.cloudKit.pushHealthRecord(record)
                try? await self.cloudKit.pushHealthSnapshot(summary, inviteCode: "SHARED", parentName: name)
            }

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
    /// or custom deep links (arterious://...). Validates user role before processing.
    func handleIncomingShareURL(url: URL) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let urlString = url.absoluteString

        // 1. Parent receives request from child to share health data: arterious://ask-parent?name=Valentino
        if url.host == "ask-parent" || urlString.contains("ask-parent") {
            // ROLE VALIDATION: Intended for Orang Tua (Parent)
            if syncState.role == .child {
                print("⚠️ [SyncViewModel] Role mismatch: child opened ask-parent link")
                self.roleMismatchMessage = "Tautan undangan ini ditujukan untuk Orang Tua agar dapat membagikan data kesehatan. Anda saat ini masuk sebagai Anak."
                self.pendingRoleSwitchTarget = .parent
                self.showRoleMismatchAlert = true
                return
            }

            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let childName = components?.queryItems?.first(where: { $0.name == "name" })?.value ?? "Anak"
            self.pendingParentShareName = childName
            self.shouldShowParentShareFlow = true
            return
        }

        // 2. Child receives Apple iCloud Share URL or Arterious accept link
        if urlString.contains("icloud.com/share") || url.host?.contains("icloud.com") == true || url.host == "accept-share" {
            // ROLE VALIDATION: Intended for Anak (Child)
            if syncState.role == .parent {
                print("⚠️ [SyncViewModel] Role mismatch: parent opened accept-share link")
                self.roleMismatchMessage = "Tautan ini ditujukan untuk Anak agar dapat memantau data kesehatan orang tua. Anda saat ini masuk sebagai Orang Tua."
                self.pendingRoleSwitchTarget = .child
                self.showRoleMismatchAlert = true
                return
            }

            do {
                let actualURL: URL
                if url.host == "accept-share",
                   let targetStr = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "url" })?.value,
                   let targetURL = URL(string: targetStr) {
                    actualURL = targetURL
                } else {
                    actualURL = url
                }

                let (pName, share) = try await cloudKit.acceptNativeShare(url: actualURL)
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

                // Trigger local notification on child's device
                await triggerAcceptNotification(parentName: pName)

                // Fetch parent's health record from shared database
                await fetchSharedParentSnapshot()

                self.bannerMessage = "Undangan diterima dari \(pName)! Data kesehatan kini terhubung."
                self.showAcceptedBanner = true
            } catch {
                print("❌ acceptNativeShare error: \(error)")
                self.errorMessage = "Gagal menerima undangan sharing: \(error.localizedDescription)"
            }
            return
        }

        // Custom deep link fallback
        await handleIncomingInvite(url: url)
    }

    /// Parses text (e.g. copied from WhatsApp or pasted manually) and processes any Arterious or iCloud share links
    @discardableResult
    func handlePastedLink(_ text: String) async -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        // 1. Direct URL
        if let url = URL(string: trimmed), url.scheme != nil {
            await handleIncomingShareURL(url: url)
            return true
        }

        // 2. Embedded arterious:// in message text
        if let range = trimmed.range(of: "arterious://[^\n\\s]+", options: .regularExpression) {
            let urlString = String(trimmed[range])
            if let url = URL(string: urlString) {
                await handleIncomingShareURL(url: url)
                return true
            }
        }

        // 3. Embedded https://www.icloud.com/share/ in message text
        if let range = trimmed.range(of: "https://www\\.icloud\\.com/share/[^\n\\s]+", options: .regularExpression) {
            let urlString = String(trimmed[range])
            if let url = URL(string: urlString) {
                await handleIncomingShareURL(url: url)
                return true
            }
        }

        return false
    }

    /// Checks the clipboard for invitations when child opens app
    func checkClipboardForInvitation() {
        guard syncState.role == .child, syncState.status != .accepted else { return }
        guard let string = UIPasteboard.general.string else { return }

        if let range = string.range(of: "arterious://accept-share[^\n\\s]+", options: .regularExpression) ??
                      string.range(of: "https://www\\.icloud\\.com/share/[^\n\\s]+", options: .regularExpression) {
            let urlString = String(string[range])
            if let url = URL(string: urlString), detectedClipboardURL != url {
                self.detectedClipboardURL = url
                self.showDetectedClipboardPrompt = true
            }
        }
    }

    private func triggerAcceptNotification(parentName: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Undangan Berbagi Diterima"
        content.body = "Kamu sekarang terhubung dengan \(parentName). Data kesehatan dapat dipantau di Arterious."
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
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
        let appStorageRole = UserDefaults.standard.string(forKey: "userRole")
        if appStorageRole == UserRole.parent.rawValue && syncState.role != .parent {
            syncState.role = .parent
        }

        switch syncState.role {
        case .child:
            if syncState.status == .accepted {
                await fetchSharedParentSnapshot()
            }
        case .parent:
            await loadParentLocalHealthData()
            // If parent shared a link, check if child has actually accepted it
            if syncState.status == .pending {
                let (hasAccepted, partnerName) = await cloudKit.checkActiveParticipants()
                if hasAccepted {
                    syncState.status = .accepted
                    syncState.partnerName = partnerName ?? "Anak"
                    persistState()
                }
            }
            if let code = syncState.inviteCode, syncState.status == .accepted {
                startParentPushLoop(code: code)
            }
        case .unset:
            if appStorageRole == UserRole.parent.rawValue {
                syncState.role = .parent
                await loadParentLocalHealthData()
            }
        }
    }

    // MARK: - Disconnect

    func disconnect() async {
        pollTask?.cancel()
        parentPushTask?.cancel()
        if syncState.role == .child {
            await cloudKit.removeParentSubscription()
        } else if syncState.role == .parent {
            await cloudKit.revokeParentShare()
        }
        let currentRole = syncState.role
        syncState = SyncState(role: currentRole, inviteCode: nil, status: .none, partnerName: nil, lastSyncDate: nil)
        parentSnapshot = nil
        healthRecord = nil
        historicalSummaries = []
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
        let appStorageRole = UserDefaults.standard.string(forKey: "userRole")
        let defaultRole: SyncRole = (appStorageRole == UserRole.parent.rawValue) ? .parent : .child

        guard let data = UserDefaults.standard.data(forKey: syncStateKey),
              let state = try? JSONDecoder().decode(SyncState.self, from: data) else {
            syncState = SyncState(role: defaultRole, inviteCode: nil, status: .none, partnerName: nil, lastSyncDate: nil)
            return
        }
        syncState = state
        if syncState.role == .unset {
            syncState.role = defaultRole
        }
        if let stored = appStorageRole, stored == UserRole.parent.rawValue && syncState.role != .parent {
            syncState.role = .parent
        }
    }
}
