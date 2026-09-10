import Foundation
import Observation
import UIKit
import CloudKit
import HealthKit
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

    /// Evaluasi lengkap dari RuleEngine
    var evaluatedOverview: EvaluatedHealthOverview?
    var baseline: HealthBaseline?

    /// Output AI Insight lengkap (Today's Overview + Domain metrics + Recommended actions)
    var insightOutput: LLMInsightOutput?
    var isUsingLocalRuleFallback: Bool = false

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

    /// Connection success modal for both Child and Parent POV
    var showConnectionSuccessModal: Bool = false
    var connectionSuccessMessage: String = ""

    /// Loading status message during iCloud fetch
    var loadingStatusMessage: String = "Menghubungkan ke iCloud..."

    /// Detected clipboard invite URL for prompt
    var detectedClipboardURL: URL? = nil
    var showDetectedClipboardPrompt: Bool = false

    /// Secondary parent name for parent selector sheet
    var secondaryParentName: String? = nil

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
    @ObservationIgnored private var periodicRefreshTimer: Timer?
    @ObservationIgnored private var heartRateObserverQuery: HKQuery?
    @ObservationIgnored private var isProcessingInvite: Bool = false

    /// Real user name for display and invites (defaults to CloudKit name, clean device name, or saved name)
    var userDisplayName: String {
        get {
            if let saved = UserDefaults.standard.string(forKey: "userDisplayName"), !saved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return saved
            }
            return ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "userDisplayName")
        }
    }

    // MARK: - Persistence Keys

    private let syncStateKey = "arterious.syncState"

    init(cloudKit: CloudKitSyncManager? = nil,
         healthKit: HealthKitManager? = nil) {
        self.cloudKit = cloudKit ?? .shared
        self.healthKit = healthKit ?? .shared
        loadPersistedState()
        startPeriodicAutoRefresh()
        Task {
            _ = await resolveUserDisplayName()
        }
    }

    /// Resolves the user's real first and last name from CloudKit identity or clean device name
    func resolveUserDisplayName() async -> String {
        if !userDisplayName.isEmpty {
            return userDisplayName
        }

        // 1. Try CloudKit User Identity
        if let userRecordID = try? await cloudKitContainer.userRecordID(),
           let identity = try? await cloudKitContainer.userIdentity(forUserRecordID: userRecordID),
           let components = identity.nameComponents {
            let given = components.givenName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let family = components.familyName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let fullName = [given, family].filter { !$0.isEmpty }.joined(separator: " ")
            if !fullName.isEmpty {
                userDisplayName = fullName
                return fullName
            }
        }

        // 2. Try parsing from device name (e.g. "Bagus Krishna's iPhone" -> "Bagus Krishna")
        let cleaned = cleanDeviceName(UIDevice.current.name)
        if !cleaned.isEmpty {
            userDisplayName = cleaned
            return cleaned
        }

        let fallback = (syncState.role == .parent) ? "Orang Tua" : "Anak"
        userDisplayName = fallback
        return fallback
    }

    private func cleanDeviceName(_ rawName: String) -> String {
        var name = rawName
        let patterns = [
            "['’]s\\s+iPhone.*",
            "['’]s\\s+iPad.*",
            "['’]s\\s+Apple\\s*Watch.*",
            "^iPhone\\s+milik\\s+",
            "^iPad\\s+milik\\s+",
            "^iPhone\\s+de\\s+",
            "^iPad\\s+de\\s+",
            "^iPhone\\s+von\\s+",
            "^iPad\\s+von\\s+",
            "\\s+iPhone$",
            "\\s+iPad$"
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                name = regex.stringByReplacingMatches(in: name, options: [], range: NSRange(location: 0, length: name.utf16.count), withTemplate: "")
            }
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.lowercased() == "iphone" || trimmed.lowercased() == "ipad" {
            return ""
        }
        return trimmed
    }

    // MARK: - Role Management

    func switchRole(to newRole: SyncRole) async {
        syncState.role = newRole
        persistState()

        if newRole == .parent {
            // ONLY parent requests Apple Health access
            try? await healthKit.requestAuthorization()
            await loadParentLocalHealthData()
            startPeriodicAutoRefresh()
            if let code = syncState.inviteCode, syncState.status == .accepted {
                await pushParentHealthData(code: code)
                startParentPushLoop(code: code)
            }
        } else {
            // Child NEVER requests Apple Health access
            parentPushTask?.cancel()
            parentPushTask = nil
            startPeriodicAutoRefresh()
            if syncState.status == .accepted {
                await fetchSharedParentSnapshot()
            }
        }
    }

    // MARK: - Parent: Local HealthKit Data Loading

    func loadParentLocalHealthData(forceGemini: Bool = false, autoPushToCloud: Bool = true) async {
        if healthKit.isHealthKitAvailable {
            try? await healthKit.requestAuthorization()
        }
        let summary = await healthKit.fetchTodaySummary()
        let history = await healthKit.fetchHistoricalSummaries(days: 14)

        let pName = (parentName.isEmpty || parentName == "Nama Ortu 1") ? "Saya" : parentName
        let (overview, promptInput) = RuleEngine.shared.evaluate(
            today: summary,
            history: history,
            parentDisplayName: pName == "Saya" ? "Ibu" : pName
        )
        self.evaluatedOverview = overview
        self.baseline = overview.baseline

        // Cek apakah perlu memanggil Gemini API:
        // Hanya panggil jika ada trigger berbahaya, atau 1x per hari, atau force refresh manual.
        var overviewSummaryText = overview.statusBadge
        let shouldCallAI = shouldCallGeminiAPI(for: overview, forceRefresh: forceGemini)

        if shouldCallAI {
            do {
                let (output, _) = try await GeminiService.shared.generateInsight(input: promptInput)
                let cleaned = RuleEngine.shared.sanitizeInsightOutput(output, overview: overview)
                self.insightOutput = cleaned
                self.isUsingLocalRuleFallback = false
                self.lastGeminiCallDate = Date()
                overviewSummaryText = cleaned.todayOverview.summary
            } catch {
                print("⚠️ [SyncViewModel] Gemini error, using rule fallback: \(error)")
                self.isUsingLocalRuleFallback = true
                let fallback = RuleEngine.shared.makeLocalFallbackInsight(from: overview, parentName: pName == "Saya" ? "Ibu" : pName)
                self.insightOutput = fallback
                overviewSummaryText = fallback.todayOverview.summary
            }
        } else if let existing = self.insightOutput {
            self.isUsingLocalRuleFallback = false
            overviewSummaryText = existing.todayOverview.summary
        } else {
            self.isUsingLocalRuleFallback = true
            let fallback = RuleEngine.shared.makeLocalFallbackInsight(from: overview, parentName: pName == "Saya" ? "Ibu" : pName)
            self.insightOutput = fallback
            overviewSummaryText = fallback.todayOverview.summary
        }

        let record = HealthRecord.create(
            from: summary,
            inviteCode: syncState.inviteCode ?? "LOCAL",
            parentName: pName,
            history: history,
            overviewTitle: overview.headline,
            overviewBody: overviewSummaryText,
            activityStatusBadge: overview.activity.status,
            sleepStatusBadge: overview.sleep.status,
            heartStatusBadge: overview.heart.status,
            insightOutput: self.insightOutput
        )
        self.healthRecord = record
        self.historicalSummaries = history
        self.lastSyncDate = Date()
        print("✅ [SyncViewModel] Synced parent health data: HR=\(record.displayHeartRate ?? -1), Steps=\(record.stepCount ?? -1), Sleep=\(record.sleepHours ?? -1), Title=\(record.summaryTitle)")

        // Auto-push to CloudKit if parent is sharing and autoPush is enabled
        if syncState.role == .parent && autoPushToCloud {
            let code = syncState.inviteCode ?? "SHARED"
            Task { [weak self] in
                guard let self else { return }
                try? await self.cloudKit.pushHealthSnapshot(summary, record: record, inviteCode: code, parentName: pName)
                try? await self.cloudKit.pushHealthRecord(record)
            }
        }
    }

    // MARK: - Continuous Auto Refresh Loop (Every 60 Seconds / Per Menit)

    func startPeriodicAutoRefresh() {
        stopPeriodicAutoRefresh()

        // Timer refresh per 60 detik (1 menit)
        periodicRefreshTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.syncState.role == .parent {
                    await self.loadParentLocalHealthData()
                    if let code = self.syncState.inviteCode, self.syncState.status == .accepted {
                        await self.pushParentHealthData(code: code)
                    }
                } else if self.syncState.status == .accepted {
                    await self.fetchSharedParentSnapshot()
                }
            }
        }

        // Observer Query untuk deteksi sampel Heart Rate baru di Apple Health
        if syncState.role == .parent {
            heartRateObserverQuery = healthKit.startHeartRateObserver { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if self.syncState.role == .parent {
                        await self.loadParentLocalHealthData()
                    }
                }
            }
        }
    }

    func stopPeriodicAutoRefresh() {
        periodicRefreshTimer?.invalidate()
        periodicRefreshTimer = nil
        if let query = heartRateObserverQuery {
            healthKit.stopHeartRateObserver(query)
            heartRateObserverQuery = nil
        }
    }

    // MARK: - Native Apple CKShare (One-Way: Read-Only) & Single-Use Invites

    /// Generates a fresh, single-use invite code and prepares the share link.
    func prepareSingleUseShareInvite() async -> (code: String, rawURL: String) {
        let uniqueCode = "ART-" + String(UUID().uuidString.prefix(6)).uppercased()
        let realName = !userDisplayName.isEmpty ? userDisplayName : (UIDevice.current.name.isEmpty ? "Orang Tua" : UIDevice.current.name)
        let pName = (parentName.isEmpty || parentName == "Nama Ortu 1" || parentName == "iPhone") ? realName : parentName
        let encodedName = pName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? pName

        // 1. Create one-time invite record in CloudKit with status = "pending"
        try? await cloudKit.createInvite(code: uniqueCode, parentName: pName)

        // 2. Set parent state to pending with this new code
        self.syncState.inviteCode = uniqueCode
        self.syncState.status = .pending
        self.syncState.partnerName = nil
        self.lastSyncDate = Date()
        persistState()

        // 3. Load local data without duplicate background task push
        await loadParentLocalHealthData(autoPushToCloud: false)
        if let record = self.healthRecord {
            let summary = await self.healthKit.fetchTodaySummary()
            try? await self.cloudKit.pushHealthSnapshot(summary, record: record, inviteCode: uniqueCode, parentName: pName)
            try? await self.cloudKit.pushHealthRecord(record)
        }

        // 4. If native CKShare exists or can be created, embed the unique code in the deep link
        var nativeShareURL: String? = nil
        if let share = await requestNativeShare(suppressErrorMessage: true), let shareURL = share.url?.absoluteString {
            nativeShareURL = shareURL
        }

        let rawURL: String
        if let shareURL = nativeShareURL {
            let encodedShareURL = shareURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? shareURL
            rawURL = "arterious://accept-share?code=\(uniqueCode)&from=\(encodedName)&url=\(encodedShareURL)"
        } else {
            rawURL = "arterious://accept-share?code=\(uniqueCode)&from=\(encodedName)"
        }

        return (uniqueCode, rawURL)
    }

    /// Prepares a native `CKShare` and uploads the latest HealthKit data.
    /// Returns the `CKShare` to be presented in `UICloudSharingController` or Share Sheet.
    func requestNativeShare(suppressErrorMessage: Bool = false) async -> CKShare? {
        if let existing = nativeShare {
            return existing
        }

        isLoading = true
        if !suppressErrorMessage { errorMessage = nil }
        defer { isLoading = false }

        do {
            let name = UIDevice.current.name.isEmpty ? "Orang Tua" : UIDevice.current.name
            let share = try await cloudKit.getOrCreateNativeShare(parentName: name)
            self.nativeShare = share
            self.inviteURL = share.url
            print("✅ Native CKShare ready: \(share.url?.absoluteString ?? "no url")")
            return share
        } catch {
            print("❌ requestNativeShare error: \(error)")
            if !suppressErrorMessage {
                let desc = error.localizedDescription
                if desc.localizedCaseInsensitiveContains("container configuration") || desc.localizedCaseInsensitiveContains("Bad Container") {
                    print("ℹ️ Native CKShare container not configured on Apple portal yet; fallback sharing link active.")
                } else {
                    self.errorMessage = formatUserFriendlyErrorMessage(error)
                }
            }
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
        // Prevent concurrent processing race conditions
        guard !isProcessingInvite else {
            print("⏳ [SyncViewModel] Already processing an invite, skipping duplicate invocation.")
            return
        }

        isProcessingInvite = true
        isLoading = true
        errorMessage = nil
        defer {
            isProcessingInvite = false
            isLoading = false
        }

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

            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let codeFromQuery = components?.queryItems?.first(where: { $0.name == "code" })?.value
            let pNameFromQuery = components?.queryItems?.first(where: { $0.name == "from" })?.value ?? "Orang Tua"
            let targetURLStr = components?.queryItems?.first(where: { $0.name == "url" })?.value

            // Extract invite code
            guard let inviteCode = codeFromQuery, !inviteCode.isEmpty else {
                // If it's a raw iCloud URL without code, try to accept natively or report error
                if let targetURL = URL(string: targetURLStr ?? urlString), urlString.contains("icloud.com/share") {
                    do {
                        let (pName, share) = try await cloudKit.acceptNativeShare(url: targetURL)
                        self.syncState = SyncState(role: .child, inviteCode: "SHARED", status: .accepted, partnerName: pName, lastSyncDate: Date())
                        self.parentName = pName
                        UserDefaults.standard.set(pName, forKey: "savedParentName")
                        self.nativeShare = share
                        persistState()
                        await fetchSharedParentSnapshot()
                        self.bannerMessage = "Undangan diterima dari \(pName)! Data kesehatan kini terhubung."
                        self.showAcceptedBanner = true
                        return
                    } catch {
                        self.errorMessage = "Tautan undangan tidak memiliki kode valid."
                        return
                    }
                }
                self.errorMessage = "Tautan undangan tidak valid atau tidak memiliki kode aktivasi."
                return
            }

            // If already accepted on this device, don't re-validate or throw error
            if syncState.status == .accepted && syncState.inviteCode == inviteCode {
                print("✅ [SyncViewModel] Invite \(inviteCode) already active, refreshing data.")
                await fetchSharedParentSnapshot()
                return
            }

            // CRITICAL: Validate and accept the single-use invite in CloudKit!
            let childDeviceName = !userDisplayName.isEmpty ? userDisplayName : (UIDevice.current.name.isEmpty ? "Anak" : UIDevice.current.name)
            do {
                let validatedParentName = try await cloudKit.validateAndAcceptInvite(code: inviteCode, childName: childDeviceName)
                let finalParentName = validatedParentName.isEmpty ? pNameFromQuery : validatedParentName

                // If native share URL was provided, attempt native share accept as well
                if let targetStr = targetURLStr, let nativeURL = URL(string: targetStr) {
                    if let (_, share) = try? await cloudKit.acceptNativeShare(url: nativeURL) {
                        self.nativeShare = share
                    }
                }

                self.syncState = SyncState(
                    role: .child,
                    inviteCode: inviteCode,
                    status: .accepted,
                    partnerName: finalParentName,
                    lastSyncDate: Date()
                )
                self.parentName = finalParentName
                UserDefaults.standard.set(finalParentName, forKey: "savedParentName")
                persistState()

                await triggerAcceptNotification(parentName: finalParentName)
                await subscribeAndFetch(code: inviteCode)

                self.bannerMessage = "Berhasil terhubung dengan data kesehatan \(finalParentName)!"
                self.showAcceptedBanner = true
                self.connectionSuccessMessage = "Kamu sekarang terhubung dengan \(finalParentName)! Data aktivitas, tidur, dan detak jantung dapat dipantau langsung di Beranda."
                self.showConnectionSuccessModal = true
            } catch let syncError as SyncError {
                print("❌ [SyncViewModel] validateAndAcceptInvite SyncError: \(syncError.localizedDescription)")
                self.errorMessage = syncError.errorDescription
                return
            } catch {
                print("❌ [SyncViewModel] validateAndAcceptInvite unexpected error: \(error)")
                self.errorMessage = formatUserFriendlyErrorMessage(error)
                return
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
        let history = await healthKit.fetchHistoricalSummaries(days: 14)
        let name = UIDevice.current.name.isEmpty ? "Orang Tua" : UIDevice.current.name
        let pName = (parentName.isEmpty || parentName == "Nama Ortu 1") ? name : parentName

        let (overview, promptInput) = RuleEngine.shared.evaluate(
            today: summary,
            history: history,
            parentDisplayName: pName == "Saya" ? "Ibu" : pName
        )
        self.evaluatedOverview = overview
        self.baseline = overview.baseline

        var overviewSummaryText = overview.statusBadge
        if let existingOutput = self.insightOutput {
            overviewSummaryText = existingOutput.todayOverview.summary
        } else if shouldCallGeminiAPI(for: overview, forceRefresh: false) {
            if let (output, _) = try? await GeminiService.shared.generateInsight(input: promptInput) {
                let cleaned = RuleEngine.shared.sanitizeInsightOutput(output, overview: overview)
                self.insightOutput = cleaned
                self.lastGeminiCallDate = Date()
                overviewSummaryText = cleaned.todayOverview.summary
            }
        } else {
            let fallback = RuleEngine.shared.makeLocalFallbackInsight(from: overview, parentName: pName == "Saya" ? "Ibu" : pName)
            self.insightOutput = fallback
            overviewSummaryText = fallback.todayOverview.summary
        }

        let record = HealthRecord.create(
            from: summary,
            inviteCode: code,
            parentName: pName,
            history: history,
            overviewTitle: overview.headline,
            overviewBody: overviewSummaryText,
            activityStatusBadge: overview.activity.status,
            sleepStatusBadge: overview.sleep.status,
            heartStatusBadge: overview.heart.status,
            insightOutput: self.insightOutput
        )

        do {
            try await cloudKit.pushHealthSnapshot(summary, record: record, inviteCode: code, parentName: pName)
            try await cloudKit.pushHealthRecord(record)

            lastSyncDate = Date()
            syncState.lastSyncDate = lastSyncDate
            healthRecord = record
            errorMessage = nil
            persistState()
            print("✅ Successfully pushed HealthRecord for code: \(code) on date: \(record.formattedDate)")
        } catch {
            print("⚠️ Push parent health data background error: \(error)")
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
                
                if let fullRecord = result.record {
                    self.healthRecord = fullRecord
                    self.insightOutput = fullRecord.insightOutput ?? makeInsightOutput(from: fullRecord)
                    self.synthesizeHistoryIfEmpty(from: fullRecord)
                } else {
                    let (overview, _) = RuleEngine.shared.evaluate(
                        today: result.summary,
                        history: self.historicalSummaries,
                        parentDisplayName: result.parentName
                    )
                    let fallback = RuleEngine.shared.makeLocalFallbackInsight(from: overview, parentName: result.parentName)
                    self.insightOutput = fallback
                    self.healthRecord = HealthRecord.create(
                        from: result.summary,
                        inviteCode: syncState.inviteCode ?? "SHARED",
                        parentName: result.parentName,
                        history: self.historicalSummaries,
                        overviewTitle: overview.headline,
                        overviewBody: fallback.todayOverview.summary,
                        activityStatusBadge: overview.activity.status,
                        sleepStatusBadge: overview.sleep.status,
                        heartStatusBadge: overview.heart.status,
                        insightOutput: fallback
                    )
                }
                
                syncState.partnerName = result.parentName
                syncState.lastSyncDate = result.updatedAt
                syncState.status = .accepted
                persistState()
                onSnapshotUpdated?()
                return
            }

            // 2. Fallback to public database with inviteCode or default to "SHARED"
            let code = syncState.inviteCode ?? "SHARED"
            await fetchParentSnapshot(code: code)
        } catch {
            print("⚠️ fetchSharedParentSnapshot error: \(error)")
            let code = syncState.inviteCode ?? "SHARED"
            await fetchParentSnapshot(code: code)
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
                self.insightOutput = hr.insightOutput ?? makeInsightOutput(from: hr)
                self.synthesizeHistoryIfEmpty(from: hr)
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

                if let rec = result.record {
                    self.healthRecord = rec
                    self.insightOutput = rec.insightOutput ?? makeInsightOutput(from: rec)
                    self.synthesizeHistoryIfEmpty(from: rec)
                } else if self.healthRecord == nil {
                    let (overview, _) = RuleEngine.shared.evaluate(
                        today: result.summary,
                        history: self.historicalSummaries,
                        parentDisplayName: result.parentName
                    )
                    let fallback = RuleEngine.shared.makeLocalFallbackInsight(from: overview, parentName: result.parentName)
                    self.insightOutput = fallback
                    self.healthRecord = HealthRecord.create(
                        from: result.summary,
                        inviteCode: code,
                        parentName: result.parentName,
                        history: self.historicalSummaries,
                        overviewTitle: overview.headline,
                        overviewBody: fallback.todayOverview.summary,
                        activityStatusBadge: overview.activity.status,
                        sleepStatusBadge: overview.sleep.status,
                        heartStatusBadge: overview.heart.status,
                        insightOutput: fallback
                    )
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

    // MARK: - Child Helpers: HealthRecord to Insight & History Synthesis

    var fallbackInsightFromCurrentRecord: LLMInsightOutput? {
        guard let rec = healthRecord else { return nil }
        return makeInsightOutput(from: rec)
    }

    func makeInsightOutput(from record: HealthRecord) -> LLMInsightOutput {
        let statusUpper: String
        let titleLower = record.summaryTitle.lowercased()
        if titleLower.contains("penurunan") || record.activityStatus.lowercased().contains("menurun") {
            statusUpper = "DECLINED"
        } else if titleLower.contains("meningkat") || titleLower.contains("membaik") {
            statusUpper = "IMPROVED"
        } else {
            statusUpper = "STABLE"
        }
        
        let pName = (record.parentName.isEmpty || record.parentName == "Nama Ortu 1" || record.parentName == "Parent") ? "Ibu" : record.parentName
        
        // Activity domain
        let steps = record.stepCount ?? 0
        let stepAvg = record.recentStepPoints.isEmpty ? 3000.0 : (record.recentStepPoints.reduce(0, +) / Double(record.recentStepPoints.count))
        let stepDelta = stepAvg > 0 ? (((Double(steps) - stepAvg) / stepAvg) * 100.0) : 0.0
        let actInsightText: String
        if steps == 0 && record.stepFormatted == "-" {
            actInsightText = "Belum ada catatan langkah hari ini di Apple Health."
        } else if steps >= 3000 {
            actInsightText = "Pola aktivitas fisik \(pName) hari ini terpantau baik dan mendukung kelenturan pembuluh darah."
        } else {
            actInsightText = "Aktivitas fisik hari ini sedang berjalan. Luangkan waktu untuk mengajak jalan santai ringan."
        }
        
        let actInsight = DomainMetricInsight(
            currentValue: record.stepFormatted == "-" ? "-" : "\(record.stepFormatted) langkah",
            baselineValue: "\(Int(stepAvg)) langkah",
            deltaPercentage: stepDelta,
            status: record.activityStatus,
            insight: actInsightText
        )
        
        // Sleep domain
        let sleep = record.sleepHours ?? 0.0
        let sleepAvg = record.recentSleepPoints.isEmpty ? 7.0 : (record.recentSleepPoints.reduce(0, +) / Double(record.recentSleepPoints.count))
        let sleepDelta = sleepAvg > 0 ? (((sleep - sleepAvg) / sleepAvg) * 100.0) : 0.0
        let sleepAvgHours = Int(sleepAvg)
        let sleepAvgMins = Int(((sleepAvg - Double(sleepAvgHours)) * 60).rounded())
        let sleepInsightText: String
        if sleep == 0 && record.sleepFormatted == "-" {
            sleepInsightText = "Belum ada catatan tidur semalam di Apple Health. Catatan tidur dapat diaktifkan melalui Sleep Focus di iPhone atau Apple Watch."
        } else if sleep < 6.0 {
            sleepInsightText = "Durasi tidur semalam kurang dari 6 jam (\(record.sleepFormatted)). Tanyakan dengan lembut apakah tidur \(pName) nyenyak semalam."
        } else {
            sleepInsightText = "Pola tidur semalam stabil dan memenuhi kebutuhan istirahat harian \(pName)."
        }
        
        let sleepInsight = DomainMetricInsight(
            currentValue: record.sleepFormatted,
            baselineValue: "\(sleepAvgHours)j \(sleepAvgMins)m",
            deltaPercentage: sleepDelta,
            status: record.sleepStatus,
            insight: sleepInsightText
        )
        
        // Heart domain
        let hr = record.displayHeartRate
        let hrAvg = record.recentHeartRatePoints.isEmpty ? 70.0 : (record.recentHeartRatePoints.reduce(0, +) / Double(record.recentHeartRatePoints.count))
        let hrDelta = (hr != nil && hrAvg > 0) ? (((hr! - hrAvg) / hrAvg) * 100.0) : 0.0
        let hrInsightText: String
        if hr == nil {
            hrInsightText = "Detak jantung belum tercatat di Apple Health (memerlukan Apple Watch atau sensor denyut terhubung)."
        } else if let h = hr, h > 85 {
            hrInsightText = "Detak jantung saat santai sedikit meningkat dibanding acuan. Pastikan \(pName) cukup minum air dan beristirahat santai."
        } else {
            hrInsightText = "Detak jantung berada di rentang normal dan stabil."
        }
        
        let heartInsight = DomainMetricInsight(
            currentValue: hr != nil ? "\(Int(hr!)) BPM" : "-",
            baselineValue: "\(Int(hrAvg)) BPM",
            deltaPercentage: hrDelta,
            status: record.heartRateStatus,
            insight: hrInsightText
        )
        
        // Recommended actions
        let actions: [String]
        if statusUpper == "DECLINED" {
            actions = [
                "Hubungi \(pName) dengan nada santai untuk menanyakan kabar dan bagaimana istirahatnya semalam.",
                "Pastikan asupan cairan cukup dan ingatkan untuk tidak memaksakan aktivitas fisik berat.",
                "Cek kembali ritme aktivitas sore nanti untuk melihat apakah ada perbaikan pola."
            ]
        } else {
            actions = [
                "Kondisi \(pName) terpantau baik, sapa seperti biasa untuk menjaga kedekatan.",
                "Dukung kebiasaan jalan santai ringan di sore hari untuk menjaga sirkulasi darah.",
                "Pastikan waktu tidur malam tetap teratur dan nyaman."
            ]
        }
        
        return LLMInsightOutput(
            todayOverview: TodayOverviewInsight(
                conditionStatus: statusUpper,
                statusLabel: record.summaryTitle,
                deltaPercentage: nil,
                summary: record.summaryBody
            ),
            activityInsight: actInsight,
            sleepInsight: sleepInsight,
            heartInsight: heartInsight,
            recommendedActions: actions
        )
    }

    private func synthesizeHistoryIfEmpty(from record: HealthRecord) {
        guard self.historicalSummaries.isEmpty else { return }
        let count = max(record.recentStepPoints.count, record.recentSleepPoints.count, record.recentHeartRatePoints.count)
        guard count > 0 else { return }
        let calendar = Calendar.current
        var list: [DailyHealthSummary] = []
        for i in 0..<count {
            let offset = (count - 1) - i
            let dayDate = calendar.date(byAdding: .day, value: -offset, to: record.recordDate) ?? record.recordDate
            let hr = i < record.recentHeartRatePoints.count ? record.recentHeartRatePoints[i] : nil
            let sleep = i < record.recentSleepPoints.count ? record.recentSleepPoints[i] : nil
            let steps = i < record.recentStepPoints.count ? record.recentStepPoints[i] : nil
            list.append(DailyHealthSummary(
                date: dayDate,
                latestHeartRate: hr,
                restingHeartRate: hr,
                sleepHours: sleep,
                stepCount: steps
            ))
        }
        self.historicalSummaries = list
    }

    // MARK: - Refresh on Foreground

    func refreshIfNeeded() async {
        let appStorageRole = UserDefaults.standard.string(forKey: "userRole")
        if appStorageRole == UserRole.parent.rawValue && syncState.role != .parent {
            syncState.role = .parent
        } else if appStorageRole == UserRole.child.rawValue && syncState.role != .child {
            syncState.role = .child
        }

        switch syncState.role {
        case .child:
            guard syncState.status == .accepted, let code = syncState.inviteCode, !code.isEmpty else {
                return
            }

            // 1. Check if the connection has been revoked by parent in CloudKit
            if let details = try? await cloudKit.fetchInviteDetails(code: code) {
                if details.status == "revoked" {
                    print("ℹ️ [SyncViewModel] Connection was revoked by parent. Resetting child state.")
                    self.syncState = SyncState(role: .child, inviteCode: nil, status: .none, partnerName: nil, lastSyncDate: nil)
                    self.parentSnapshot = nil
                    self.healthRecord = nil
                    self.insightOutput = nil
                    self.evaluatedOverview = nil
                    self.baseline = nil
                    self.historicalSummaries = []
                    self.persistState()
                    self.errorMessage = "Koneksi data kesehatan telah diputuskan oleh Orang Tua."
                    return
                }
            }

            await fetchSharedParentSnapshot()

        case .parent:
            await loadParentLocalHealthData()

            // Check connection status if parent has an active or pending code
            if let code = syncState.inviteCode, !code.isEmpty {
                if let details = try? await cloudKit.fetchInviteDetails(code: code) {
                    if details.status == "revoked" {
                        print("ℹ️ [SyncViewModel] Connection was revoked by child. Resetting parent active sharing.")
                        self.syncState.status = .none
                        self.syncState.partnerName = nil
                        self.syncState.inviteCode = nil
                        self.persistState()
                    } else if details.status == "used" {
                        // Child accepted the invitation!
                        if self.syncState.status != .accepted || self.syncState.partnerName == nil {
                            let childName = details.childName ?? "Anak"
                            self.syncState.status = .accepted
                            self.syncState.partnerName = childName
                            self.persistState()
                            self.connectionSuccessMessage = "\(childName) telah berhasil terhubung dan sekarang dapat memantau data kesehatan Anda."
                            self.showConnectionSuccessModal = true
                        }
                    }
                } else if syncState.status == .pending {
                    let (hasAccepted, partnerName) = await cloudKit.checkActiveParticipants()
                    if hasAccepted {
                        let childName = partnerName ?? "Anak"
                        syncState.status = .accepted
                        syncState.partnerName = childName
                        persistState()
                        self.connectionSuccessMessage = "\(childName) telah berhasil terhubung dan sekarang dapat memantau data kesehatan Anda."
                        self.showConnectionSuccessModal = true
                    }
                }

                if syncState.status == .accepted {
                    startParentPushLoop(code: code)
                }
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

        let activeCode = syncState.inviteCode
        let currentRole = syncState.role

        if let code = activeCode, !code.isEmpty {
            await cloudKit.revokeConnection(code: code, revokedBy: currentRole == .parent ? "parent" : "child")
        } else {
            if currentRole == .child {
                await cloudKit.removeParentSubscription()
            } else if currentRole == .parent {
                await cloudKit.revokeParentShare()
            }
        }

        syncState = SyncState(role: currentRole, inviteCode: nil, status: .none, partnerName: nil, lastSyncDate: nil)
        parentSnapshot = nil
        healthRecord = nil
        insightOutput = nil
        evaluatedOverview = nil
        baseline = nil
        historicalSummaries = []
        nativeShare = nil
        inviteURL = nil
        lastSyncDate = nil
        parentName = ""
        UserDefaults.standard.removeObject(forKey: "savedParentName")
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
        if let partner = syncState.partnerName, !partner.isEmpty {
            self.parentName = partner
        } else if let saved = UserDefaults.standard.string(forKey: "savedParentName"), !saved.isEmpty {
            self.parentName = saved
        }
    }

    // MARK: - Smart AI Rate-Limiting & Alert Triggering

    var lastGeminiCallDate: Date? {
        get { UserDefaults.standard.object(forKey: "arterious.lastGeminiCallDate") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "arterious.lastGeminiCallDate") }
    }

    func shouldCallGeminiAPI(for overview: EvaluatedHealthOverview, forceRefresh: Bool = false) -> Bool {
        guard APIConfig.isConfigured else { return false }
        if forceRefresh { return true }

        // 1. Kondisi / trigger berbahaya (misal: penurunan pola atau detak jantung abnormal)
        let isDangerousTrigger = overview.conditionStatus == "DECLINED" ||
                                 overview.heart.status.localizedCaseInsensitiveContains("Perhatian") ||
                                 overview.heart.status.localizedCaseInsensitiveContains("Meningkat")
        if isDangerousTrigger {
            return true
        }

        // 2. Jika kondisi normal/stabil, batasi hanya sekali per hari
        guard let lastDate = lastGeminiCallDate else {
            return true
        }
        return !Calendar.current.isDateInToday(lastDate)
    }

    // MARK: - User-Friendly Error Formatter

    func formatUserFriendlyErrorMessage(_ error: Error) -> String {
        if let syncError = error as? SyncError {
            return syncError.errorDescription ?? "Terjadi kesalahan pada sinkronisasi."
        }

        let nsError = error as NSError
        if nsError.domain == CKErrorDomain {
            let code = CKError.Code(rawValue: nsError.code)
            switch code {
            case .serviceUnavailable, .requestRateLimited, .zoneBusy:
                let retrySec = (nsError.userInfo[CKErrorRetryAfterKey] as? NSNumber)?.intValue ?? 60
                let minutes = max(1, Int(ceil(Double(retrySec) / 60.0)))
                return "Server iCloud sedang sibuk atau dibatasi sementara oleh Apple. Silakan coba kembali dalam \(minutes) menit."
            case .notAuthenticated:
                return "Akun iCloud belum aktif. Silakan masuk ke Apple ID di Pengaturan iPhone Anda."
            case .networkFailure, .networkUnavailable:
                return "Koneksi internet bermasalah. Pastikan perangkat terhubung ke internet."
            case .quotaExceeded:
                return "Kapasitas penyimpanan iCloud penuh."
            default:
                break
            }
        }

        let desc = error.localizedDescription
        if desc.localizedCaseInsensitiveContains("throttled") || desc.localizedCaseInsensitiveContains("503") {
            return "Server iCloud sedang sibuk. Silakan coba kembali dalam beberapa menit."
        }
        return desc
    }
}
