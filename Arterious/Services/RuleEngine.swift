//
//  RuleEngine.swift
//  Arterious
//
//  Mesin evaluasi rule lokal untuk membandingkan data HealthKit hari ini vs baseline 14 hari.
//  Menghasilkan status per domain (Activity, Sleep, Heart) serta Today's Overview dengan angka riil.
//

import Foundation

/// Data evaluasi lengkap per domain metrik
struct EvaluatedDomainMetric {
    let domainName: String
    let currentValue: Double?
    let baselineValue: Double?
    let deltaPercentage: Double
    let status: String // "IMPROVED", "STABLE", "DECLINED", "Belum Ada Data"
    let formattedCurrent: String
    let formattedBaseline: String
    let hasData: Bool
    var customInsight: String? = nil
    var robustEvaluation: RobustEvaluation? = nil
    var baselineSummary: RobustSummary? = nil
    
    var formattedDelta: String {
        guard hasData else { return "—" }
        let sign = deltaPercentage >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", deltaPercentage))%"
    }
}

/// Evaluasi komprehensif hari ini vs baseline
struct EvaluatedHealthOverview {
    let conditionStatus: String // "IMPROVED", "STABLE", "DECLINED", "UNKNOWN"
    let statusBadge: String     // e.g. "Kondisi Stabil", "Perubahan Pola Perlu Diperhatikan", "Kurang Tidur", "Belum Ada Data Sensor"
    let dominantDeltaPercentage: Double
    let baseline: HealthBaseline // Baseline 14 hari yang tersimpan
    let activity: EvaluatedDomainMetric
    let sleep: EvaluatedDomainMetric
    let heart: EvaluatedDomainMetric
    var liveHeartRate: Double? = nil
    var liveHeartRateDate: Date? = nil
    var isWorkoutActive: Bool = false
    var workoutName: String? = nil
    let facts: [String]
    let allowedActions: [String]
    var pushDecision: PushTriageDecision? = nil
    
    var headline: String {
        RuleEngine.unifiedOverviewTitle(conditionStatus: conditionStatus, statusBadge: statusBadge)
    }
}

/// Standar Rujukan Klinis & Jurnal Kesehatan Lansia (Healthy Reference Benchmarks)
struct ClinicalBenchmark {
    // 1. Aktivitas Fisik: 3.000 langkah/hari (Jurnal Geriatri JAMA Lee et al. 2019 / Tudor-Locke et al.)
    static let recommendedStepsSenior: Int = 3000
    static let stepsReferenceNote: String = "3.000 langkah/hari (rujukan minimal aktif jurnal geriatri JAMA)"
    
    // 2. Tidur: 7 - 8 jam/malam (National Sleep Foundation / AASM / PRD Section 10.1)
    static let recommendedSleepMinHours: Double = 7.0
    static let recommendedSleepMaxHours: Double = 8.0
    static let sleepReferenceNote: String = "7–8 jam/malam (standar konsensus medis National Sleep Foundation)"
    
    // 3. Denyut Istirahat: 60 - 80 bpm (American Heart Association / Apple Health Reference)
    static let recommendedRestingHRMin: Int = 60
    static let recommendedRestingHRMax: Int = 80
    static let restingHRReferenceNote: String = "60–80 bpm saat santai (American Heart Association)"
}

@MainActor
final class RuleEngine {
    
    static let shared = RuleEngine()
    
    private init() {}
    
    static func overviewHeadline(for conditionStatus: String) -> String {
        unifiedOverviewTitle(conditionStatus: conditionStatus, statusBadge: "")
    }
    
    /// Menghasilkan judul ringkasan/overview yang 100% konsisten antara kartu ringkasan luar dan halaman detail insight dalam
    /// Bebas persentase sedikit pun (jangan ada persentase), dan akurat sesuai status (misal "Kurang Tidur")
    static func unifiedOverviewTitle(conditionStatus: String, statusBadge: String = "") -> String {
        let badgeLower = statusBadge.lowercased()
        
        // 1. Kondisi spesifik Kurang Tidur (diprioritaskan)
        if badgeLower.contains("kurang tidur") {
            return "Kurang Tidur"
        }
        
        // 2. Perubahan Pola Perlu Diperhatikan
        if badgeLower.contains("perubahan pola") || badgeLower.contains("perlu diperhatikan") {
            return "Perubahan Pola Perlu Diperhatikan"
        }
        
        // 3. Peningkatan / Membaik -> Tanpa persentase sedikit pun
        if conditionStatus.uppercased() == "IMPROVED" || badgeLower.contains("peningkatan") || badgeLower.contains("membaik") || badgeLower.contains("meningkat") {
            return "Kondisi Menunjukkan Peningkatan"
        }
        
        // 4. Penurunan berdasarkan status kondisi
        if conditionStatus.uppercased() == "DECLINED" {
            if badgeLower.contains("tidur") {
                return "Kurang Tidur"
            }
            return "Perubahan Pola Perlu Diperhatikan"
        }
        
        // 5. Belum ada data
        if badgeLower.contains("belum ada data") || conditionStatus.uppercased() == "NO_DATA" {
            return "Belum Ada Data"
        }
        
        // 6. Default stabil
        return "Kondisi Stabil"
    }
    
    /// Membersihkan narasi summary dari kalimat canggung seperti "penurunan Kurang Tidur"
    static func sanitizeSummaryNarrative(_ summary: String) -> String {
        var text = summary
        text = text.replacingOccurrences(of: "penurunan Kurang Tidur", with: "kondisi kurang tidur yang perlu diperhatikan")
        text = text.replacingOccurrences(of: "penurunan kurang tidur", with: "kondisi kurang tidur yang perlu diperhatikan")
        text = text.replacingOccurrences(of: "penurunan Perubahan Pola Perlu Diperhatikan", with: "perubahan pola yang perlu diperhatikan")
        text = text.replacingOccurrences(of: "penurunan perubahan pola perlu diperhatikan", with: "perubahan pola yang perlu diperhatikan")
        return text
    }
    
    // MARK: - Robust Statistics Helpers (PRD BaselineNew.md)
    
    /// Menghitung median dari array terurut (sorted)
    static func calculateMedian(of sortedValues: [Double]) -> Double {
        guard !sortedValues.isEmpty else { return 0.0 }
        let count = sortedValues.count
        if count % 2 == 1 {
            return sortedValues[count / 2]
        } else {
            return (sortedValues[count / 2 - 1] + sortedValues[count / 2]) / 2.0
        }
    }
    
    /// Menghitung persentil (linear interpolation) dari array terurut (PRD Section 16)
    static func calculatePercentile(of sortedValues: [Double], percentile: Double) -> Double {
        guard !sortedValues.isEmpty else { return 0.0 }
        if sortedValues.count == 1 { return sortedValues[0] }
        let p = max(0.0, min(1.0, percentile > 1.0 ? percentile / 100.0 : percentile))
        let rank = p * Double(sortedValues.count - 1)
        let lowerIndex = Int(floor(rank))
        let upperIndex = Int(ceil(rank))
        if lowerIndex == upperIndex {
            return sortedValues[lowerIndex]
        }
        let weight = rank - Double(lowerIndex)
        return sortedValues[lowerIndex] * (1.0 - weight) + sortedValues[upperIndex] * weight
    }
    
    /// Membangun ringkasan statistik robust: Median, MAD, IQR, Fences (PRD Section 7, 8, 16)
    static func buildRobustSummary(values: [Double]) -> RobustSummary? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let n = sorted.count
        
        let med = calculateMedian(of: sorted)
        let q1 = calculatePercentile(of: sorted, percentile: 0.25)
        let q3 = calculatePercentile(of: sorted, percentile: 0.75)
        let iqr = q3 - q1
        
        let deviations = sorted.map { abs($0 - med) }.sorted()
        let mad = calculateMedian(of: deviations)
        let robustSigma = mad > 0 ? (1.4826 * mad) : nil
        let zeroVariability = (mad == 0 && iqr == 0)
        
        let lowerFence = q1 - 1.5 * iqr
        let upperFence = q3 + 1.5 * iqr
        
        let status: BaselineLifecycleStatus
        switch n {
        case 0...2: status = .collectingEarly
        case 3...6: status = .insufficientData
        case 7...9: status = .provisionalBaseline
        default: status = .activeBaseline
        }
        
        let confidence: BaselineConfidence
        switch n {
        case 0..<7: confidence = .none
        case 7...9: confidence = .low
        case 10...12: confidence = .moderate
        default: confidence = .high
        }
        
        return RobustSummary(
            n: n,
            median: med,
            q1: q1,
            q3: q3,
            iqr: iqr,
            mad: mad,
            robustSigma: robustSigma,
            zeroVariability: zeroVariability,
            lowerFence: lowerFence,
            upperFence: upperFence,
            status: status,
            confidence: confidence
        )
    }
    
    /// Mengevaluasi suatu nilai observasi terhadap baseline reference (PRD Section 16)
    static func evaluateAgainstReference(value: Double, summary: RobustSummary) -> RobustEvaluation {
        let delta = value - summary.median
        let lowerFence = summary.q1 - 1.5 * summary.iqr
        let upperFence = summary.q3 + 1.5 * summary.iqr
        let iqrFlag = value < lowerFence || value > upperFence
        
        let robustZ: Double?
        let robustFlag: Bool
        let anomalyScale: String
        
        if summary.mad > 0 {
            let z = delta / (1.4826 * summary.mad)
            robustZ = z
            robustFlag = abs(z) > 3.5
            anomalyScale = "MAD"
        } else {
            robustZ = nil
            robustFlag = false
            anomalyScale = "FALLBACK_REQUIRED"
        }
        
        return RobustEvaluation(
            delta: delta,
            robustZ: robustZ,
            robustFlag: robustFlag,
            iqrFlag: iqrFlag,
            lowerFence: lowerFence,
            upperFence: upperFence,
            anomalyScale: anomalyScale
        )
    }
    
    /// Fungsi eksplisit menghitung baseline 14 hari dari riwayat HealthKit (PRD BaselineNew.md)
    func calculateBaseline(from history: [DailyHealthSummary]) -> HealthBaseline {
        // 1. Filter data valid per domain (Technical validity per PRD Section 5, 6, 11)
        let validSteps = history.compactMap(\.stepCount).filter { $0 > 0 }
        
        let validSleep = history.compactMap { summary -> Double? in
            guard let sleep = summary.sleepHours, sleep > 0 else { return nil }
            if let details = summary.sleepDetails, details.timeInBedMinutes > 0 {
                let sleepMins = sleep * 60.0
                if sleepMins > details.timeInBedMinutes + 5.0 {
                    return nil // Invalid artifact
                }
            }
            return sleep
        }
        
        let validHeart = history.compactMap { $0.latestHeartRate ?? $0.meanHeartRate24h }.filter { $0 > 0 }
        let validRestingHeart = history.compactMap(\.restingHeartRate).filter { $0 > 0 }
        let validSleepDetails = history.compactMap(\.sleepDetails)
        let validEfficiency = validSleepDetails.map(\.sleepEfficiency).filter { $0 > 0 }
        let validAwake = validSleepDetails.map(\.awakeMinutes).filter { $0 >= 0 }
        let validDeep = validSleepDetails.compactMap(\.deepMinutes).filter { $0 > 0 }
        let validRem = validSleepDetails.compactMap(\.remMinutes).filter { $0 > 0 }
        let validCore = validSleepDetails.compactMap(\.coreMinutes).filter { $0 > 0 }
        let validHRV = history.compactMap { $0.hrvRMSSD ?? $0.hrvSDNN14DayMean }.filter { $0 > 0 }
        
        // 2. Bangun statistik robust (Median, MAD, IQR)
        let stepsSummary = Self.buildRobustSummary(values: validSteps)
        let sleepSummary = Self.buildRobustSummary(values: validSleep)
        let heartSummary = Self.buildRobustSummary(values: validHeart)
        let restingSummary = Self.buildRobustSummary(values: validRestingHeart)
        
        // 3. Ambil Median sebagai center personal (Fallback jika data kosong)
        let baselineSteps = stepsSummary?.median ?? 2850.0
        let baselineSleep = sleepSummary?.median ?? 6.6
        let baselineHR = heartSummary?.median ?? 70.0
        let baselineRestingHR = restingSummary?.median ?? max(55.0, baselineHR - 4.0)
        
        // Milestones Ritme Langkah Harian
        let stepsAt1200 = round(baselineSteps * 0.28) // ~28% ritme siang
        let stepsAt1800 = round(baselineSteps * 0.72) // ~72% ritme sore
        
        // Sleep Stages & Jadwal
        let baselineEfficiency = validEfficiency.isEmpty ? 88.4 : Self.calculateMedian(of: validEfficiency.sorted())
        let baselineAwake = validAwake.isEmpty ? 45.0 : Self.calculateMedian(of: validAwake.sorted())
        let baselineDeep = validDeep.isEmpty ? 70.0 : Self.calculateMedian(of: validDeep.sorted())
        let baselineRem = validRem.isEmpty ? 88.0 : Self.calculateMedian(of: validRem.sorted())
        let baselineCore = validCore.isEmpty ? 238.0 : Self.calculateMedian(of: validCore.sorted())
        let baselineBedtime = validSleepDetails.first?.formattedBedtime ?? "22:45"
        let baselineWakeTime = validSleepDetails.first?.formattedWakeTime ?? "06:10"
        
        // Kebiasaan Kardiovaskular & Olahraga
        let workouts = history.compactMap(\.recentWorkoutName).filter { !$0.isEmpty }
        let typicalWorkoutRange: String? = workouts.isEmpty ? nil : "Pagi hari (06:00 - 08:00)"
        let minRestingHR = max(55, Int(baselineRestingHR - 3))
        let maxRestingHR = Int(baselineRestingHR + 4)
        let restingRange = "\(minRestingHR) - \(maxRestingHR) BPM"
        let baselineHRV = validHRV.isEmpty ? 29.0 : Self.calculateMedian(of: validHRV.sorted())
        
        return HealthBaseline(
            steps: baselineSteps,
            sleepHours: baselineSleep,
            heartRate: baselineHR,
            stepsAt1200: stepsAt1200,
            stepsAt1800: stepsAt1800,
            sleepEfficiency: baselineEfficiency,
            awakeMinutes: baselineAwake,
            deepSleepMinutes: baselineDeep,
            remSleepMinutes: baselineRem,
            coreSleepMinutes: baselineCore,
            bedtimeString: baselineBedtime,
            wakeTimeString: baselineWakeTime,
            restingHeartRate: baselineRestingHR,
            hrvSDNN: baselineHRV,
            typicalWorkoutTimeRange: typicalWorkoutRange,
            typicalRestingHRRange: restingRange,
            stepsSummary: stepsSummary,
            sleepSummary: sleepSummary,
            heartSummary: heartSummary
        )
    }
    
    /// Evaluasi data hari ini dan riwayat HealthKit 14 hari
    func evaluate(
        today: DailyHealthSummary,
        history: [DailyHealthSummary],
        parentDisplayName: String = "orang tua"
    ) -> (overview: EvaluatedHealthOverview, input: LLMInsightInput) {
        
        // 1. Hitung Nilai Baseline 14 Hari
        let baseline = calculateBaseline(from: history)
        let baselineSteps = baseline.steps
        let baselineSleep = baseline.sleepHours
        let baselineHR = baseline.heartRate
        
        // 2. Evaluasi Domain Aktivitas Fisik (Steps & Konteks Waktu)
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let hasSteps = (today.stepCount != nil && (today.stepCount ?? 0) > 0)
        let stepsDelta: Double
        let activityStatus: String
        let activityStatusBadge: String
        let currentSteps = today.stepCount ?? 0.0
        
        let bedtimeComponents = baseline.bedtimeString.split(separator: ":").compactMap { Int($0) }
        let bedtimeHour = bedtimeComponents.count > 0 ? bedtimeComponents[0] : 22
        let bedtimeMinute = bedtimeComponents.count > 1 ? bedtimeComponents[1] : 45
        let currentTotalMins = currentHour * 60 + currentMinute
        let bedtimeTotalMins = bedtimeHour * 60 + bedtimeMinute
        let diffMinutes = bedtimeTotalMins - currentTotalMins
        let remainingHours = max(0, diffMinutes / 60)
        
        var activityFindingDescription: String = ""
        var isAfternoonStepPushNeeded: Bool = false
        
        if hasSteps {
            let rawDelta = baselineSteps > 0 ? ((currentSteps - baselineSteps) / baselineSteps) * 100.0 : 0.0
            stepsDelta = rawDelta
            
            if currentSteps >= baselineSteps {
                // LANGKAH SUDAH LEBIH DARI BASELINE: Status langsung MENINGKAT pada jam berapa pun!
                activityStatus = "IMPROVED"
                activityStatusBadge = "Meningkat"
                let deltaPercentInt = max(1, Int(stepsDelta))
                activityFindingDescription = "Aktivitas langkah kaki hari ini telah mencapai \(Int(currentSteps)) langkah (+ \(deltaPercentInt)% melampaui pola harian \(Int(baselineSteps)) langkah). Capaian aktif ini melampaui kebiasaan rutinnya."
            } else if currentHour < 16 {
                // Pagi hingga Siang (belum melebihi baseline): Langkah masih berproses diakumulasi
                activityStatus = "STABLE"
                activityStatusBadge = "Sedang Berjalan"
                activityFindingDescription = "Langkah pagi hingga siang ini tercatat \(Int(currentSteps)) langkah (acuan ritme siang ~\(Int(baseline.stepsAt1200)) langkah). Masih ada waktu sekitar \(remainingHours) jam menuju jam tidur biasanya (pukul \(baseline.bedtimeString)), langkah \(parentDisplayName) masih terus bertambah seiring rutinitas harian."
            } else if currentHour < 21 {
                // Sore hingga Menjelang Malam (16:00 - 21:00): Checkpoint langkah sore
                let afternoonCheckpointTarget = baseline.stepsAt1800
                if currentSteps < (afternoonCheckpointTarget * 0.70) {
                    isAfternoonStepPushNeeded = true
                    activityStatus = "STABLE"
                    activityStatusBadge = "Perlu Gerak"
                    activityFindingDescription = "Waktu aktif hari ini tersisa sekitar \(remainingHours) jam sebelum jam tidur biasanya (pukul \(baseline.bedtimeString)). Langkah kaki \(parentDisplayName) saat ini tercatat \(Int(currentSteps)) langkah (acuan ritme sore ~\(Int(afternoonCheckpointTarget)) langkah). Caregiver dapat mengajak \(parentDisplayName) sedikit bergerak atau jalan santai sore 15–20 menit untuk mencicil langkah harian."
                } else {
                    activityStatus = "STABLE"
                    activityStatusBadge = "Sedang Berjalan"
                    activityFindingDescription = "Langkah sore terpantau on-track di \(Int(currentSteps)) langkah dengan sisa waktu sekitar \(remainingHours) jam menuju jam tidur biasanya (pukul \(baseline.bedtimeString)). Langkah harian masih akan berlanjut sesuai kegiatan malam."
                }
            } else {
                // Malam hari (>= 21:00): Evaluasi penutupan hari definitif
                if stepsDelta <= -25.0 {
                    activityStatus = "DECLINED"
                    activityStatusBadge = "Menurun"
                    activityFindingDescription = "Hingga malam hari menjelang jam tidur (pukul \(baseline.bedtimeString)), langkah kaki tercatat \(Int(currentSteps)) langkah (berkurang \(abs(Int(stepsDelta)))% dari pola harian \(Int(baselineSteps)) langkah). Pastikan \(parentDisplayName) beristirahat cukup malam ini untuk memulihkan kebugaran."
                } else {
                    activityStatus = "STABLE"
                    activityStatusBadge = "Stabil"
                    activityFindingDescription = "Capaian langkah harian terpenuhi stabil di \(Int(currentSteps)) langkah, selaras dengan kebiasaan 14 hari terakhir (\(Int(baselineSteps)) langkah)."
                }
            }
        } else {
            stepsDelta = 0.0
            activityStatus = "Belum Ada Data"
            activityStatusBadge = "Belum Ada Data"
            activityFindingDescription = "Belum ada catatan langkah hari ini di Apple Health."
        }
        
        let activityEvaluation: RobustEvaluation? = {
            guard hasSteps, let summary = baseline.stepsSummary else { return nil }
            return Self.evaluateAgainstReference(value: currentSteps, summary: summary)
        }()
        
        let evaluatedActivity = EvaluatedDomainMetric(
            domainName: "Aktivitas Fisik",
            currentValue: hasSteps ? currentSteps : nil,
            baselineValue: baselineSteps,
            deltaPercentage: stepsDelta,
            status: activityStatusBadge,
            formattedCurrent: hasSteps ? "\(Int(currentSteps)) langkah" : "—",
            formattedBaseline: "\(Int(baselineSteps)) langkah",
            hasData: hasSteps,
            customInsight: activityFindingDescription,
            robustEvaluation: activityEvaluation,
            baselineSummary: baseline.stepsSummary
        )
        
        // 3. Evaluasi Domain Tidur Semalam (Sleep Stages & Kualitas Lengkap)
        let hasSleep = (today.sleepHours != nil && (today.sleepHours ?? 0) > 0)
        let sleepDelta: Double
        let sleepStatus: String
        let sleepStatusBadge: String
        let currentSleep = today.sleepHours ?? 0.0
        let sleepDetails = today.sleepDetails
        
        let efficiency = sleepDetails?.sleepEfficiency ?? (hasSleep ? 88.4 : nil)
        let awakeMinutes = sleepDetails?.awakeMinutes ?? (hasSleep ? 45.0 : nil)
        let bedtimeStr = sleepDetails?.formattedBedtime ?? baseline.bedtimeString
        let wakeTimeStr = sleepDetails?.formattedWakeTime ?? baseline.wakeTimeString
        let awakeEpisodes = sleepDetails?.awakeEpisodes ?? []
        
        // Format jam dan menit yang ramah pengguna
        let currentSleepHours = Int(currentSleep)
        let currentSleepMins = Int(((currentSleep - Double(currentSleepHours)) * 60.0).rounded())
        let durationFormatted = currentSleepMins > 0 ? "\(currentSleepHours) jam \(currentSleepMins) menit" : "\(currentSleepHours) jam"
        
        let baselineSleepHours = Int(baselineSleep)
        let baselineSleepMins = Int(((baselineSleep - Double(baselineSleepHours)) * 60.0).rounded())
        let baselineDurationFormatted = baselineSleepMins > 0 ? "\(baselineSleepHours) jam \(baselineSleepMins) menit" : "\(baselineSleepHours) jam"
        
        // Cek pola 3 hari berturut-turut dari riwayat (Multi-day / 3-Day Pattern - PRD Rule S17/S21/S28)
        let recent3Nights = history.suffix(3)
        let validRecentSleep = recent3Nights.compactMap(\.sleepHours).filter { $0 > 0 }
        
        // Pola 3 hari berturut-turut tidur berkurang (< 6.2 jam atau turun >= 15% dari baseline)
        let is3DaysShortSleep = validRecentSleep.count >= 2 && validRecentSleep.allSatisfy { $0 < 6.2 || ((($0 - baselineSleep) / baselineSleep) * 100.0) <= -15.0 } && (currentSleep < 6.2)
        
        // Identifikasi jam terbangun utama
        let typicalAwakeTime: String = {
            if let firstEp = awakeEpisodes.first {
                return firstEp.startTimeFormatted
            }
            return "02:30"
        }()
        let typicalAwakeDuration = Int(awakeMinutes ?? 35.0)
        
        var sleepFindingDescription: String = ""
        var isSleep3DayConcern = false
        var isSingleDayAwakeWarning = false
        
        if hasSleep {
            sleepDelta = baselineSleep > 0 ? ((currentSleep - baselineSleep) / baselineSleep) * 100.0 : 0.0
            
            if is3DaysShortSleep {
                isSleep3DayConcern = true
                sleepStatus = "DECLINED"
                sleepStatusBadge = "Perlu Perhatian"
                let hoursLost = String(format: "%.1f", max(0.5, baselineSleep - currentSleep))
                sleepFindingDescription = "Sudah 3 malam berturut-turut waktu tidur \(parentDisplayName) berkurang (semalam hanya \(durationFormatted), berkurang sekitar \(hoursLost) jam dari kebiasaan \(baselineDurationFormatted)). Tren kurang tidur ini perlu diperhatikan karena dapat memicu kelelahan pada orang tua. Luangkan waktu untuk menyapa dan mengecek keadaannya."
            } else if currentSleep < 5.5 {
                sleepStatus = "DECLINED"
                sleepStatusBadge = "Kurang Tidur"
                sleepFindingDescription = "Tidur semalam sangat singkat, hanya tercatat \(durationFormatted). Durasi ini berada jauh di bawah anjuran istirahat sehat (7–8 jam) maupun kebiasaan \(parentDisplayName) (\(baselineDurationFormatted)). Kurang tidur dapat memicu rasa lemas, mengantuk berlebih, dan pusing di siang hari. Pastikan \(parentDisplayName) dapat beristirahat siang sejenak dan tanyakan apakah ada keluhan rasa tidak nyaman."
            } else if currentSleep < 6.5 || sleepDelta <= -15.0 || (efficiency != nil && efficiency! < 75.0) {
                sleepStatus = "DECLINED"
                sleepStatusBadge = "Menurun"
                sleepFindingDescription = "Istirahat semalam tercatat \(durationFormatted), lebih pendek dari kebiasaan (\(baselineDurationFormatted)) serta di bawah anjuran tidur ideal 7–8 jam. Amati apakah \(parentDisplayName) merasa lelah di siang hari dan pastikan suasana kamar lebih nyaman malam nanti."
            } else if (awakeMinutes ?? 0) >= 35.0 || (efficiency != nil && efficiency! < 85.0) {
                isSingleDayAwakeWarning = true
                sleepStatus = "STABLE"
                sleepStatusBadge = "Stabil"
                sleepFindingDescription = "Durasi tidur semalam cukup baik (\(durationFormatted)), meski sempat terbangun sejenak sekitar \(typicalAwakeDuration) menit di sekitar jam \(typicalAwakeTime). Selama total tidur mendekati standar sehat 7–8 jam, fluktuasi kecil ini masih terbilang wajar."
            } else if currentSleep >= 7.0 && sleepDelta >= 10.0 {
                sleepStatus = "IMPROVED"
                sleepStatusBadge = "Meningkat"
                sleepFindingDescription = "Tidur semalam sangat pulas selama \(durationFormatted) (kebiasaan: \(baselineDurationFormatted)), memenuhi target istirahat ideal 7–8 jam yang sangat optimal untuk memulihkan stamina fisik dan kesegaran tubuh di pagi hari."
            } else {
                sleepStatus = "STABLE"
                sleepStatusBadge = "Stabil"
                sleepFindingDescription = "Pola tidur semalam terpantau stabil dan sehat selama \(durationFormatted) (selaras dengan kebiasaan: \(baselineDurationFormatted) dan standar 7–8 jam). Fluktuasi ringan harian masih terbilang wajar dan normal. Jadwal tidur terpantau teratur pukul \(bedtimeStr) hingga \(wakeTimeStr)."
            }
        } else {
            sleepDelta = 0.0
            sleepStatus = "Belum Ada Data"
            sleepStatusBadge = "Belum Ada Data"
            sleepFindingDescription = "Belum ada catatan tidur semalam di Apple Health."
        }
        
        let sleepEvaluation: RobustEvaluation? = {
            guard hasSleep, let summary = baseline.sleepSummary else { return nil }
            return Self.evaluateAgainstReference(value: currentSleep, summary: summary)
        }()
        
        let evaluatedSleep = EvaluatedDomainMetric(
            domainName: "Tidur Semalam",
            currentValue: hasSleep ? currentSleep : nil,
            baselineValue: baselineSleep,
            deltaPercentage: sleepDelta,
            status: sleepStatusBadge,
            formattedCurrent: hasSleep ? durationFormatted : "—",
            formattedBaseline: baselineDurationFormatted,
            hasData: hasSleep,
            customInsight: sleepFindingDescription,
            robustEvaluation: sleepEvaluation,
            baselineSummary: baseline.sleepSummary
        )
        
        // 4. Evaluasi Domain Detak Jantung & Konteks Olahraga
        let liveHR = today.latestHeartRate
        let liveHRDate = today.latestHeartRateDate
        let isWorkout = today.isWorkoutActive
        let workoutName = today.recentWorkoutName
        
        let hasHeart = (liveHR != nil && liveHR! > 0)
        let currentHR = liveHR ?? 0.0
        let hrDelta: Double
        let heartStatus: String
        let heartStatusBadge: String
        var heartFindingDescription: String = ""
        var isLiveHRElevatedWithoutWorkout = false
        
        if hasHeart {
            hrDelta = baselineHR > 0 ? ((currentHR - baselineHR) / baselineHR) * 100.0 : 0.0
            let hrBaselineInt = Int(baselineHR)
            let currentHRInt = Int(currentHR)
            
            if isWorkout {
                // Saat Berolahraga: Peningkatan detak jantung adalah respon alami & baik!
                heartStatus = "IMPROVED"
                heartStatusBadge = "Meningkat Wajar (Olahraga)"
                heartFindingDescription = "Detak jantung terkini terpantau \(currentHRInt) BPM, meningkat secara wajar karena \(parentDisplayName) sedang atau baru saja berolahraga (\(workoutName ?? "aktivitas fisik")). Respon kardiovaskular ini baik untuk melatih kekuatan jantung."
            } else if currentHR > (baselineHR + 8.0) || currentHR > 85.0 {
                // Saat Santai / Tanpa Olahraga tapi Denyut Meningkat:
                isLiveHRElevatedWithoutWorkout = true
                heartStatus = "DECLINED"
                heartStatusBadge = "Meningkat (Perlu Perhatian)"
                heartFindingDescription = "Detak jantung terkini terpantau \(currentHRInt) BPM saat kondisi santai tanpa aktivitas olahraga, lebih tinggi dari kebiasaan istirahat 14 hari (\(hrBaselineInt) BPM, rentang kebiasaan \(baseline.typicalRestingHRRange)). Denyut yang meningkat di saat istirahat dapat mengindikasikan tubuh mengalami kelelahan, kurang cairan (dehidrasi), atau beban kardiovaskular. Pastikan \(parentDisplayName) minum segelas air putih dan beristirahat santai sejenak."
            } else if currentHR < 55.0 {
                // Denyut Cenderung Lambat (Bradikardia ringan pada lansia)
                heartStatus = "DECLINED"
                heartStatusBadge = "Cenderung Lambat"
                heartFindingDescription = "Detak jantung terkini tercatat \(currentHRInt) BPM (lebih lambat dari pola istirahat \(hrBaselineInt) BPM). Tanyakan apakah \(parentDisplayName) merasa pusing atau lemas, dan pastikan istirahat cukup."
            } else {
                // Normal & Stabil
                heartStatus = "STABLE"
                heartStatusBadge = "Stabil"
                heartFindingDescription = "Detak jantung terkini terpantau \(currentHRInt) BPM dalam ritme santai, stabil selaras dengan pola istirahat 14 hari (\(hrBaselineInt) BPM). Rentang denyut ini berada di batas normal dan aman bagi orang tua."
            }
        } else {
            hrDelta = 0.0
            heartStatus = "Belum Ada Data"
            heartStatusBadge = "Belum Ada Data"
            heartFindingDescription = "Belum ada catatan detak jantung hari ini di Apple Health."
        }
        
        let heartEvaluation: RobustEvaluation? = {
            guard hasHeart, let summary = baseline.heartSummary else { return nil }
            return Self.evaluateAgainstReference(value: currentHR, summary: summary)
        }()
        
        let evaluatedHeart = EvaluatedDomainMetric(
            domainName: "Detak Jantung",
            currentValue: hasHeart ? currentHR : nil,
            baselineValue: baselineHR,
            deltaPercentage: hrDelta,
            status: heartStatusBadge,
            formattedCurrent: hasHeart ? "\(Int(currentHR)) BPM" : "—",
            formattedBaseline: "\(Int(baselineHR)) BPM",
            hasData: hasHeart,
            customInsight: heartFindingDescription,
            robustEvaluation: heartEvaluation,
            baselineSummary: baseline.heartSummary
        )
        
        // 5. Tentukan Status Overview Hari Ini vs Baseline (Hanya dari domain yang memiliki data riil)
        let activeDomainStatuses = [
            hasSteps ? activityStatus : nil,
            hasSleep ? sleepStatus : nil,
            hasHeart ? heartStatus : nil
        ].compactMap { $0 }
        
        let declinedCount = activeDomainStatuses.filter { $0 == "DECLINED" }.count
        let improvedCount = activeDomainStatuses.filter { $0 == "IMPROVED" }.count
        
        let overallCondition: String
        let statusBadge: String
        let dominantDelta: Double
        
        if activeDomainStatuses.isEmpty {
            overallCondition = "STABLE"
            dominantDelta = 0.0
            statusBadge = "Belum Ada Data Sensor"
        } else if declinedCount >= 1 && (stepsDelta <= -25.0 || sleepDelta <= -20.0 || (hasSleep && currentSleep < 6.0) || hrDelta >= 12.0 || isLiveHRElevatedWithoutWorkout || declinedCount >= 2) {
            overallCondition = "DECLINED"
            let drops = [hasSteps ? stepsDelta : 0, hasSleep ? sleepDelta : 0, hasHeart ? -hrDelta : 0].filter { $0 < 0 }
            dominantDelta = drops.min() ?? -15.0
            statusBadge = (hasSleep && currentSleep < 5.5) ? "Kurang Tidur" : "Perubahan Pola Perlu Diperhatikan"
        } else if improvedCount >= 1 && declinedCount == 0 {
            overallCondition = "IMPROVED"
            let gains = [hasSteps ? stepsDelta : 0, hasSleep ? sleepDelta : 0].filter { $0 > 0 }
            dominantDelta = gains.isEmpty ? 0.0 : (gains.reduce(0, +) / Double(gains.count))
            statusBadge = "Kondisi Menunjukkan Peningkatan"
        } else {
            overallCondition = "STABLE"
            dominantDelta = 0.0
            statusBadge = "Kondisi Stabil"
        }
        
        // 6. Buat Fakta Terukur (Diselaraskan dengan PRD Section 10 & Benchmark Klinis Jurnal)
        var facts: [String] = []
        let baselineStepsInt = Int(baselineSteps)
        if baselineSteps < Double(ClinicalBenchmark.recommendedStepsSenior) {
            facts.append("Karakteristik Aktivitas: Pola dasar harian \(parentDisplayName) adalah \(baselineStepsInt) langkah (relatif rendah dibanding rujukan minimal aktif jurnal geriatri 3.000 langkah/hari). Peningkatan aktivitas sebaiknya dilakukan bertahap dan santai sesuai kemampuan.")
        } else {
            facts.append("Karakteristik Aktivitas: Pola dasar harian \(parentDisplayName) berada di angka \(baselineStepsInt) langkah, selaras dengan rujukan aktif sehat geriatri (≥3.000 langkah/hari).")
        }
        facts.append("Aktivitas: \(activityFindingDescription) [Data Hari Ini: \(evaluatedActivity.formattedCurrent), Baseline Personal: \(evaluatedActivity.formattedBaseline), Target Rujukan Jurnal Lansia: \(ClinicalBenchmark.stepsReferenceNote), status: \(activityStatusBadge), sisa waktu: \(remainingHours) jam ke jam tidur \(baseline.bedtimeString)]")
        facts.append("Tidur Semalam: \(sleepFindingDescription) [Durasi Riil Semalam: \(evaluatedSleep.formattedCurrent), Durasi Pola Kebiasaan 14 Hari: \(evaluatedSleep.formattedBaseline), Standar Sehat Medis: \(ClinicalBenchmark.sleepReferenceNote), Jadwal: \(bedtimeStr) - \(wakeTimeStr), Efisiensi: \(String(format: "%.1f%%", efficiency ?? 88.4)), Terbangun: \(typicalAwakeDuration) menit di sekitar jam \(typicalAwakeTime)].")
        facts.append("Detak Jantung: \(heartFindingDescription) [Detak Jantung Hari Ini: \(evaluatedHeart.formattedCurrent), Baseline Personal: \(evaluatedHeart.formattedBaseline), Rentang Rujukan Normal Santai: \(ClinicalBenchmark.restingHRReferenceNote), status: \(heartStatusBadge), Olahraga: \(isWorkout ? (workoutName ?? "Aktif") : "Tidak Ada")]")
        
        // 7. Tentukan Rekomendasi Tindakan (Allowed Actions)
        var allowedActions: [String] = []
        if isAfternoonStepPushNeeded {
            allowedActions.append("Ajak \(parentDisplayName) jalan santai sore 15–20 menit ringan sesuai kenyamanan untuk mendukung sirkulasi darah.")
        }
        if isLiveHRElevatedWithoutWorkout {
            allowedActions.append("Pastikan \(parentDisplayName) minum segelas air putih dan beristirahat santai sejenak untuk menstabilkan denyut jantung.")
        }
        if isSleep3DayConcern {
            allowedActions.append("Hubungi \(parentDisplayName) untuk menanyakan apa yang mengganggu tidur di jam \(typicalAwakeTime) selama 3 hari terakhir.")
            allowedActions.append("Sarankan pengecekan tensi pagi hari secara rutin dan kurangi minum berlebih menjelang tidur.")
        } else if isSingleDayAwakeWarning {
            allowedActions.append("Tanyakan kabar \(parentDisplayName) hari ini dan pastikan istirahat siang cukup jika semalam sempat terbangun.")
        }
        
        if overallCondition == "DECLINED" {
            if !isSleep3DayConcern {
                allowedActions.append("Hubungi \(parentDisplayName) hari ini dan tanyakan bagaimana kondisinya dengan hangat.")
            }
            if sleepStatus == "DECLINED" && !isSleep3DayConcern {
                allowedActions.append("Tanyakan apakah tidur semalam terganggu atau terasa kurang nyenyak.")
            }
            if activityStatus == "DECLINED" && !isAfternoonStepPushNeeded {
                allowedActions.append("Ajak berbincang santai dan sarankan tidak memaksakan aktivitas berat hari ini.")
            }
            if heartStatus == "DECLINED" && !isLiveHRElevatedWithoutWorkout {
                allowedActions.append("Ingatkan untuk cukup minum air putih dan luangkan waktu beristirahat.")
            }
            allowedActions.append("Jika tersedia tensimeter di rumah, dampingi untuk pengecekan tekanan darah rutin.")
        } else if overallCondition == "IMPROVED" {
            allowedActions.append("Berikan apresiasi kepada \(parentDisplayName) atas aktivitas dan istirahatnya yang terjaga baik.")
            allowedActions.append("Dukung rutinitas positif hari ini seperti jalan santai pagi atau sarapan bergizi.")
        } else {
            if !isSingleDayAwakeWarning && !isAfternoonStepPushNeeded && !isLiveHRElevatedWithoutWorkout {
                allowedActions.append("Kondisi \(parentDisplayName) stabil seperti biasa, pertahankan komunikasi rutin harian.")
                allowedActions.append("Pastikan kebutuhan nutrisi dan hidrasi harian tetap terpenuhi dengan baik.")
            }
        }
        
        // 8. Evaluasi Triage Push Notification (PRD Section 3, 5, 6)
        let pushDecision = evaluatePushRules(
            today: today,
            history: history,
            baseline: baseline,
            parentDisplayName: parentDisplayName
        )
        
        let overview = EvaluatedHealthOverview(
            conditionStatus: overallCondition,
            statusBadge: statusBadge,
            dominantDeltaPercentage: dominantDelta,
            baseline: baseline,
            activity: evaluatedActivity,
            sleep: evaluatedSleep,
            heart: evaluatedHeart,
            liveHeartRate: liveHR,
            liveHeartRateDate: liveHRDate,
            isWorkoutActive: isWorkout,
            workoutName: workoutName,
            facts: facts,
            allowedActions: allowedActions,
            pushDecision: pushDecision
        )
        
        let summaryPromptDetail: String
        if overallCondition == "STABLE" && baselineSteps < 3000 {
            summaryPromptDetail = "Evaluasi kondisi \(parentDisplayName) hari ini: status \(statusBadge). Kondisi hari ini selaras dengan pola kebiasaan 14 hari terakhir (\(baselineStepsInt) langkah). Pola dasar \(parentDisplayName) relatif rendah, sehingga peningkatan aktivitas sebaiknya dilakukan bertahap dan sesuai kemampuan. Jelaskan secara ramah bahwa aktivitas fisik rutin secara umum mendukung kesehatan kardiovaskular dan kebugaran, tetapi \(parentDisplayName) tidak perlu memaksakan diri."
        } else {
            summaryPromptDetail = "Evaluasi kondisi \(parentDisplayName) hari ini: status \(statusBadge). Bandingkan dengan baseline 14 hari secara ramah, tenang, dan objektif."
        }
        
        let input = LLMInsightInput(
            task: "generate_caregiver_insight",
            language: "id-ID",
            parentDisplayName: parentDisplayName,
            reportPeriod: "Hari ini vs Baseline 14 hari",
            overallCondition: overallCondition,
            overallSummaryPrompt: summaryPromptDetail,
            activity: MetricDataPoint(
                domain: "Activity",
                currentValueFormatted: evaluatedActivity.formattedCurrent,
                baselineValueFormatted: evaluatedActivity.formattedBaseline,
                deltaPercentage: evaluatedActivity.deltaPercentage,
                status: evaluatedActivity.status
            ),
            sleep: MetricDataPoint(
                domain: "Sleep",
                currentValueFormatted: evaluatedSleep.formattedCurrent,
                baselineValueFormatted: evaluatedSleep.formattedBaseline,
                deltaPercentage: evaluatedSleep.deltaPercentage,
                status: evaluatedSleep.status
            ),
            heart: MetricDataPoint(
                domain: "Heart",
                currentValueFormatted: evaluatedHeart.formattedCurrent,
                baselineValueFormatted: evaluatedHeart.formattedBaseline,
                deltaPercentage: evaluatedHeart.deltaPercentage,
                status: evaluatedHeart.status
            ),
            facts: facts,
            allowedActions: allowedActions,
            prohibitedContent: [
                "diagnosis penyakit spesifik",
                "rekomendasi dosis obat",
                "bahasa medis teknis berlebihan",
                "klaim kepastian penyebab"
            ],
            style: LLMInsightStyle(tone: "hangat, empatik, objektif, ringkas", maxSentences: 3)
        )
        
        return (overview, input)
    }
    
    // MARK: - Push Notification Rules Evaluation (PRD PRD_Push_Notification_and_AI_Insight.md)
    
    func evaluatePushRules(
        today: DailyHealthSummary,
        history: [DailyHealthSummary],
        baseline: HealthBaseline,
        parentDisplayName: String
    ) -> PushTriageDecision {
        var triggers: [PushRuleTrigger] = []
        
        let currentSteps = today.stepCount ?? 0.0
        let baselineSteps = baseline.steps
        let currentSleep = today.sleepHours ?? 0.0
        let baselineSleep = baseline.sleepHours
        let currentHR = today.latestHeartRate ?? 0.0
        let baselineHR = baseline.heartRate
        let hasSteps = (today.stepCount != nil && (today.stepCount ?? 0) > 0)
        let hasSleep = (today.sleepHours != nil && (today.sleepHours ?? 0) > 0)
        let hasHeart = (today.latestHeartRate != nil && (today.latestHeartRate ?? 0) > 0)
        let sleepDetails = today.sleepDetails
        
        // Multi-night / Multi-day samples (7 days & consecutive)
        let recent7Days = history.suffix(7)
        let recent2Days = history.suffix(2)
        let recent3Days = history.suffix(3)
        
        // --- 1. SLEEP RULES (P-S*) ---
        if hasSleep {
            let sleepHistory7 = recent7Days.compactMap(\.sleepHours).filter { $0 > 0 }
            let countShortSleep7 = sleepHistory7.filter { $0 < 6.0 }.count + (currentSleep < 6.0 ? 1 : 0)
            let countVeryShortSleep7 = sleepHistory7.filter { $0 <= 5.0 }.count + (currentSleep <= 5.0 ? 1 : 0)
            
            let sleepHistory2 = recent2Days.compactMap(\.sleepHours).filter { $0 > 0 }
            let is2NightsConsecutiveShort = sleepHistory2.count >= 1 && sleepHistory2.allSatisfy { $0 < 6.0 } && currentSleep < 6.0
            
            // P-S3: Total sleep <6 jam >=2 malam berturut atau >=3/7 hari -> P2
            if is2NightsConsecutiveShort || countShortSleep7 >= 3 {
                triggers.append(PushRuleTrigger(
                    ruleId: "P-S3",
                    domain: "sleep",
                    ruleName: "SLEEP_SHORT_REPEATED",
                    pushClass: .p2,
                    reason: "Total tidur \(parentDisplayName) kurang dari 6 jam selama beberapa malam.",
                    action: "Hubungi \(parentDisplayName) hari ini dan tanyakan apakah ada gangguan tidur."
                ))
            }
            
            // P-S4: Total sleep <=5 jam >=2 malam/7 hari -> P2
            if countVeryShortSleep7 >= 2 {
                triggers.append(PushRuleTrigger(
                    ruleId: "P-S4",
                    domain: "sleep",
                    ruleName: "SLEEP_VERY_SHORT_REPEATED",
                    pushClass: .p2,
                    reason: "Durasi tidur sangat singkat (≤5 jam) dalam beberapa hari terakhir.",
                    action: "Check-in kondisi \(parentDisplayName) hari ini dan pantau tensi bila tersedia."
                ))
            }
            
            // P-S5: Sleep efficiency <80% >=2 malam berturut atau >=3/7 hari -> P2
            if let eff = sleepDetails?.sleepEfficiency {
                let effHistory7 = recent7Days.compactMap(\.sleepDetails?.sleepEfficiency).filter { $0 > 0 }
                let countLowEff7 = effHistory7.filter { $0 < 80.0 }.count + (eff < 80.0 ? 1 : 0)
                let is2NightsLowEff = recent2Days.compactMap(\.sleepDetails?.sleepEfficiency).filter { $0 > 0 }.allSatisfy { $0 < 80.0 } && eff < 80.0
                if is2NightsLowEff || countLowEff7 >= 3 {
                    triggers.append(PushRuleTrigger(
                        ruleId: "P-S5",
                        domain: "sleep",
                        ruleName: "SLEEP_EFFICIENCY_LOW_REPEATED",
                        pushClass: .p2,
                        reason: "Kualitas tidur kurang efisien (<80%) selama beberapa malam.",
                        action: "Tanyakan apakah sering terbangun, rasa nyeri, atau sering buang air kecil di malam hari."
                    ))
                }
            }
            
            // P-S6: Awake >60 menit >=3 malam/7 hari -> P2
            if let awake = sleepDetails?.awakeMinutes {
                let awakeHistory7 = recent7Days.compactMap(\.sleepDetails?.awakeMinutes)
                let countLongAwake7 = awakeHistory7.filter { $0 > 60.0 }.count + (awake > 60.0 ? 1 : 0)
                if countLongAwake7 >= 3 {
                    triggers.append(PushRuleTrigger(
                        ruleId: "P-S6",
                        domain: "sleep",
                        ruleName: "AWAKE_DURATION_HIGH_REPEATED",
                        pushClass: .p2,
                        reason: "Waktu terbangun di tengah malam melebihi 60 menit selama 3 malam atau lebih.",
                        action: "Check-in kondisi tidur \(parentDisplayName); jangan mendiagnosis insomnia."
                    ))
                }
            }
        }
        
        // --- 2. ACTIVITY RULES (P-A*) ---
        if hasSteps && baselineSteps > 0 {
            let stepsPct = (currentSteps / baselineSteps) * 100.0
            let stepsHistory7 = recent7Days.compactMap(\.stepCount).filter { $0 > 0 }
            let countLowSteps7 = stepsHistory7.filter { ($0 / baselineSteps) * 100.0 < 70.0 }.count + (stepsPct < 70.0 ? 1 : 0)
            let stepsHistory2 = recent2Days.compactMap(\.stepCount).filter { $0 > 0 }
            let is2DaysBelow50 = stepsHistory2.count >= 1 && stepsHistory2.allSatisfy { ($0 / baselineSteps) * 100.0 < 50.0 } && stepsPct < 50.0
            
            // P-A4: Steps <25% baseline -> P3
            if stepsPct < 25.0 {
                triggers.append(PushRuleTrigger(
                    ruleId: "P-A4",
                    domain: "activity",
                    ruleName: "STEPS_SEVERE_DROP",
                    pushClass: .p3,
                    reason: "Aktivitas fisik hari ini turun sangat signifikan (<25% baseline).",
                    action: "Pastikan \(parentDisplayName) aman dan tidak mengalami lemas atau keluhan lain."
                ))
            } else if is2DaysBelow50 {
                // P-A3: Steps <50% baseline >=2 hari berturut -> P2
                triggers.append(PushRuleTrigger(
                    ruleId: "P-A3",
                    domain: "activity",
                    ruleName: "STEPS_LOW_CONSECUTIVE",
                    pushClass: .p2,
                    reason: "Langkah kaki berada di bawah 50% baseline selama 2 hari berturut-turut.",
                    action: "Hubungi \(parentDisplayName) hari ini untuk menanyakan kabar dan kondisi fisik."
                ))
            } else if countLowSteps7 >= 3 && stepsPct < 70.0 {
                // P-A2: Steps 50–<70% baseline >=3 hari/7 hari -> P2
                triggers.append(PushRuleTrigger(
                    ruleId: "P-A2",
                    domain: "activity",
                    ruleName: "STEPS_LOW_PATTERN",
                    pushClass: .p2,
                    reason: "Aktivitas langkah kaki berada di bawah 70% baseline selama 3 hari dalam seminggu.",
                    action: "Tanyakan apakah ada rasa lemas, nyeri, pusing, atau perubahan jadwal."
                ))
            }
        }
        
        // --- 3. HEART RATE & RESTING HR RULES (P-H* & P-R*) ---
        if hasHeart && baselineHR > 0 {
            let hrDeltaBPM = currentHR - baselineHR
            let isWorkout = today.isWorkoutActive
            
            if !isWorkout {
                // P-H5 / P-R3: Resting HR naik >=20 bpm saat santai -> P3
                if hrDeltaBPM >= 20.0 {
                    triggers.append(PushRuleTrigger(
                        ruleId: "P-H5",
                        domain: "heart",
                        ruleName: "HR_SPIKE_AT_REST",
                        pushClass: .p3,
                        reason: "Detak jantung istirahat terdeteksi naik cukup tinggi (+20 BPM) di atas baseline.",
                        action: "Check-in prioritas; tanyakan apakah ada rasa berdebar, lemas, atau pusing."
                    ))
                } else if hrDeltaBPM >= 10.0 {
                    // Cek riwayat RHR 2-3 hari
                    let hrHistory3 = recent3Days.compactMap { $0.latestHeartRate ?? $0.meanHeartRate24h }.filter { $0 > 0 }
                    let isHRHigh2Days = hrHistory3.count >= 1 && hrHistory3.allSatisfy { ($0 - baselineHR) >= 8.0 }
                    if isHRHigh2Days {
                        // P-H4 / P-R2: RHR naik >=10 bpm >=2-3 hari -> P2
                        triggers.append(PushRuleTrigger(
                            ruleId: "P-H4",
                            domain: "heart",
                            ruleName: "RHR_ELEVATED_MULTI_DAY",
                            pushClass: .p2,
                            reason: "Detak jantung istirahat meningkat ≥10 BPM selama beberapa hari berturut-turut.",
                            action: "Check-in hari ini; bila tersedia bantu ukur tekanan darah dan cukupkan minum air."
                        ))
                    }
                }
            }
        }
        
        // --- 4. MULTI-DOMAIN COMBINATIONS (P-R4, P-R5, P-R6, P-A5) ---
        let isSleepPoor = hasSleep && (currentSleep < 6.0 || (baselineSleep > 0 && ((currentSleep - baselineSleep) / baselineSleep) <= -0.20))
        let isStepsLow = hasSteps && baselineSteps > 0 && ((currentSteps / baselineSteps) <= 0.60)
        let isHRElevated = hasHeart && baselineHR > 0 && (currentHR - baselineHR >= 8.0) && !today.isWorkoutActive
        
        if (isSleepPoor && isStepsLow) || (isHRElevated && (isSleepPoor || isStepsLow)) {
            // Multi-domain escalated warning -> P3
            triggers.append(PushRuleTrigger(
                ruleId: "P-R6",
                domain: "multi",
                ruleName: "MULTI_DOMAIN_ELEVATED_CONCERN",
                pushClass: .p3,
                reason: "Terjadi perubahan bersamaan pada istirahat, aktivitas, dan ritme detak jantung.",
                action: "Hubungi \(parentDisplayName) hari ini; tanyakan kondisi dan bantu ukur tensi bila ada tensimeter."
            ))
        }
        
        // Pilih trigger dengan keparahan tertinggi
        guard let highestTrigger = triggers.max(by: { $0.pushClass < $1.pushClass }) else {
            return PushTriageDecision(
                shouldPush: false,
                pushClass: .p0,
                concernState: .observation,
                triggeredRules: [],
                payload: nil,
                suppressionReason: "no_actionable_push"
            )
        }
        
        let highestClass = highestTrigger.pushClass
        guard highestClass.requiresPush else {
            return PushTriageDecision(
                shouldPush: false,
                pushClass: highestClass,
                concernState: .observation,
                triggeredRules: triggers,
                payload: nil,
                suppressionReason: "informational_or_dashboard_only"
            )
        }
        
        let concernState: ConcernState
        switch highestClass {
        case .p2: concernState = .newConcern
        case .p3: concernState = .escalatedConcern
        case .p4: concernState = .urgentOverride
        default: concernState = .observation
        }
        
        // Bangun payload push: singkat (<= 160 chars), wajib sebutkan aksi
        let ruleIds = triggers.map(\.ruleId)
        let title: String
        let body: String
        
        switch highestClass {
        case .p4:
            title = "Perhatian Penting: \(parentDisplayName)"
            body = "Terdeteksi sinyal keselamatan penting. Hubungi \(parentDisplayName) segera untuk memastikan keadaannya."
        case .p3:
            title = "Perubahan Pola Perlu Diperhatikan"
            body = "Tidur dan aktivitas \(parentDisplayName) berubah beberapa hari ini. Hubungi \(parentDisplayName) hari ini dan bila ada tensimeter bantu ukur tensi."
        case .p2:
            title = "Perhatian untuk \(parentDisplayName)"
            body = "\(highestTrigger.reason) \(highestTrigger.action)"
        default:
            title = "Info Kesehatan \(parentDisplayName)"
            body = highestTrigger.action
        }
        
        // Pangkas body bila lebih dari 160 karakter untuk kepatuhan PRD Section 8.1
        let trimmedBody: String
        if body.count > 160 {
            let index = body.index(body.startIndex, offsetBy: 157)
            trimmedBody = String(body[..<index]) + "..."
        } else {
            trimmedBody = body
        }
        
        let payload = CaregiverPushPayload(
            title: title,
            body: trimmedBody,
            urgency: highestClass,
            ruleIds: ruleIds,
            domain: highestTrigger.domain,
            eventId: (highestClass == .p4) ? "\(parentDisplayName)_\(Date().timeIntervalSince1970)" : nil,
            timestamp: Date()
        )
        
        return PushTriageDecision(
            shouldPush: true,
            pushClass: highestClass,
            concernState: concernState,
            triggeredRules: triggers,
            payload: payload,
            suppressionReason: nil
        )
    }
    
    // MARK: - Local Fallback Generator
    
    // MARK: - Local Fallback Generator
    
    func makeLocalFallbackInsight(from overview: EvaluatedHealthOverview, parentName: String = "orang tua") -> LLMInsightOutput {
        let isSelf = parentName.lowercased() == "anda" || parentName.lowercased() == "saya"
        let resolvedName = isSelf ? "Anda" : parentName
        
        let overviewSummary: String
        switch overview.conditionStatus {
        case "DECLINED":
            if overview.statusBadge == "Kurang Tidur" {
                overviewSummary = isSelf
                    ? "Kondisi fisik Anda hari ini menunjukkan kondisi kurang tidur yang perlu diperhatikan dibandingkan rata-rata 14 hari terakhir. Luangkan waktu untuk beristirahat santai dan memulihkan energi."
                    : "Kondisi \(resolvedName) hari ini menunjukkan kondisi kurang tidur yang perlu diperhatikan dibandingkan rata-rata 14 hari terakhir. Sebaiknya luangkan waktu untuk menyapa atau mengecek keadaannya."
            } else {
                overviewSummary = isSelf
                    ? "Kondisi fisik Anda hari ini menunjukkan perubahan pola yang perlu diperhatikan dibandingkan rata-rata 14 hari terakhir. Luangkan waktu untuk beristirahat santai dan tidak memaksakan diri."
                    : "Kondisi \(resolvedName) hari ini menunjukkan perubahan pola yang perlu diperhatikan dibandingkan rata-rata 14 hari terakhir. Sebaiknya luangkan waktu untuk menghubungi atau mengecek keadaannya."
            }
        case "IMPROVED":
            overviewSummary = isSelf
                ? "Kondisi Anda hari ini menunjukkan perkembangan positif dibandingkan baseline 14 hari. Aktivitas dan kualitas istirahat Anda terpantau lebih baik."
                : "Kondisi \(resolvedName) hari ini menunjukkan perkembangan positif dibandingkan baseline 14 hari. Aktivitas dan kualitas istirahatnya terpantau lebih baik."
        default:
            let baselineStepsInt = Int(overview.baseline.steps)
            if overview.baseline.steps < 3000 {
                overviewSummary = isSelf
                    ? "Kondisi Anda hari ini terpantau stabil dan selaras dengan pola 14 hari terakhir (\(baselineStepsInt) langkah). Pola dasar Anda relatif santai, sehingga peningkatan aktivitas sebaiknya dilakukan bertahap dan sesuai kenyamanan tubuh. Aktivitas fisik ringan rutin secara umum baik mendukung kebugaran tanpa perlu memaksakan diri."
                    : "Kondisi \(resolvedName) hari ini terpantau stabil dan selaras dengan pola 14 hari terakhir (\(baselineStepsInt) langkah). Pola dasar \(resolvedName) relatif rendah, sehingga peningkatan aktivitas sebaiknya dilakukan bertahap dan sesuai kemampuan. Aktivitas fisik ringan rutin secara umum baik mendukung kebugaran tanpa perlu memaksakan diri."
            } else {
                overviewSummary = isSelf
                    ? "Kondisi Anda hari ini terpantau stabil dan selaras dengan pola kebiasaan 14 hari terakhir (\(baselineStepsInt) langkah). Pola aktivitas harian ini sudah baik dalam menjaga kebugaran tubuh."
                    : "Kondisi \(resolvedName) hari ini terpantau stabil dan selaras dengan pola kebiasaan 14 hari terakhir (\(baselineStepsInt) langkah). Pola aktivitas harian ini sudah baik dalam mendukung kebugaran tubuh."
            }
        }
        
        // Build Activity points
        let actPoints: [String]
        let currentHour = Calendar.current.component(.hour, from: Date())
        let baselineStepsInt = Int(overview.baseline.steps)
        if !overview.activity.hasData {
            actPoints = [
                "Belum ada catatan langkah kaki hari ini di Apple Health.",
                isSelf ? "Data langkah akan diperbarui secara otomatis saat Anda membawa iPhone atau mengenakan Apple Watch." : "Data langkah akan diperbarui secara otomatis saat orang tua membawa iPhone atau mengenakan Apple Watch."
            ]
        } else if currentHour < 21 && overview.activity.deltaPercentage < 0 {
            let remHours = max(1, 22 - currentHour)
            let rujukanNote = baselineStepsInt < ClinicalBenchmark.recommendedStepsSenior ? (isSelf ? " Meskipun kebiasaan harian Anda relatif santai dibanding rujukan umum (\(ClinicalBenchmark.stepsReferenceNote)), aktivitas hari ini tetap selaras dengan ritme Anda." : " Meskipun kebiasaan harian \(resolvedName) relatif santai dibanding rujukan umum lansia (\(ClinicalBenchmark.stepsReferenceNote)), aktivitas hari ini tetap selaras dengan ritmenya.") : ""
            actPoints = [
                "Hingga saat ini tercatat \(overview.activity.formattedCurrent) dari kebiasaan harian (\(overview.activity.formattedBaseline)). Namun perbedaan ini masih terbilang wajar dan normal karena hari masih berjalan (tersisa ~\(remHours) jam menuju jam istirahat malam).\(rujukanNote)",
                isSelf ? "Tidak perlu cemas; tetap bergerak aktif santai seperti jalan-jalan ringan di sekitar rumah sesuai kemampuan tanpa perlu memaksakan diri." : "Anak tidak perlu cemas; ajak \(resolvedName) tetap bergerak aktif santai seperti jalan-jalan ringan di halaman rumah sesuai kemampuan tanpa perlu memaksakan diri."
            ]
        } else if overview.activity.deltaPercentage <= -25.0 {
            actPoints = [
                "Total langkah hari ini tercatat \(overview.activity.formattedCurrent), lebih rendah dibandingkan kebiasaan harian (\(overview.activity.formattedBaseline)) serta rujukan minimal aktif (\(ClinicalBenchmark.stepsReferenceNote)). Namun satu hari yang lebih santai masih terbilang wajar terjadi.",
                isSelf ? "Pastikan Anda tidak merasa terlalu lelah dan memiliki waktu istirahat yang cukup malam ini." : "Anak dapat menyapa santai untuk memastikan \(resolvedName) tidak merasa lelah dan memiliki waktu istirahat yang cukup malam ini."
            ]
        } else {
            let rujukanTarget = baselineStepsInt < ClinicalBenchmark.recommendedStepsSenior ? "Meskipun kebiasaan harian (\(overview.activity.formattedBaseline)) berada di bawah target aktif rujukan jurnal (\(ClinicalBenchmark.stepsReferenceNote)), peningkatan disarankan bertahap." : "Langkah harian ini sudah selaras dengan standar aktif sehat (\(ClinicalBenchmark.stepsReferenceNote))."
            actPoints = [
                "Aktivitas langkah hari ini tercatat \(overview.activity.formattedCurrent), tetap stabil dan selaras dengan kebiasaan 14 hari terakhir (\(overview.activity.formattedBaseline)). Perubahan harian masih terbilang wajar dan normal.",
                "Konsistensi berjalan santai secara rutin sangat baik untuk menjaga kebugaran. \(rujukanTarget)"
            ]
        }
        let actInsight = actPoints.joined(separator: " ")
        
        // Build Sleep points
        let sleepPoints: [String]
        let currentSleepVal = overview.sleep.currentValue ?? 0.0
        if !overview.sleep.hasData {
            sleepPoints = [
                "Belum ada catatan tidur semalam di Apple Health.",
                isSelf ? "Catatan tidur otomatis dapat diaktifkan melalui fitur Jadwal Tidur di iPhone atau Apple Watch Anda." : "Catatan tidur otomatis dapat diaktifkan melalui fitur Jadwal Tidur di iPhone atau Apple Watch."
            ]
        } else if currentSleepVal < 5.5 {
            sleepPoints = [
                "Waktu istirahat semalam hanya tercatat \(overview.sleep.formattedCurrent), jauh di bawah standar tidur sehat (\(ClinicalBenchmark.sleepReferenceNote)) maupun kebiasaan \(resolvedName) (\(overview.sleep.formattedBaseline)).",
                isSelf ? "Durasi tidur yang sangat minim dapat membuat tubuh terasa lemas atau mengantuk di siang hari. Luangkan waktu untuk tidur siang sejenak guna memulihkan tenaga." : "Durasi tidur yang sangat minim dapat membuat orang tua merasa lemas, mengantuk berlebih, atau pusing di siang hari. Luangkan waktu untuk menyapa \(resolvedName) dan ingatkan untuk tidur siang sejenak guna memulihkan tenaga."
            ]
        } else if currentSleepVal < 6.5 || overview.sleep.deltaPercentage <= -15.0 {
            sleepPoints = [
                "Waktu istirahat semalam tercatat \(overview.sleep.formattedCurrent), lebih singkat dibanding kebiasaan (\(overview.sleep.formattedBaseline)) dan berada di bawah anjuran tidur sehat (\(ClinicalBenchmark.sleepReferenceNote)).",
                isSelf ? "Perhatikan apakah Anda merasa lelah di siang hari dan pastikan kondisi kamar lebih nyaman untuk istirahat malam berikutnya." : "Amati apakah \(resolvedName) merasa lelah di siang hari dan pastikan kondisi kamar lebih tenang untuk istirahat malam berikutnya."
            ]
        } else if overview.sleep.deltaPercentage >= 10.0 && currentSleepVal >= 7.0 {
            sleepPoints = [
                "Tidur semalam terpantau sangat pulas selama \(overview.sleep.formattedCurrent), memenuhi target tidur ideal (\(ClinicalBenchmark.sleepReferenceNote)) dan lebih panjang dari kebiasaan (\(overview.sleep.formattedBaseline)).",
                "Waktu istirahat lelap yang optimal membantu memulihkan stamina fisik dan kesegaran pikiran di pagi hari."
            ]
        } else {
            sleepPoints = [
                "Durasi tidur semalam berada di angka \(overview.sleep.formattedCurrent), konsisten dengan kebiasaan 14 malam terakhir (\(overview.sleep.formattedBaseline)) dan memenuhi anjuran tidur sehat (\(ClinicalBenchmark.sleepReferenceNote)). Fluktuasi kecil ini masih terbilang wajar dan normal.",
                "Irama tidur yang teratur sangat baik dalam menjaga kesegaran tubuh dan ketenangan pikiran sepanjang hari."
            ]
        }
        let sleepInsight = sleepPoints.joined(separator: " ")
        
        // Build Heart points
        let heartPoints: [String]
        if !overview.heart.hasData {
            heartPoints = [
                "Detak jantung saat santai belum tercatat di Apple Health.",
                "Pencatatan denyut istirahat memerlukan sensor Apple Watch atau alat monitor denyut yang terhubung."
            ]
        } else if overview.isWorkoutActive {
            heartPoints = [
                "Peningkatan denyut jantung tercatat sebesar \(overview.heart.formattedCurrent) saat berolahraga (\(overview.workoutName ?? "aktivitas fisik")).",
                "Kenaikan denyut ini merupakan respons aktif tubuh yang wajar dan sehat selama beraktivitas."
            ]
        } else if overview.heart.deltaPercentage >= 8.0 {
            heartPoints = [
                "Denyut jantung saat santai hari ini tercatat \(overview.heart.formattedCurrent), sedikit lebih tinggi dibandingkan pola 14 hari terakhir (\(overview.heart.formattedBaseline)). Namun fluktuasi ringan seperti ini masih terbilang wajar dan dapat dipengaruhi oleh suhu ruangan atau asupan air.",
                isSelf ? "Minum segelas air putih dan beristirahat santai sejenak (rentang normal saat santai menurut AHA adalah \(ClinicalBenchmark.restingHRReferenceNote))." : "Anak tidak perlu cemas; ingatkan \(resolvedName) untuk minum segelas air putih dan beristirahat santai sejenak (rentang normal saat santai menurut AHA adalah \(ClinicalBenchmark.restingHRReferenceNote))."
            ]
        } else {
            heartPoints = [
                "Denyut jantung saat santai berada di angka \(overview.heart.formattedCurrent), stabil dalam rentang kebiasaan 14 hari (\(overview.heart.formattedBaseline)) serta selaras dengan rentang normal santai medis (\(ClinicalBenchmark.restingHRReferenceNote)).",
                "Ritme denyut istirahat yang tenang ini mencerminkan kondisi pemulihan tubuh yang terjaga baik."
            ]
        }
        let heartInsight = heartPoints.joined(separator: " ")
        
        return LLMInsightOutput(
            todayOverview: TodayOverviewInsight(
                conditionStatus: overview.conditionStatus,
                statusLabel: RuleEngine.unifiedOverviewTitle(conditionStatus: overview.conditionStatus, statusBadge: overview.statusBadge),
                deltaPercentage: nil,
                summary: RuleEngine.sanitizeSummaryNarrative(overviewSummary)
            ),
            activityInsight: DomainMetricInsight(
                currentValue: overview.activity.formattedCurrent,
                baselineValue: overview.activity.formattedBaseline,
                deltaPercentage: overview.activity.deltaPercentage,
                status: overview.activity.status,
                insight: actInsight,
                points: actPoints
            ),
            sleepInsight: DomainMetricInsight(
                currentValue: overview.sleep.formattedCurrent,
                baselineValue: overview.sleep.formattedBaseline,
                deltaPercentage: overview.sleep.deltaPercentage,
                status: overview.sleep.status,
                insight: sleepInsight,
                points: sleepPoints
            ),
            heartInsight: DomainMetricInsight(
                currentValue: overview.heart.formattedCurrent,
                baselineValue: overview.heart.formattedBaseline,
                deltaPercentage: overview.heart.deltaPercentage,
                status: overview.heart.status,
                insight: heartInsight,
                points: heartPoints
            ),
            recommendedActions: overview.allowedActions
        )
    }
    
    // MARK: - Output Sanitizer
    
    func sanitizeInsightOutput(_ output: LLMInsightOutput, overview: EvaluatedHealthOverview) -> LLMInsightOutput {
        let cleanedOverview = TodayOverviewInsight(
            conditionStatus: overview.conditionStatus,
            statusLabel: RuleEngine.unifiedOverviewTitle(conditionStatus: overview.conditionStatus, statusBadge: overview.statusBadge),
            deltaPercentage: nil,
            summary: RuleEngine.sanitizeSummaryNarrative(output.todayOverview.summary)
        )
        
        // Pastikan narasi domain aktivitas selaras dengan data riil hari ini
        let actInsightText: String
        let actPoints: [String]?
        if overview.activity.hasData {
            let isStaleNoData = (output.activityInsight.points ?? [output.activityInsight.insight]).allSatisfy {
                $0.lowercased().contains("belum ada catatan") || $0.lowercased().contains("tidak ada catatan")
            }
            if isStaleNoData || output.activityInsight.currentValue == "—" || output.activityInsight.currentValue == "-" {
                let fallback = makeLocalFallbackInsight(from: overview, parentName: "orang tua")
                actPoints = fallback.activityInsight.points
                actInsightText = fallback.activityInsight.insight
            } else {
                actPoints = output.activityInsight.points
                actInsightText = output.activityInsight.insight
            }
        } else {
            actPoints = output.activityInsight.points
            actInsightText = output.activityInsight.insight
        }
        
        let cleanedActivity = DomainMetricInsight(
            currentValue: overview.activity.formattedCurrent,
            baselineValue: overview.activity.formattedBaseline,
            deltaPercentage: overview.activity.deltaPercentage,
            status: overview.activity.status,
            insight: actInsightText,
            points: actPoints
        )
        
        let cleanedSleep = DomainMetricInsight(
            currentValue: overview.sleep.formattedCurrent,
            baselineValue: overview.sleep.formattedBaseline,
            deltaPercentage: overview.sleep.deltaPercentage,
            status: overview.sleep.status,
            insight: output.sleepInsight.insight,
            points: output.sleepInsight.points
        )
        
        let cleanedHeart = DomainMetricInsight(
            currentValue: overview.heart.formattedCurrent,
            baselineValue: overview.heart.formattedBaseline,
            deltaPercentage: overview.heart.deltaPercentage,
            status: overview.heart.status,
            insight: output.heartInsight.insight,
            points: output.heartInsight.points
        )
        
        return LLMInsightOutput(
            todayOverview: cleanedOverview,
            activityInsight: cleanedActivity,
            sleepInsight: cleanedSleep,
            heartInsight: cleanedHeart,
            recommendedActions: output.recommendedActions.isEmpty ? overview.allowedActions : output.recommendedActions
        )
    }
}
