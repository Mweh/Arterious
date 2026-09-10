//
//  LLMInsightViewModel.swift
//  Arterious
//
//  ViewModel untuk Caregiver Insight:
//  Mengambil data HealthKit harian & riwayat 14 hari, mengevaluasi deviasi vs baseline
//  melalui RuleEngine, dan memanggil Gemini API untuk menghasilkan insight terstruktur.
//

import Foundation
import Observation
import HealthKit

@Observable
@MainActor
final class LLMInsightViewModel {
    
    // MARK: - Published State
    
    /// Status loading data & analisis AI
    var isLoading: Bool = false
    
    /// Pesan kesalahan jika terjadi kegagalan jaringan atau parsing
    var errorMessage: String?
    
    /// Ringkasan evaluasi lokal dari RuleEngine (selalu tersedia langsung dari data HealthKit)
    var evaluatedOverview: EvaluatedHealthOverview?
    
    /// Data Baseline 14 Hari yang dihitung dari riwayat HealthKit
    var baseline14Days: HealthBaseline?
    
    /// Output insight terstruktur dari Gemini API (Today's Overview + Activity + Sleep + Heart + Actions)
    var insightOutput: LLMInsightOutput?
    
    /// Menandakan apakah teks insight saat ini berasal dari Rule Engine lokal (karena API key invalid, offline, atau fallback)
    var isUsingLocalRuleFallback: Bool = false
    
    /// Nama orang tua yang dipantau
    var parentName: String = "Ibu"
    
    // MARK: - Real-time Heart Rate State
    
    var liveHeartRate: Double?
    var liveHeartRateDate: Date?
    var isWorkoutActive: Bool = false
    var recentWorkoutName: String? = nil
    
    // MARK: - Dependencies
    
    private let healthKitManager: HealthKitManager
    private let ruleEngine: RuleEngine
    private let geminiService: GeminiService
    @ObservationIgnored private var heartRateObserverQuery: HKQuery?
    @ObservationIgnored private var refreshTimer: Timer?
    
    // MARK: - Initialization
    
    init(
        healthKitManager: HealthKitManager? = nil,
        ruleEngine: RuleEngine? = nil,
        geminiService: GeminiService? = nil,
        autoFetch: Bool = false
    ) {
        self.healthKitManager = healthKitManager ?? HealthKitManager.shared
        self.ruleEngine = ruleEngine ?? RuleEngine.shared
        self.geminiService = geminiService ?? GeminiService.shared
        
        if autoFetch {
            Task {
                await loadAndGenerateInsight()
            }
        }
    }
    
    // MARK: - Data Fetch & AI Insight Generation
    
    /// Mengambil data HealthKit, mengevaluasi baseline 14 hari, dan memanggil Gemini
    func loadAndGenerateInsight(forceRefresh: Bool = false) async {
        isLoading = true
        errorMessage = nil
        
        // 0. Minta izin akses HealthKit jika belum
        try? await healthKitManager.requestAuthorization()
        
        // 1. Ambil data hari ini dan riwayat 14 hari dari HealthKit
        let today = await healthKitManager.fetchTodaySummary()
        let history = await healthKitManager.fetchHistoricalSummaries(days: 14)
        
        // Simpan state real-time terkini
        self.liveHeartRate = today.latestHeartRate
        self.liveHeartRateDate = today.latestHeartRateDate
        self.isWorkoutActive = today.isWorkoutActive
        self.recentWorkoutName = today.recentWorkoutName
        
        // 2. Evaluasi lokal terhadap baseline menggunakan RuleEngine
        let (overview, promptInput) = ruleEngine.evaluate(
            today: today,
            history: history,
            parentDisplayName: parentName
        )
        self.evaluatedOverview = overview
        self.baseline14Days = overview.baseline
        
        // 3. Panggil Gemini API hanya jika ada trigger berbahaya atau belum ada insight hari ini
        let shouldCallAI = shouldCallGeminiAPI(for: overview, forceRefresh: forceRefresh)
        if shouldCallAI && APIConfig.isConfigured {
            do {
                let (output, _) = try await geminiService.generateInsight(input: promptInput)
                self.insightOutput = sanitizeInsightOutput(output, overview: overview)
                self.isUsingLocalRuleFallback = false
                UserDefaults.standard.set(Date(), forKey: "arterious.lastGeminiCallDate")
            } catch {
                self.errorMessage = error.localizedDescription
                // Fallback: Buat insight dari rule engine jika API error / key palsu
                self.isUsingLocalRuleFallback = true
                self.insightOutput = makeLocalFallbackInsight(from: overview)
            }
        } else if self.insightOutput != nil, !forceRefresh {
            // Gunakan insight yang sudah ada untuk hari ini
            self.isUsingLocalRuleFallback = false
        } else {
            // Jika kondisi stabil dan sudah ada evaluasi harian, gunakan kalkulasi aturan lokal
            self.isUsingLocalRuleFallback = true
            self.insightOutput = makeLocalFallbackInsight(from: overview)
        }
        
        isLoading = false
        
        // 4. Mulai monitoring real-time Heart Rate (60s timer + HKObserverQuery)
        startRealtimeHeartMonitoring()
    }
    
    // MARK: - Real-time Heart Rate Monitoring
    
    func startRealtimeHeartMonitoring() {
        stopRealtimeHeartMonitoring()
        
        // Timer refresh setiap 60 detik
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshLiveHeartRate()
            }
        }
        
        // HealthKit Observer Query untuk mendeteksi sampel HR baru
        heartRateObserverQuery = healthKitManager.startHeartRateObserver { [weak self] in
            Task { @MainActor [weak self] in
                await self?.refreshLiveHeartRate()
            }
        }
    }
    
    func stopRealtimeHeartMonitoring() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        if let query = heartRateObserverQuery {
            healthKitManager.stopHeartRateObserver(query)
            heartRateObserverQuery = nil
        }
    }
    
    func refreshLiveHeartRate() async {
        let (latestHR, latestDate) = await healthKitManager.fetchLatestHeartRateWithTime()
        let (isActive, workout) = await healthKitManager.fetchRecentWorkout()
        
        guard let hr = latestHR else { return }
        
        if hr != self.liveHeartRate || isActive != self.isWorkoutActive {
            self.liveHeartRate = hr
            self.liveHeartRateDate = latestDate
            self.isWorkoutActive = isActive
            self.recentWorkoutName = workout
            
            // Re-evaluate heart narrative
            if var overview = self.evaluatedOverview {
                overview.liveHeartRate = hr
                overview.liveHeartRateDate = latestDate
                overview.isWorkoutActive = isActive
                overview.workoutName = workout
                self.evaluatedOverview = overview
                
                if self.isUsingLocalRuleFallback {
                    self.insightOutput = makeLocalFallbackInsight(from: overview)
                }
            }
        }
    }
    
    // MARK: - Local Fallback Generator
    
    private func makeLocalFallbackInsight(from overview: EvaluatedHealthOverview) -> LLMInsightOutput {
        let overviewSummary: String
        switch overview.conditionStatus {
        case "DECLINED":
            overviewSummary = "Kondisi \(parentName) hari ini menunjukkan penurunan \(overview.statusBadge.replacingOccurrences(of: "Penurunan ", with: "")) dibandingkan rata-rata 14 hari terakhir. Sebaiknya luangkan waktu untuk menghubungi atau mengecek keadaannya."
        case "IMPROVED":
            overviewSummary = "Kondisi \(parentName) hari ini menunjukkan perkembangan positif dibandingkan baseline 14 hari. Aktivitas dan kualitas istirahatnya terpantau lebih baik."
        default:
            let baselineStepsInt = Int(overview.baseline.steps)
            if overview.baseline.steps < 3000 {
                overviewSummary = "Kondisi \(parentName) hari ini terpantau stabil dan selaras dengan pola kebiasaan 14 hari terakhir (\(baselineStepsInt) langkah). Namun, berdasarkan acuan kebugaran lansia, target ideal untuk menjaga kesehatan vaskular adalah minimal 3.000–4.000 langkah per hari. Walaupun hari ini stabil, ritme aktivitas \(parentName) baiknya mulai ditingkatkan perlahan (seperti menambah jalan santai 10–15 menit) agar sirkulasi darah lebih optimal dan membantu menjaga kestabilan tekanan darah jangka panjang."
            } else {
                overviewSummary = "Kondisi \(parentName) hari ini terpantau stabil dan selaras dengan pola kebiasaan 14 hari terakhir (\(baselineStepsInt) langkah). Pola aktivitas harian ini sudah sangat baik dalam mendukung kelenturan pembuluh darah dan kesehatan jantung."
            }
        }
        
        let actInsight: String
        if let custom = overview.activity.customInsight, !custom.isEmpty {
            actInsight = custom
        } else if !overview.activity.hasData {
            actInsight = "Belum ada catatan langkah hari ini di Apple Health."
        } else {
            actInsight = "Aktivitas fisik hari ini terpantau stabil dalam rentang yang wajar."
        }
        
        let sleepInsight: String
        if !overview.sleep.hasData {
            sleepInsight = "Belum ada catatan tidur semalam di Apple Health. Catatan tidur dapat diaktifkan melalui Sleep Focus di iPhone atau Apple Watch."
        } else if let custom = overview.sleep.customInsight, !custom.isEmpty {
            sleepInsight = custom
        } else if (overview.sleep.currentValue ?? 8.0) < 6.0 {
            sleepInsight = "Durasi tidur semalam kurang dari 6 jam (\(overview.sleep.formattedCurrent)). Tanyakan dengan lembut apakah tidur \(parentName) nyenyak semalam."
        } else if overview.sleep.deltaPercentage >= 10.0 {
            sleepInsight = "Waktu tidur semalam cukup panjang dan memenuhi kebutuhan istirahat harian."
        } else {
            sleepInsight = "Pola tidur semalam stabil dan sesuai dengan durasi acuan biasa."
        }
        
        let heartInsight: String
        if let custom = overview.heart.customInsight, !custom.isEmpty {
            heartInsight = custom
        } else if !overview.heart.hasData {
            heartInsight = "Detak jantung belum tercatat di Apple Health (memerlukan Apple Watch atau sensor denyut terhubung)."
        } else if overview.heart.deltaPercentage >= 10.0 {
            heartInsight = "Detak jantung istirahat sedikit meningkat dibanding baseline. Ingatkan untuk cukup minum air dan jangan terlalu lelah."
        } else {
            heartInsight = "Denyut jantung istirahat berada di rentang normal dan stabil."
        }
        
        return LLMInsightOutput(
            todayOverview: TodayOverviewInsight(
                conditionStatus: overview.conditionStatus,
                statusLabel: overview.statusBadge,
                deltaPercentage: overview.dominantDeltaPercentage,
                summary: overviewSummary
            ),
            activityInsight: DomainMetricInsight(
                currentValue: overview.activity.formattedCurrent,
                baselineValue: overview.activity.formattedBaseline,
                deltaPercentage: overview.activity.deltaPercentage,
                status: overview.activity.status,
                insight: actInsight
            ),
            sleepInsight: DomainMetricInsight(
                currentValue: overview.sleep.formattedCurrent,
                baselineValue: overview.sleep.formattedBaseline,
                deltaPercentage: overview.sleep.deltaPercentage,
                status: overview.sleep.status,
                insight: sleepInsight
            ),
            heartInsight: DomainMetricInsight(
                currentValue: overview.heart.formattedCurrent,
                baselineValue: overview.heart.formattedBaseline,
                deltaPercentage: overview.heart.deltaPercentage,
                status: overview.heart.status,
                insight: heartInsight
            ),
            recommendedActions: overview.allowedActions
        )
    }
    
    // MARK: - Output Sanitizer
    
    private func sanitizeInsightOutput(_ output: LLMInsightOutput, overview: EvaluatedHealthOverview) -> LLMInsightOutput {
        // PERINGATAN ARSITEKTUR: Rule Engine & Apple HealthKit adalah SINGLE SOURCE OF TRUTH.
        // Seluruh nilai numerik (currentValue, baselineValue, deltaPercentage, status, badge)
        // WAJIB diambil langsung dari Apple HealthKit / RuleEngine, BUKAN dari AI generate.
        // AI Gemini HANYA menyuplai teks narasi empati (summary, insight, recommendedActions).
        
        let cleanedOverview = TodayOverviewInsight(
            conditionStatus: overview.conditionStatus,
            statusLabel: overview.statusBadge,
            deltaPercentage: overview.dominantDeltaPercentage,
            summary: output.todayOverview.summary
        )
        
        let cleanedActivity = DomainMetricInsight(
            currentValue: overview.activity.formattedCurrent,
            baselineValue: overview.activity.formattedBaseline,
            deltaPercentage: overview.activity.deltaPercentage,
            status: overview.activity.status,
            insight: overview.activity.hasData ? output.activityInsight.insight : (overview.activity.customInsight ?? "Belum ada catatan langkah hari ini di Apple Health.")
        )
        
        let cleanedSleep = DomainMetricInsight(
            currentValue: overview.sleep.formattedCurrent,
            baselineValue: overview.sleep.formattedBaseline,
            deltaPercentage: overview.sleep.deltaPercentage,
            status: overview.sleep.status,
            insight: overview.sleep.hasData ? output.sleepInsight.insight : (overview.sleep.customInsight ?? "Belum ada catatan tidur semalam di Apple Health. Catatan tidur dapat diaktifkan melalui Sleep Focus di iPhone atau Apple Watch.")
        )
        
        let cleanedHeart = DomainMetricInsight(
            currentValue: overview.heart.formattedCurrent,
            baselineValue: overview.heart.formattedBaseline,
            deltaPercentage: overview.heart.deltaPercentage,
            status: overview.heart.status,
            insight: overview.heart.hasData ? output.heartInsight.insight : (overview.heart.customInsight ?? "Detak jantung belum tercatat di Apple Health (memerlukan Apple Watch atau sensor denyut terhubung).")
        )
        
        return LLMInsightOutput(
            todayOverview: cleanedOverview,
            activityInsight: cleanedActivity,
            sleepInsight: cleanedSleep,
            heartInsight: cleanedHeart,
            recommendedActions: output.recommendedActions
        )
    }
    
    // MARK: - Smart AI Rate-Limiting & Alert Triggering
    
    private func shouldCallGeminiAPI(for overview: EvaluatedHealthOverview, forceRefresh: Bool = false) -> Bool {
        guard APIConfig.isConfigured else { return false }
        if forceRefresh { return true }
        
        // 1. Kondisi / trigger berbahaya (misal: penurunan pola atau detak jantung abnormal saat santai)
        let isDangerousTrigger = overview.conditionStatus == "DECLINED" ||
                                 overview.heart.status.localizedCaseInsensitiveContains("Perhatian") ||
                                 overview.heart.status.localizedCaseInsensitiveContains("Meningkat")
        if isDangerousTrigger {
            return true
        }
        
        // 2. Selebihnya batasi hanya sekali per hari
        guard let lastDate = UserDefaults.standard.object(forKey: "arterious.lastGeminiCallDate") as? Date else {
            return true
        }
        return !Calendar.current.isDateInToday(lastDate)
    }
}
