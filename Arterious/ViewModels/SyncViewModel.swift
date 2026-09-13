import Foundation
import Observation
import UIKit
import CloudKit
import HealthKit
import UserNotifications
import Contacts

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
    var parentName: String = "Orang Tua"
    var lastSyncDate: Date?

    /// Evaluasi lengkap dari RuleEngine
    var evaluatedOverview: EvaluatedHealthOverview?
    var baseline: HealthBaseline?

    /// Output AI Insight lengkap (Today's Overview + Domain metrics + Recommended actions)
    var insightOutput: LLMInsightOutput?
    var isUsingLocalRuleFallback: Bool = false

    /// AI Insight yang tersimpan per tanggal ("yyyy-MM-dd")
    var historicalInsights: [String: LLMInsightOutput] = [:]

    /// Deep link trigger to open parent share flow when requested by child
    var shouldShowParentShareFlow: Bool = false
    var pendingParentShareName: String = "Anak"

    /// Role mismatch alert state when opening a link intended for the other role
    var showRoleMismatchAlert: Bool = false
    var roleMismatchMessage: String = ""
    var pendingRoleSwitchTarget: SyncRole? = nil

    /// Native Apple-style centered status HUD state (check/x)
    var connectionHUD: ConnectionHUDState? = nil

    /// Banner toast state for child when share is accepted (legacy fallback)
    var showAcceptedBanner: Bool = false
    var bannerMessage: String = ""

    /// Connection success modal for both Child and Parent POV
    var showConnectionSuccessModal: Bool = false
    var connectionSuccessMessage: String = ""

    /// Loading status message during iCloud fetch
    var loadingStatusMessage: String = "Menghubungkan ke iCloud..."

    /// Active only during explicit initial connection / invite acceptance (not periodic sync)
    var isInitialConnecting: Bool = false

    /// Detected clipboard invite URL for prompt
    var detectedClipboardURL: URL? = nil
    var showDetectedClipboardPrompt: Bool = false

    /// Secondary parent name for parent selector sheet
    var secondaryParentName: String? = nil

    /// Holds the active native Apple CKShare for presentation in UICloudSharingController
    var nativeShare: CKShare?

    // MARK: - Native Status HUD Helpers

    func showSuccessHUD(title: String = "Berhasil Terhubung", message: String) {
        self.connectionHUD = ConnectionHUDState(type: .success, title: title, message: message)
    }

    func showFailureHUD(title: String = "Gagal Terhubung", message: String) {
        self.connectionHUD = ConnectionHUDState(type: .failure, title: title, message: message)
    }

    func dismissHUD() {
        self.connectionHUD = nil
    }

    // MARK: - Name Formatting Helpers

    /// Sanitizes and formats the parent's display name to ensure it always cleanly says "Orang Tua"
    /// (or "Orang Tua (Name)") and never "Saya", "Anak", or raw placeholder strings.
    func formattedParentName(_ raw: String?) -> String {
        guard let name = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return "Orang Tua"
        }
        let lower = name.lowercased()
        if lower == "saya" || lower == "anak" || lower == "parent" || lower == "nama ortu 1" || lower == "nama ortu 2" || lower == "iphone" || lower == "keluarga" || lower == "data saya" {
            return "Orang Tua"
        }
        if lower.contains("orang tua") || lower.contains("ortu") || lower.contains("ayah") || lower.contains("ibu") || lower.contains("papa") || lower.contains("mama") {
            return name
        }
        return "Orang Tua (\(name))"
    }

    /// Sanitizes and formats the child's display name for parent display.
    func formattedChildName(_ raw: String?) -> String {
        guard let name = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return "Anak"
        }
        let lower = name.lowercased()
        if lower == "saya" || lower == "parent" || lower == "orang tua" || lower == "iphone" || lower == "data saya" {
            return "Anak"
        }
        if lower.contains("anak") {
            return name
        }
        return "Anak (\(name))"
    }

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
    @ObservationIgnored private var hasExecutedInitialAICall: Bool = false
    @ObservationIgnored private var observerDebounceTask: Task<Void, Never>?
    @ObservationIgnored private var lastHealthDataLoadTime: Date?
    @ObservationIgnored private var isCurrentlyLoadingHealthData: Bool = false
    @ObservationIgnored private var geminiCooldownUntil: Date?

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
    private let historicalInsightsKey = "arterious.historicalInsights"

    init(cloudKit: CloudKitSyncManager? = nil,
         healthKit: HealthKitManager? = nil) {
        self.cloudKit = cloudKit ?? .shared
        self.healthKit = healthKit ?? .shared
        loadPersistedState()
        loadHistoricalInsights()
        if self.insightOutput == nil {
            self.insightOutput = historicalInsights[dateKey(for: Date())]
        }
        startPeriodicAutoRefresh()
        Task {
            _ = await resolveUserDisplayName()
        }
    }

    /// Resolves the user's real first and last name from Contacts "My Card", CloudKit identity, or clean device name
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
            "^Apple\\s*Watch\\s+milik\\s+",
            "^iPhone\\s+",
            "^iPad\\s+",
            "^Apple\\s*Watch\\s+",
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
            if syncState.status == .accepted && syncState.inviteCode != nil && !syncState.inviteCode!.isEmpty {
                await fetchSharedParentSnapshot()
            } else {
                self.healthRecord = nil
                self.parentSnapshot = nil
                self.insightOutput = nil
                self.evaluatedOverview = nil
                self.baseline = nil
                self.historicalSummaries = []
            }
        }
    }

    // MARK: - Parent: Local HealthKit Data Loading

    func loadParentLocalHealthData(forceGemini: Bool = false, autoPushToCloud: Bool = true) async {
        // Debounce: Hindari pemanggilan ganda/beruntun dalam hitungan milidetik
        if isCurrentlyLoadingHealthData && !forceGemini { return }
        if let lastLoad = lastHealthDataLoadTime, Date().timeIntervalSince(lastLoad) < 3.0, !forceGemini { return }
        isCurrentlyLoadingHealthData = true
        isLoading = true
        defer {
            isCurrentlyLoadingHealthData = false
            isLoading = false
        }
        lastHealthDataLoadTime = Date()

        if healthKit.isHealthKitAvailable {
            try? await healthKit.requestAuthorization()
        }
        let summary = await healthKit.fetchTodaySummary()
        let history = await healthKit.fetchHistoricalSummaries(days: 14)

        let pName = (parentName.isEmpty || parentName == "Nama Ortu 1") ? "Saya" : parentName
        let (overview, promptInput) = RuleEngine.shared.evaluate(
            today: summary,
            history: history,
            parentDisplayName: pName == "Saya" ? "anda" : pName
        )
        self.evaluatedOverview = overview
        self.baseline = overview.baseline

        // Tandai bahwa evaluasi kesehatan telah dijalankan
        self.hasExecutedInitialAICall = true

        // Cek apakah perlu memanggil Gemini API:
        // Hanya panggil 1x saat aplikasi awal dijalankan, atau jika ada perubahan/eskalasi kondisi yang signifikan.
        var overviewSummaryText = overview.statusBadge
        let shouldCallAI = shouldCallGeminiAPI(for: overview, forceRefresh: forceGemini)

        if shouldCallAI {
            do {
                let (output, _) = try await GeminiService.shared.generateInsight(input: promptInput)
                let cleaned = RuleEngine.shared.sanitizeInsightOutput(output, overview: overview)
                self.insightOutput = cleaned
                self.isUsingLocalRuleFallback = false
                self.lastGeminiCallDate = Date()
                self.geminiCooldownUntil = nil
                overviewSummaryText = cleaned.todayOverview.summary
            } catch {
                let errorStr = "\(error)"
                let isQuota429 = errorStr.contains("429") || errorStr.contains("RESOURCE_EXHAUSTED")
                if isQuota429 {
                    print("⚠️ [SyncViewModel] Kuota free-tier Gemini habis (HTTP 429 RESOURCE_EXHAUSTED). Menggunakan RuleEngine fallback (cooldown 15 menit).")
                    self.geminiCooldownUntil = Date().addingTimeInterval(900) // 15 menit jeda
                } else {
                    print("⚠️ [SyncViewModel] Gemini error, using rule fallback: \(error.localizedDescription)")
                    self.geminiCooldownUntil = Date().addingTimeInterval(180) // 3 menit jeda
                }
                // Catat waktu panggilan agar tidak melakukan retry beruntun setiap detik
                self.lastGeminiCallDate = Date()
                self.isUsingLocalRuleFallback = true
                let fallback = RuleEngine.shared.makeLocalFallbackInsight(from: overview, parentName: pName == "Saya" ? "anda" : pName)
                self.insightOutput = fallback
                overviewSummaryText = fallback.todayOverview.summary
            }
        } else if let existing = self.insightOutput {
            self.isUsingLocalRuleFallback = false
            // Selaraskan data metrik domain yang terus terakumulasi (misal langkah hari ini) ke insight yang ada
            let updated = RuleEngine.shared.sanitizeInsightOutput(existing, overview: overview)
            self.insightOutput = updated
            self.saveDailyInsight(updated, for: summary.date)
            overviewSummaryText = updated.todayOverview.summary
        } else if let cachedToday = self.historicalInsights[dateKey(for: Date())] {
            let updated = RuleEngine.shared.sanitizeInsightOutput(cachedToday, overview: overview)
            self.insightOutput = updated
            self.saveDailyInsight(updated, for: summary.date)
            self.isUsingLocalRuleFallback = false
            overviewSummaryText = updated.todayOverview.summary
        } else {
            self.isUsingLocalRuleFallback = true
            let fallback = RuleEngine.shared.makeLocalFallbackInsight(from: overview, parentName: pName == "Saya" ? "anda" : pName)
            self.insightOutput = fallback
            overviewSummaryText = fallback.todayOverview.summary
        }

        // Simpan status kondisi dan push class saat ini agar tidak memicu deteksi eskalasi palsu di putaran refresh berikutnya
        UserDefaults.standard.set(overview.conditionStatus, forKey: "arterious.lastKnownConditionStatus")
        if let pushClass = overview.pushDecision?.pushClass.rawValue {
            UserDefaults.standard.set(pushClass, forKey: "arterious.lastKnownPushClass")
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
        var fullHistory = history
        if !fullHistory.contains(where: { Calendar.current.isDate($0.date, inSameDayAs: summary.date) }) {
            fullHistory.append(summary)
        }
        self.healthRecord = record
        self.historicalSummaries = fullHistory
        self.lastSyncDate = Date()
        if let currentInsight = self.insightOutput {
            self.saveDailyInsight(currentInsight, for: summary.date)
        }
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

        // Observer Query untuk deteksi sampel Heart Rate baru di Apple Health dengan debounce 3 detik
        if syncState.role == .parent {
            heartRateObserverQuery = healthKit.startHeartRateObserver { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.observerDebounceTask?.cancel()
                    self.observerDebounceTask = Task { @MainActor [weak self] in
                        try? await Task.sleep(for: .seconds(3))
                        guard let self, !Task.isCancelled else { return }
                        if self.syncState.role == .parent {
                            await self.loadParentLocalHealthData()
                        }
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
        isInitialConnecting = true
        isLoading = true
        loadingStatusMessage = "Menghubungkan ke Orang Tua..."
        errorMessage = nil
        defer {
            isProcessingInvite = false
            isInitialConnecting = false
            isLoading = false
        }

        let urlString = url.absoluteString

        // 1. Parent receives request from child (arterious://ask-parent?name=...)
        if urlString.contains("ask-parent") || url.host == "ask-parent" {
            // If child accidentally opens ask link, show native HUD
            if syncState.role == .child {
                showFailureHUD(
                    title: "Tautan untuk Orang Tua",
                    message: "Tautan ini harus dibuka di perangkat orang tua Anda."
                )
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
                        let displayParentName = formattedParentName(pName)
                        self.syncState = SyncState(role: .child, inviteCode: "SHARED", status: .accepted, partnerName: displayParentName, lastSyncDate: Date())
                        self.parentName = displayParentName
                        UserDefaults.standard.set(displayParentName, forKey: "savedParentName")
                        self.nativeShare = share
                        persistState()
                        await fetchSharedParentSnapshot()
                        self.showSuccessHUD(
                            title: "Berhasil Terhubung",
                            message: "Terhubung dengan \(displayParentName)"
                        )
                        return
                    } catch {
                        let msg = "Tautan undangan tidak memiliki kode valid."
                        self.errorMessage = msg
                        self.showFailureHUD(title: "Gagal Terhubung", message: msg)
                        return
                    }
                }
                let msg = "Tautan undangan tidak valid atau tidak memiliki kode aktivasi."
                self.errorMessage = msg
                self.showFailureHUD(title: "Gagal Terhubung", message: msg)
                return
            }

            // If already accepted on this device, don't re-validate or throw error
            if syncState.status == .accepted && syncState.inviteCode == inviteCode {
                print("✅ [SyncViewModel] Invite \(inviteCode) already active, refreshing data.")
                await fetchSharedParentSnapshot()
                let displayParentName = formattedParentName(self.parentName)
                self.showSuccessHUD(
                    title: "Berhasil Terhubung",
                    message: "Terhubung dengan \(displayParentName)"
                )
                return
            }

            // CRITICAL: Validate and accept the single-use invite in CloudKit!
            let childDeviceName = !userDisplayName.isEmpty ? userDisplayName : (UIDevice.current.name.isEmpty ? "Anak" : UIDevice.current.name)
            do {
                let validatedParentName = try await cloudKit.validateAndAcceptInvite(code: inviteCode, childName: childDeviceName)
                let resolvedParentName = validatedParentName.isEmpty ? pNameFromQuery : validatedParentName
                let displayParentName = formattedParentName(resolvedParentName)

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
                    partnerName: displayParentName,
                    lastSyncDate: Date()
                )
                self.parentName = displayParentName
                UserDefaults.standard.set(displayParentName, forKey: "savedParentName")
                persistState()

                await triggerAcceptNotification(parentName: displayParentName)
                await subscribeAndFetch(code: inviteCode)

                self.showSuccessHUD(
                    title: "Berhasil Terhubung",
                    message: "Terhubung dengan \(displayParentName)"
                )
            } catch let syncError as SyncError {
                print("❌ [SyncViewModel] validateAndAcceptInvite SyncError: \(syncError.localizedDescription)")
                let msg = syncError.errorDescription ?? "Gagal memvalidasi undangan."
                self.errorMessage = msg
                self.showFailureHUD(title: "Gagal Terhubung", message: msg)
                return
            } catch {
                print("❌ [SyncViewModel] validateAndAcceptInvite unexpected error: \(error)")
                let msg = formatUserFriendlyErrorMessage(error)
                self.errorMessage = msg
                self.showFailureHUD(title: "Gagal Terhubung", message: msg)
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
        guard !trimmed.isEmpty else {
            self.showFailureHUD(title: "Tautan Kosong", message: "Silakan salin tautan undangan terlebih dahulu.")
            return false
        }

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

        self.showFailureHUD(
            title: "Gagal Terhubung",
            message: "Tautan tidak dikenali. Pastikan Anda menempel tautan Arterious atau iCloud yang valid."
        )
        return false
    }

    /// Checks the clipboard for invitations when child opens app (Disabled in favor of user-initiated manual paste in Access tab)
    func checkClipboardForInvitation() {
        // Dinonaktifkan: Anak menempel tautan secara sadar melalui tab Akses
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
            let msg = "Link undangan tidak valid."
            errorMessage = msg
            showFailureHUD(title: "Gagal Terhubung", message: msg)
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let details = (try? await cloudKit.fetchInviteDetails(code: code)) ?? InviteDetails(
            code: code,
            status: "accepted",
            senderRole: syncState.role == .parent ? "child" : "parent",
            senderName: "Orang Tua"
        )

        if details.senderRole == "parent" || syncState.role == .child {
            let displayParentName = formattedParentName(details.senderName)
            syncState = SyncState(
                role: .child,
                inviteCode: code,
                status: .accepted,
                partnerName: displayParentName,
                lastSyncDate: Date()
            )
            self.parentName = displayParentName
            persistState()

            Task {
                try? await cloudKit.acceptInvite(code: code)
                await subscribeAndFetch(code: code)
            }

            self.showSuccessHUD(
                title: "Berhasil Terhubung",
                message: "Terhubung dengan \(displayParentName)"
            )
        } else {
            let displayChildName = formattedChildName(details.childName ?? details.senderName)
            syncState = SyncState(
                role: .parent,
                inviteCode: code,
                status: .accepted,
                partnerName: displayChildName,
                lastSyncDate: Date()
            )
            persistState()

            Task {
                try? await healthKit.requestAuthorization()
                try? await cloudKit.acceptInvite(code: code)
                await pushParentHealthData(code: code)
                startParentPushLoop(code: code)
            }

            self.showSuccessHUD(
                title: "Berhasil Terhubung",
                message: "Terhubung dengan \(displayChildName)"
            )
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

        let (overview, _) = RuleEngine.shared.evaluate(
            today: summary,
            history: history,
            parentDisplayName: pName == "Saya" ? "anda" : pName
        )
        self.evaluatedOverview = overview
        self.baseline = overview.baseline

        var overviewSummaryText = overview.statusBadge
        if let existingOutput = self.insightOutput {
            overviewSummaryText = existingOutput.todayOverview.summary
        } else {
            let fallback = RuleEngine.shared.makeLocalFallbackInsight(from: overview, parentName: pName == "Saya" ? "anda" : pName)
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
            if let currentInsight = self.insightOutput {
                self.saveDailyInsight(currentInsight, for: summary.date)
            }
            errorMessage = nil
            persistState()
            print("✅ Successfully pushed HealthRecord for code: \(code) on date: \(record.formattedDate)")
        } catch {
            print("⚠️ Push parent health data background error: \(error)")
        }
    }

    // MARK: - Child: Fetch Shared Parent Snapshot

    func fetchSharedParentSnapshot() async {
        isLoading = true
        defer { isLoading = false }
        do {
            // 1. Try native CKShare shared database first
            if let result = try await cloudKit.fetchSharedHealthData() {
                parentSnapshot = result.summary
                parentName = result.parentName
                lastSyncDate = result.updatedAt
                
                if let fullRecord = result.record {
                    self.healthRecord = fullRecord
                    let ins = fullRecord.insightOutput ?? makeInsightOutput(from: fullRecord)
                    self.insightOutput = ins
                    self.saveDailyInsight(ins, for: fullRecord.recordDate)
                    self.synthesizeHistoryIfEmpty(from: fullRecord)
                } else {
                    let pDisplayName = (result.parentName.isEmpty || result.parentName == "Nama Ortu 1" || result.parentName == "Parent" || result.parentName == "Saya" || result.parentName.lowercased() == "anda") ? "orang tua" : result.parentName
                    let (overview, _) = RuleEngine.shared.evaluate(
                        today: result.summary,
                        history: self.historicalSummaries,
                        parentDisplayName: pDisplayName
                    )
                    let fallback = RuleEngine.shared.makeLocalFallbackInsight(from: overview, parentName: pDisplayName)
                    self.insightOutput = fallback
                    self.saveDailyInsight(fallback, for: result.summary.date)
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
                    
                    if let push = overview.pushDecision, push.shouldPush {
                        Task {
                            await PushNotificationService.shared.processAndDeliver(push)
                        }
                    }
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
        isLoading = true
        defer { isLoading = false }
        do {
            if let hr = try await cloudKit.fetchLatestHealthRecord(inviteCode: code) {
                self.healthRecord = hr
                let rawInsight = hr.insightOutput ?? makeInsightOutput(from: hr)
                let synchronized = self.synchronizeInsightWithHealthRecord(rawInsight, record: hr)
                self.insightOutput = synchronized
                self.saveDailyInsight(synchronized, for: hr.recordDate)
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
                    let rawInsight = rec.insightOutput ?? makeInsightOutput(from: rec)
                    let synchronized = self.synchronizeInsightWithHealthRecord(rawInsight, record: rec)
                    self.insightOutput = synchronized
                    self.saveDailyInsight(synchronized, for: rec.recordDate)
                    self.synthesizeHistoryIfEmpty(from: rec)
                } else if self.healthRecord == nil {
                    let pDisplayName = (result.parentName.isEmpty || result.parentName == "Nama Ortu 1" || result.parentName == "Parent" || result.parentName == "Saya" || result.parentName.lowercased() == "anda") ? "orang tua" : result.parentName
                    let (overview, _) = RuleEngine.shared.evaluate(
                        today: result.summary,
                        history: self.historicalSummaries,
                        parentDisplayName: pDisplayName
                    )
                    let fallback = RuleEngine.shared.makeLocalFallbackInsight(from: overview, parentName: pDisplayName)
                    self.insightOutput = fallback
                    self.saveDailyInsight(fallback, for: result.summary.date)
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
                    
                    if let push = overview.pushDecision, push.shouldPush {
                        Task {
                            await PushNotificationService.shared.processAndDeliver(push)
                        }
                    }
                }
            }

            if let historyRecords = try? await cloudKit.fetchHealthRecordHistory(inviteCode: code, days: 14) {
                for hRec in historyRecords {
                    if let ins = hRec.insightOutput {
                        self.saveDailyInsight(ins, for: hRec.recordDate)
                    }
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
        if titleLower.contains("penurunan") || titleLower.contains("kurang tidur") || record.activityStatus.lowercased().contains("menurun") {
            statusUpper = "DECLINED"
        } else if titleLower.contains("meningkat") || titleLower.contains("peningkatan") || titleLower.contains("membaik") {
            statusUpper = "IMPROVED"
        } else {
            statusUpper = "STABLE"
        }
        
        let isChild = syncState.role == .child
        let pName: String
        if isChild {
            pName = (record.parentName.isEmpty || record.parentName == "Nama Ortu 1" || record.parentName == "Parent" || record.parentName == "Saya" || record.parentName.lowercased() == "anda") ? "orang tua" : record.parentName
        } else {
            pName = "Anda"
        }
        
        // Activity domain
        let steps = record.stepCount ?? 0
        let stepAvg = record.recentStepPoints.isEmpty ? 3000.0 : (record.recentStepPoints.reduce(0, +) / Double(record.recentStepPoints.count))
        let stepDelta = stepAvg > 0 ? (((Double(steps) - stepAvg) / stepAvg) * 100.0) : 0.0
        let actInsightText: String
        if steps == 0 && record.stepFormatted == "-" {
            actInsightText = "Belum ada catatan langkah kaki hari ini di Apple Health."
        } else {
            actInsightText = "Aktivitas langkah hari ini tercatat \(record.stepFormatted) langkah."
        }
        let actInsight = DomainMetricInsight(
            currentValue: record.stepFormatted == "-" ? "—" : "\(record.stepFormatted) langkah",
            baselineValue: "\(Int(stepAvg)) langkah",
            deltaPercentage: stepDelta,
            status: record.activityStatus,
            insight: actInsightText,
            points: [actInsightText]
        )
        
        // Sleep domain
        let sleepHours = record.sleepHours ?? 0.0
        let sleepAvg = record.recentSleepPoints.isEmpty ? 7.0 : (record.recentSleepPoints.reduce(0, +) / Double(record.recentSleepPoints.count))
        let sleepDelta = sleepAvg > 0 ? (((sleepHours - sleepAvg) / sleepAvg) * 100.0) : 0.0
        let sleepInsightText: String
        if sleepHours == 0 && record.sleepFormatted == "-" {
            sleepInsightText = "Belum ada catatan tidur semalam di Apple Health."
        } else {
            sleepInsightText = "Tidur semalam tercatat \(record.sleepFormatted)."
        }
        let sleepInsight = DomainMetricInsight(
            currentValue: record.sleepFormatted == "-" ? "—" : record.sleepFormatted,
            baselineValue: String(format: "%.1f jam", sleepAvg),
            deltaPercentage: sleepDelta,
            status: record.sleepStatus,
            insight: sleepInsightText,
            points: [sleepInsightText]
        )
        
        // Heart domain
        let hr = record.heartRate ?? 0.0
        let hrAvg = record.recentHeartRatePoints.isEmpty ? 72.0 : (record.recentHeartRatePoints.reduce(0, +) / Double(record.recentHeartRatePoints.count))
        let hrDelta = hrAvg > 0 ? (((hr - hrAvg) / hrAvg) * 100.0) : 0.0
        let hrInsightText: String
        if hr == 0 && record.heartRateStatus == "-" {
            hrInsightText = "Belum ada catatan denyut jantung hari ini di Apple Health."
        } else {
            hrInsightText = "Denyut jantung tercatat \(Int(hr)) bpm."
        }
        let heartInsight = DomainMetricInsight(
            currentValue: hr == 0 ? "—" : "\(Int(hr)) bpm",
            baselineValue: "\(Int(hrAvg)) bpm",
            deltaPercentage: hrDelta,
            status: record.heartRateStatus,
            insight: hrInsightText,
            points: [hrInsightText]
        )
        
        // Recommended actions
        let actions: [String]
        if isChild {
            if statusUpper == "DECLINED" {
                actions = [
                    "Sapa \(pName) dengan hangat dan tanyakan bagaimana istirahatnya hari ini.",
                    "Ingatkan \(pName) untuk santai, cukup minum air, dan tidak perlu memaksakan diri.",
                    "Perhatikan kembali perkembangannya besok pagi tanpa perlu khawatir berlebihan."
                ]
            } else {
                actions = [
                    "Kondisi \(pName) terpantau baik, sapa seperti biasa untuk menjaga kedekatan.",
                    "Dukung kebiasaan jalan santai ringan di sore hari untuk menjaga kebugaran tubuh.",
                    "Pastikan waktu tidur malam tetap teratur dan nyaman."
                ]
            }
        } else {
            if statusUpper == "DECLINED" {
                actions = [
                    "Luangkan waktu untuk beristirahat santai dan tidak memaksakan diri.",
                    "Pastikan asupan air minum cukup sepanjang hari.",
                    "Perhatikan kembali ritme tubuh malam ini dengan tidur lebih awal."
                ]
            } else {
                actions = [
                    "Kondisi tubuh terpantau baik, pertahankan rutinitas sehat Anda.",
                    "Lakukan jalan santai ringan di sore hari untuk menjaga sirkulasi tubuh.",
                    "Jaga waktu istirahat malam tetap teratur dan nyaman."
                ]
            }
        }
        
        return LLMInsightOutput(
            todayOverview: TodayOverviewInsight(
                conditionStatus: statusUpper,
                statusLabel: RuleEngine.unifiedOverviewTitle(conditionStatus: statusUpper, statusBadge: record.summaryTitle),
                deltaPercentage: nil,
                summary: RuleEngine.sanitizeSummaryNarrative(record.summaryBody)
            ),
            activityInsight: actInsight,
            sleepInsight: sleepInsight,
            heartInsight: heartInsight,
            recommendedActions: actions
        )
    }

    func synchronizeInsightWithHealthRecord(_ insight: LLMInsightOutput, record: HealthRecord) -> LLMInsightOutput {
        let formatted = record.stepFormatted
        guard let steps = record.stepCount, steps > 0, formatted != "-" else {
            return insight
        }
        let act = insight.activityInsight
        if act.currentValue == "—" || act.currentValue == "-" || act.currentValue.isEmpty || act.currentValue.contains("0 langkah") {
            let isChild = syncState.role == .child
            let pName = isChild ? (record.parentName.isEmpty ? "orang tua" : record.parentName) : "Anda"
            let baselineText = act.baselineValue.isEmpty ? "3.000 langkah" : act.baselineValue
            let points = [
                isChild
                    ? "Hingga saat ini tercatat \(formatted) langkah dari kebiasaan harian (\(baselineText)). Namun perbedaan ini masih terbilang wajar dan normal karena hari masih berjalan."
                    : "Hingga saat ini tercatat \(formatted) langkah dari kebiasaan harian (\(baselineText)). Namun perbedaan ini masih terbilang wajar dan normal karena hari masih berjalan.",
                isChild
                    ? "Anak tidak perlu cemas; ajak \(pName) tetap bergerak aktif santai seperti jalan-jalan ringan di halaman rumah sesuai kemampuan."
                    : "Tetap bergerak aktif santai sesuai kemampuan tubuh tanpa perlu memaksakan diri."
            ]
            let updatedActivity = DomainMetricInsight(
                currentValue: "\(formatted) langkah",
                baselineValue: act.baselineValue,
                deltaPercentage: act.deltaPercentage,
                status: record.activityStatus,
                insight: points.joined(separator: " "),
                points: points
            )
            return LLMInsightOutput(
                todayOverview: insight.todayOverview,
                activityInsight: updatedActivity,
                sleepInsight: insight.sleepInsight,
                heartInsight: insight.heartInsight,
                recommendedActions: insight.recommendedActions
            )
        }
        return insight
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
                minHeartRate24h: hr,
                maxHeartRate24h: hr,
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
                if self.healthRecord != nil && (syncState.status != .accepted || syncState.inviteCode == nil || syncState.inviteCode!.isEmpty) {
                    self.healthRecord = nil
                    self.parentSnapshot = nil
                    self.insightOutput = nil
                    self.evaluatedOverview = nil
                    self.baseline = nil
                    self.historicalSummaries = []
                }
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
                            let displayChildName = self.formattedChildName(childName)
                            self.syncState.status = .accepted
                            self.syncState.partnerName = displayChildName
                            self.persistState()
                            self.showSuccessHUD(
                                title: "Berhasil Terhubung",
                                message: "Terhubung dengan \(displayChildName)"
                            )
                        }
                    }
                } else if syncState.status == .pending {
                    let (hasAccepted, partnerName) = await cloudKit.checkActiveParticipants()
                    if hasAccepted {
                        let childName = partnerName ?? "Anak"
                        let displayChildName = self.formattedChildName(childName)
                        syncState.status = .accepted
                        syncState.partnerName = displayChildName
                        persistState()
                        self.showSuccessHUD(
                            title: "Berhasil Terhubung",
                            message: "Terhubung dengan \(displayChildName)"
                        )
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
        // Pertahankan historicalInsights agar catatan AI harian tanggal-tanggal sebelumnya tidak terhapus
        evaluatedOverview = nil
        baseline = nil
        historicalSummaries = []
        nativeShare = nil
        inviteURL = nil
        lastSyncDate = nil
        parentName = ""
        UserDefaults.standard.removeObject(forKey: "savedParentName")
        persistState()

        self.showSuccessHUD(
            title: "Berhasil Dihapus",
            message: "Akses data kesehatan telah diputuskan."
        )
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

    // MARK: - Historical AI Insights Management

    func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    func saveDailyInsight(_ insight: LLMInsightOutput?, for date: Date) {
        guard let insight = insight else { return }
        let key = dateKey(for: date)
        historicalInsights[key] = insight
        persistHistoricalInsights()
        print("💾 [SyncViewModel] Saved daily insight for key: \(key) (Status: \(insight.todayOverview.statusLabel))")
    }

    func insight(for date: Date) -> LLMInsightOutput? {
        let key = dateKey(for: date)
        
        // 1. If today and active memory insightOutput exists, return it
        if Calendar.current.isDateInToday(date), let current = insightOutput {
            return current
        }
        
        // 2. If saved in historical dictionary, return it
        if let saved = historicalInsights[key] {
            return saved
        }
        
        // 3. If healthRecord matches this date and contains insightOutput, cache and return it
        if let hr = healthRecord, Calendar.current.isDate(hr.recordDate, inSameDayAs: date), let ins = hr.insightOutput {
            saveDailyInsight(ins, for: hr.recordDate)
            return ins
        }
        
        // 4. On-demand Clinical Rule-Based Evaluation for past dates with recorded health data
        let pDisplayName: String = {
            if syncState.role == .parent {
                return "anda"
            }
            let name = parentName.trimmingCharacters(in: .whitespacesAndNewlines)
            return (name.isEmpty || name == "Nama Ortu 1" || name == "Saya") ? "orang tua" : name
        }()
        
        // Check if there is a summary for this date in historicalSummaries or healthRecord
        let targetSummary: DailyHealthSummary? = {
            if let found = historicalSummaries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
                return found
            }
            if let hr = healthRecord, Calendar.current.isDate(hr.recordDate, inSameDayAs: date) {
                return DailyHealthSummary(
                    date: hr.recordDate,
                    latestHeartRate: hr.displayHeartRate,
                    restingHeartRate: hr.restingHeartRate,
                    sleepHours: hr.sleepHours,
                    stepCount: hr.stepCount.map { Double($0) }
                )
            }
            return nil
        }()
        
        if let summary = targetSummary {
            let hasMetrics = (summary.latestHeartRate ?? 0) > 0 || (summary.sleepHours ?? 0) > 0 || (summary.stepCount ?? 0) > 0
            if hasMetrics {
                let (overview, _) = RuleEngine.shared.evaluate(
                    today: summary,
                    history: self.historicalSummaries,
                    parentDisplayName: pDisplayName
                )
                let fallback = RuleEngine.shared.makeLocalFallbackInsight(from: overview, parentName: pDisplayName)
                saveDailyInsight(fallback, for: date)
                print("⚡️ [SyncViewModel] Generated on-demand rule-based insight for past date \(key)")
                return fallback
            }
        }
        
        return nil
    }

    func hasSavedInsight(for date: Date) -> Bool {
        return insight(for: date) != nil
    }

    func summaryTitle(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            if let title = healthRecord?.summaryTitle, !title.isEmpty {
                return RuleEngine.unifiedOverviewTitle(
                    conditionStatus: healthRecord?.insightOutput?.todayOverview.conditionStatus ?? "",
                    statusBadge: title
                )
            }
            if let ins = insight(for: date) {
                return RuleEngine.unifiedOverviewTitle(
                    conditionStatus: ins.todayOverview.conditionStatus,
                    statusBadge: ins.todayOverview.statusLabel
                )
            }
            return "Kondisi Stabil"
        }

        if let ins = insight(for: date) {
            return RuleEngine.unifiedOverviewTitle(
                conditionStatus: ins.todayOverview.conditionStatus,
                statusBadge: ins.todayOverview.statusLabel
            )
        }

        return "Belum Ada Data"
    }

    func summaryBody(for date: Date) -> String {
        let rawBody: String
        if Calendar.current.isDateInToday(date) {
            if let body = healthRecord?.summaryBody, !body.isEmpty {
                rawBody = body
            } else if let ins = insight(for: date) {
                rawBody = ins.todayOverview.summary
            } else {
                rawBody = "Data detak jantung, tidur, dan langkah tercatat dari Apple Health hari ini."
            }
        } else if let ins = insight(for: date) {
            rawBody = ins.todayOverview.summary
        } else {
            rawBody = "Data detak jantung, tidur, dan langkah tidak tercatat pada tanggal ini."
        }

        return RuleEngine.sanitizeSummaryNarrative(rawBody)
    }

    private func persistHistoricalInsights() {
        if let data = try? JSONEncoder().encode(historicalInsights) {
            UserDefaults.standard.set(data, forKey: historicalInsightsKey)
        }
    }

    private func loadHistoricalInsights() {
        guard let data = UserDefaults.standard.data(forKey: historicalInsightsKey),
              let decoded = try? JSONDecoder().decode([String: LLMInsightOutput].self, from: data) else {
            return
        }
        var sanitized: [String: LLMInsightOutput] = [:]
        for (key, item) in decoded {
            let cleanTitle = RuleEngine.unifiedOverviewTitle(
                conditionStatus: item.todayOverview.conditionStatus,
                statusBadge: item.todayOverview.statusLabel
            )
            let cleanSummary = RuleEngine.sanitizeSummaryNarrative(item.todayOverview.summary)
            let updatedOverview = TodayOverviewInsight(
                conditionStatus: item.todayOverview.conditionStatus,
                statusLabel: cleanTitle,
                deltaPercentage: nil,
                summary: cleanSummary
            )
            sanitized[key] = LLMInsightOutput(
                todayOverview: updatedOverview,
                activityInsight: item.activityInsight,
                sleepInsight: item.sleepInsight,
                heartInsight: item.heartInsight,
                recommendedActions: item.recommendedActions
            )
        }
        self.historicalInsights = sanitized
    }

    // MARK: - Smart AI Rate-Limiting & Alert Triggering (PRD Section 9)

    var lastGeminiCallDate: Date? {
        get { UserDefaults.standard.object(forKey: "arterious.lastGeminiCallDate") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "arterious.lastGeminiCallDate") }
    }

    func shouldCallGeminiAPI(for overview: EvaluatedHealthOverview, forceRefresh: Bool = false) -> Bool {
        guard APIConfig.isConfigured else { return false }

        // 1. Force refresh / Caregiver meminta penjelasan eksplisit
        if forceRefresh { return true }

        // 2. Cooldown check: Jika kuota habis (429) atau sedang error, jangan spam API
        if let cooldown = geminiCooldownUntil, Date() < cooldown {
            return false
        }

        // 3. Urgent event (P4): Jangan panggil LLM untuk pesan utama; gunakan template tetap
        if let push = overview.pushDecision, push.pushClass == .p4 {
            return false
        }

        let calendar = Calendar.current
        let isNewDay: Bool
        if let lastCall = lastGeminiCallDate {
            isNewDay = !calendar.isDate(lastCall, inSameDayAs: Date())
        } else {
            isNewDay = (self.insightOutput == nil && self.historicalInsights[dateKey(for: Date())] == nil)
        }

        // 4. Jika sudah ada insight untuk hari ini:
        // Cek apakah kondisi status dan severity berubah secara signifikan.
        // Jika status sama persis (misal sama-sama STABLE atau sama-sama DECLINED yang sudah dianalisis hari ini),
        // JANGAN panggil Gemini lagi! Tetap gunakan insight yang sudah ada.
        let existingInsight = self.insightOutput ?? self.historicalInsights[dateKey(for: Date())]
        if let existing = existingInsight, !isNewDay {
            let lastKnownStatus = UserDefaults.standard.string(forKey: "arterious.lastKnownConditionStatus") ?? existing.todayOverview.conditionStatus
            let currentStatus = overview.conditionStatus
            
            // Eskalasi hanya jika kondisi sebelumnya bukan DECLINED, lalu sekarang memburuk menjadi DECLINED
            let hasSeverityEscalated = (lastKnownStatus != "DECLINED" && currentStatus == "DECLINED")
            
            let lastKnownPushClass = UserDefaults.standard.string(forKey: "arterious.lastKnownPushClass") ?? "P0"
            let currentPushClass = overview.pushDecision?.pushClass.rawValue ?? "P0"
            let hasPushEscalated = (currentPushClass != lastKnownPushClass && (currentPushClass == "P2" || currentPushClass == "P3"))
            
            if !hasSeverityEscalated && !hasPushEscalated {
                // Fluktuasi ringan (langkah kaki bertambah sedikit, dsb). Tidak perlu hit Gemini berulang-ulang!
                return false
            }
        }

        // 5. Daily overview: Maksimal 1 kali per hari jika belum ada insight sama sekali hari ini
        if !hasExecutedInitialAICall || isNewDay || existingInsight == nil {
            return true
        }

        // 6. Deteksi Concern Baru atau Eskalasi
        let lastKnownStatus = UserDefaults.standard.string(forKey: "arterious.lastKnownConditionStatus") ?? "STABLE"
        let lastKnownPushClass = UserDefaults.standard.string(forKey: "arterious.lastKnownPushClass") ?? "P0"
        let currentPushClass = overview.pushDecision?.pushClass.rawValue ?? "P0"

        let hasSeverityChanged = (overview.conditionStatus != lastKnownStatus && overview.conditionStatus == "DECLINED")
        let hasPushEscalated = (currentPushClass != lastKnownPushClass && (currentPushClass == "P2" || currentPushClass == "P3"))

        if hasSeverityChanged || hasPushEscalated {
            return true
        }

        // 7. Kondisi tetap sama: Gunakan cached insight
        return false
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
                return "Server iCloud sedang sandak atau dibatasi sementara oleh Apple. Silakan coba kembali dalam \(minutes) menit."
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
            return "Server iCloud sedang sandak. Silakan coba kembali dalam beberapa menit."
        }
        return desc
    }
}
