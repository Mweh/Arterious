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
    
    var formattedDelta: String {
        guard hasData else { return "—" }
        let sign = deltaPercentage >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", deltaPercentage))%"
    }
}

/// Evaluasi komprehensif hari ini vs baseline
struct EvaluatedHealthOverview {
    let conditionStatus: String // "IMPROVED", "STABLE", "DECLINED", "UNKNOWN"
    let statusBadge: String     // e.g. "Kondisi Stabil", "Penurunan 23%", "Membaik +14%", "Belum Ada Data"
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
}

@MainActor
final class RuleEngine {
    
    static let shared = RuleEngine()
    
    private init() {}
    
    /// Fungsi eksplisit menghitung baseline 14 hari dari riwayat HealthKit
    func calculateBaseline(from history: [DailyHealthSummary]) -> HealthBaseline {
        let validSteps = history.compactMap(\.stepCount).filter { $0 > 0 }
        let baselineSteps = validSteps.isEmpty ? 2850.0 : (validSteps.reduce(0, +) / Double(validSteps.count))
        
        let validSleep = history.compactMap(\.sleepHours).filter { $0 > 0 }
        let baselineSleep = validSleep.isEmpty ? 6.6 : (validSleep.reduce(0, +) / Double(validSleep.count))
        
        let validRHR = history.compactMap(\.restingHeartRate).filter { $0 > 0 }
        let baselineRHR = validRHR.isEmpty ? 65.0 : (validRHR.reduce(0, +) / Double(validRHR.count))
        
        let validSleepDetails = history.compactMap(\.sleepDetails)
        let baselineEfficiency = validSleepDetails.isEmpty ? 88.4 : (validSleepDetails.map(\.sleepEfficiency).reduce(0, +) / Double(validSleepDetails.count))
        let baselineAwake = validSleepDetails.isEmpty ? 50.0 : (validSleepDetails.map(\.awakeMinutes).reduce(0, +) / Double(validSleepDetails.count))
        let baselineBedtime = validSleepDetails.first?.formattedBedtime ?? "22:45"
        let baselineWakeTime = validSleepDetails.first?.formattedWakeTime ?? "06:10"
        
        return HealthBaseline(
            steps: baselineSteps,
            sleepHours: baselineSleep,
            restingHeartRate: baselineRHR,
            sleepEfficiency: baselineEfficiency,
            awakeMinutes: baselineAwake,
            bedtimeString: baselineBedtime,
            wakeTimeString: baselineWakeTime
        )
    }
    
    /// Evaluasi data hari ini dan riwayat HealthKit 14 hari
    func evaluate(
        today: DailyHealthSummary,
        history: [DailyHealthSummary],
        parentDisplayName: String = "Ibu"
    ) -> (overview: EvaluatedHealthOverview, input: LLMInsightInput) {
        
        // 1. Hitung Nilai Baseline 14 Hari
        let baseline = calculateBaseline(from: history)
        let baselineSteps = baseline.steps
        let baselineSleep = baseline.sleepHours
        let baselineRHR = baseline.restingHeartRate
        
        // 2. Evaluasi Domain Aktivitas Fisik (Steps) dengan Pacing Jam Hari Ini
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let hasSteps = (today.stepCount != nil && (today.stepCount ?? 0) > 0)
        let stepsDelta: Double
        let activityStatus: String
        let activityStatusBadge: String
        let currentSteps = today.stepCount ?? 0.0
        
        // Acuan jam tidur dari baseline adalah ~22:45
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
            if currentHour < 16 {
                // Pagi hingga Siang: Langkah masih berproses diakumulasi
                activityStatus = "STABLE"
                activityStatusBadge = "Sedang Berjalan"
                stepsDelta = 0.0
                activityFindingDescription = "Langkah pagi hingga siang ini tercatat \(Int(currentSteps)) langkah. Masih ada selisih sekitar \(remainingHours) jam menuju waktu tidur biasanya (pukul \(baseline.bedtimeString)). Langkah \(parentDisplayName) masih akan terus bertambah seiring rutinitas harian. Aktivitas langkah kaki yang teratur sangat bermanfaat membantu kelenturan dinding pembuluh darah, menurunkan resistensi vaskular perifer, dan menjaga kestabilan tekanan darah."
            } else if currentHour < 21 {
                // Sore hingga Menjelang Malam (16:00 - 21:00): Checkpoint langkah sore
                let afternoonCheckpointTarget = baselineSteps * 0.70 // Acuan sore ~70% dari baseline
                if currentSteps < afternoonCheckpointTarget {
                    isAfternoonStepPushNeeded = true
                    activityStatus = "STABLE"
                    activityStatusBadge = "Perlu Gerak"
                    stepsDelta = 0.0
                    activityFindingDescription = "Waktu aktif hari ini tersisa selisih sekitar \(remainingHours) jam sebelum jam tidur biasanya (pukul \(baseline.bedtimeString)), namun langkah kaki \(parentDisplayName) (\(Int(currentSteps)) langkah) masih di bawah ritme aktivitas sore (acuan target ~\(Int(afternoonCheckpointTarget)) langkah). Caregiver disarankan mengajak \(parentDisplayName) sedikit bergerak atau jalan santai sore 15–20 menit untuk mengejar target langkah. Rutin memenuhi target langkah kaki harian terbukti membantu elastisitas pembuluh darah, memperlancar sirkulasi perifer, dan menjaga tekanan darah tetap stabil."
                } else {
                    activityStatus = "STABLE"
                    activityStatusBadge = "Sedang Berjalan"
                    stepsDelta = 0.0
                    activityFindingDescription = "Langkah sore terpantau on-track di \(Int(currentSteps)) langkah dengan selisih sekitar \(remainingHours) jam menuju jam tidur biasanya (pukul \(baseline.bedtimeString)). Rutinitas berjalan santai ini sangat baik untuk sirkulasi darah dan mendukung kestabilan tensi."
                }
            } else {
                // Malam hari (>= 21:00): Menjelang jam tidur 22:45, evaluasi capaian penuh 24 jam
                let rawDelta = baselineSteps > 0 ? ((currentSteps - baselineSteps) / baselineSteps) * 100.0 : 0.0
                stepsDelta = rawDelta
                if stepsDelta <= -30.0 {
                    activityStatus = "DECLINED"
                    activityStatusBadge = "Menurun"
                    activityFindingDescription = "Hingga malam hari menjelang jam tidur (pukul \(baseline.bedtimeString)), langkah kaki tercatat \(Int(currentSteps)) langkah (berkurang \(abs(Int(stepsDelta)))% dari baseline). Pastikan \(parentDisplayName) beristirahat cukup malam ini untuk memulihkan kebugaran dan menstabilkan tekanan darah."
                } else if stepsDelta >= 15.0 {
                    activityStatus = "IMPROVED"
                    activityStatusBadge = "Meningkat"
                    activityFindingDescription = "Aktivitas langkah hari ini sangat prima mencapai \(Int(currentSteps)) langkah (+ \(Int(stepsDelta))% di atas baseline), memberi dampak sangat baik bagi elastisitas pembuluh darah dan kesehatan jantung."
                } else {
                    activityStatus = "STABLE"
                    activityStatusBadge = "Stabil"
                    activityFindingDescription = "Capaian langkah harian terpenuhi stabil di \(Int(currentSteps)) langkah, selaras dengan kebiasaan 14 hari terakhir."
                }
            }
        } else {
            stepsDelta = 0.0
            activityStatus = "Belum Ada Data"
            activityStatusBadge = "Belum Ada Data"
            activityFindingDescription = "Belum ada catatan langkah hari ini di Apple Health."
        }
        
        let evaluatedActivity = EvaluatedDomainMetric(
            domainName: "Aktivitas Fisik",
            currentValue: hasSteps ? currentSteps : nil,
            baselineValue: baselineSteps,
            deltaPercentage: stepsDelta,
            status: activityStatusBadge,
            formattedCurrent: hasSteps ? "\(Int(currentSteps)) langkah" : "—",
            formattedBaseline: "\(Int(baselineSteps)) langkah",
            hasData: hasSteps,
            customInsight: activityFindingDescription
        )
        
        // 3. Evaluasi Domain Tidur Semalam (Sleep) & Analisis Pola Multi-Hari (3 Hari)
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
                // KASUS 3 HARI BERTURUT-TURUT: Rule S17 / S21 / S28
                isSleep3DayConcern = true
                sleepStatus = "DECLINED"
                sleepStatusBadge = "Perlu Perhatian"
                let hoursLost = String(format: "%.1f", max(0.5, baselineSleep - currentSleep))
                sleepFindingDescription = "Sudah 3 hari ini \(parentDisplayName) selalu terbangun di sekitar jam \(typicalAwakeTime), dan ini menyebabkan tidur \(parentDisplayName) jadi sedikit sehingga berkurang \(hoursLost) jam dari baseline. Kondisi fragmentasi tidur 3 hari ini cukup perlu diperhatikan karena dapat memicu peningkatan tekanan darah saat tidur dan kelelahan."
            } else if currentSleep < 6.0 || sleepDelta <= -20.0 || (efficiency != nil && efficiency! < 75.0) {
                // Kasus penurunan tidur hari ini (Short Sleep / Low Efficiency - Rule S2/S8)
                sleepStatus = "DECLINED"
                sleepStatusBadge = "Menurun"
                sleepFindingDescription = "Tidur semalam tercatat \(String(format: "%.1f jam", currentSleep)) (berkurang \(abs(Int(sleepDelta)))% dari baseline \(String(format: "%.1f jam", baselineSleep)), efisiensi tidur \(String(format: "%.0f%%", efficiency ?? 80.0))). Waktu terbangun tercatat \(typicalAwakeDuration) menit."
            } else if (awakeMinutes ?? 0) >= 35.0 || (efficiency != nil && efficiency! < 85.0) {
                // KASUS STABIL / NORMAL TAPI ADA EPISODE TERBANGUN (Single-Day Context - Rule S9):
                // Durasi tidur secara umum normal/stabil, namun ada episode awake di jam tertentu
                isSingleDayAwakeWarning = true
                sleepStatus = "STABLE"
                sleepStatusBadge = "Stabil"
                sleepFindingDescription = "Kondisi tidur \(parentDisplayName) masih normal (\(String(format: "%.1f jam", currentSleep))), hanya saja sedikit lebih banyak terbangun sekitar \(typicalAwakeDuration) menit di jam \(typicalAwakeTime). Jika kondisi sering terbangun ini berlangsung selama beberapa hari (≥3 hari), kondisi tekanan darah \(parentDisplayName) saat tidur dapat dipicu meningkat."
            } else if currentSleep >= 7.0 && sleepDelta >= 10.0 {
                sleepStatus = "IMPROVED"
                sleepStatusBadge = "Meningkat"
                sleepFindingDescription = "Tidur semalam sangat pulas selama \(String(format: "%.1f jam", currentSleep)) dengan efisiensi prima (\(String(format: "%.0f%%", efficiency ?? 90.0)))."
            } else {
                sleepStatus = "STABLE"
                sleepStatusBadge = "Stabil"
                sleepFindingDescription = "Pola tidur semalam terpantau stabil (\(String(format: "%.1f jam", currentSleep))) dengan jam tidur pukul \(bedtimeStr) dan bangun pukul \(wakeTimeStr)."
            }
        } else {
            sleepDelta = 0.0
            sleepStatus = "Belum Ada Data"
            sleepStatusBadge = "Belum Ada Data"
            sleepFindingDescription = "Belum ada catatan tidur semalam di Apple Health."
        }
        
        let evaluatedSleep = EvaluatedDomainMetric(
            domainName: "Tidur Semalam",
            currentValue: hasSleep ? currentSleep : nil,
            baselineValue: baselineSleep,
            deltaPercentage: sleepDelta,
            status: sleepStatusBadge,
            formattedCurrent: hasSleep ? String(format: "%.1f jam", currentSleep) : "—",
            formattedBaseline: String(format: "%.1f jam", baselineSleep),
            hasData: hasSleep,
            customInsight: sleepFindingDescription
        )
        
        // 4. Evaluasi Domain Detak Jantung (Live Heart Rate & Resting Heart Rate)
        let hasHeart = (today.restingHeartRate != nil && (today.restingHeartRate ?? 0) > 0)
        let rhrDelta: Double
        let heartStatus: String
        let heartStatusBadge: String
        let currentRHR = today.restingHeartRate ?? 0.0
        let liveHR = today.latestHeartRate
        let liveHRDate = today.latestHeartRateDate
        let isWorkout = today.isWorkoutActive
        let workoutName = today.recentWorkoutName
        
        if hasHeart {
            rhrDelta = baselineRHR > 0 ? ((currentRHR - baselineRHR) / baselineRHR) * 100.0 : 0.0
            if rhrDelta >= 10.0 {
                heartStatus = "DECLINED"
                heartStatusBadge = "Meningkat"
            } else if rhrDelta <= -8.0 {
                heartStatus = "IMPROVED"
                heartStatusBadge = "Rileks"
            } else {
                heartStatus = "STABLE"
                heartStatusBadge = "Normal"
            }
        } else {
            rhrDelta = 0.0
            heartStatus = "Belum Ada Data"
            heartStatusBadge = "Belum Ada Data"
        }
        
        var heartFindingDescription: String = ""
        let rhrString = hasHeart ? "\(Int(currentRHR)) BPM" : "—"
        let rhrBaselineString = "\(Int(baselineRHR)) BPM"
        var isLiveHRElevatedWithoutWorkout = false
        
        if let currentLive = liveHR {
            if isWorkout {
                heartFindingDescription = "Detak jantung terkini terpantau \(Int(currentLive)) BPM (meningkat wajar karena \(parentDisplayName) sedang atau baru saja berolahraga: \(workoutName ?? "aktivitas fisik")). Denyut istirahat (RHR) hari ini tetap stabil di \(rhrString) (baseline: \(rhrBaselineString))."
            } else if currentLive >= (baselineRHR + 20.0) {
                isLiveHRElevatedWithoutWorkout = true
                heartFindingDescription = "Detak jantung terkini menunjukkan \(Int(currentLive)) BPM, terpantau lebih tinggi dari denyut istirahat harian (\(rhrString)) tanpa terdeteksi sesi olahraga. Perlu dipastikan apakah \(parentDisplayName) cukup minum air putih, kegerahan, atau merasa lelah."
            } else {
                heartFindingDescription = "Detak jantung terkini terpantau \(Int(currentLive)) BPM dalam ritme santai. Denyut istirahat (RHR) hari ini stabil di \(rhrString) dibandingkan baseline 14 hari (\(rhrBaselineString))."
            }
        } else if hasHeart {
            heartFindingDescription = "Denyut jantung istirahat (RHR) hari ini tercatat \(rhrString) (baseline: \(rhrBaselineString)), berada dalam batas normal dan stabil."
        } else {
            heartFindingDescription = "Belum ada catatan detak jantung hari ini di Apple Health."
        }
        
        let evaluatedHeart = EvaluatedDomainMetric(
            domainName: "Detak Jantung",
            currentValue: hasHeart ? currentRHR : (liveHR ?? nil),
            baselineValue: baselineRHR,
            deltaPercentage: rhrDelta,
            status: heartStatusBadge,
            formattedCurrent: hasHeart ? "\(Int(currentRHR)) BPM" : (liveHR != nil ? "\(Int(liveHR!)) BPM" : "—"),
            formattedBaseline: "\(Int(baselineRHR)) BPM",
            hasData: hasHeart || liveHR != nil,
            customInsight: heartFindingDescription
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
        } else if declinedCount >= 1 && (stepsDelta <= -25.0 || sleepDelta <= -25.0 || rhrDelta >= 15.0 || declinedCount >= 2) {
            overallCondition = "DECLINED"
            let drops = [hasSteps ? stepsDelta : 0, hasSleep ? sleepDelta : 0, hasHeart ? -rhrDelta : 0].filter { $0 < 0 }
            dominantDelta = drops.min() ?? -15.0
            statusBadge = "Penurunan \(abs(Int(dominantDelta)))%"
        } else if improvedCount >= 1 && declinedCount == 0 {
            overallCondition = "IMPROVED"
            let gains = [hasSteps ? stepsDelta : 0, hasSleep ? sleepDelta : 0].filter { $0 > 0 }
            dominantDelta = gains.isEmpty ? 10.0 : (gains.reduce(0, +) / Double(gains.count))
            statusBadge = "Membaik +\(Int(dominantDelta))%"
        } else {
            overallCondition = "STABLE"
            dominantDelta = 0.0
            statusBadge = "Kondisi Stabil"
        }
        
        // 6. Buat Fakta Terukur
        var facts: [String] = []
        let baselineStepsInt = Int(baselineSteps)
        if baselineSteps < 3000 {
            facts.append("Standar Lansia: Rekomendasi kebugaran lansia untuk menjaga elastisitas pembuluh darah adalah minimal 3.000–4.000 langkah/hari. Baseline 14 hari \(parentDisplayName) saat ini adalah \(baselineStepsInt) langkah (tergolong rendah). Walaupun kondisi hari ini stabil selaras dengan kebiasaannya, target aktivitas ini baiknya ditingkatkan secara bertahap demi kestabilan tekanan darah.")
        } else {
            facts.append("Standar Lansia: Baseline harian \(parentDisplayName) (\(baselineStepsInt) langkah) telah memenuhi target aktif lansia (minimal 3.000 langkah/hari).")
        }
        facts.append("Aktivitas: \(activityFindingDescription) [Data: \(evaluatedActivity.formattedCurrent) vs baseline \(evaluatedActivity.formattedBaseline), status: \(activityStatusBadge), sisa waktu: \(remainingHours) jam ke jam tidur \(baseline.bedtimeString)]")
        facts.append("Tidur Semalam: \(sleepFindingDescription) [Data: \(evaluatedSleep.formattedCurrent) vs baseline \(evaluatedSleep.formattedBaseline), Jadwal: \(bedtimeStr) - \(wakeTimeStr), Efisiensi: \(String(format: "%.1f%%", efficiency ?? 88.4)), Terbangun: \(typicalAwakeDuration) menit di sekitar jam \(typicalAwakeTime)].")
        facts.append("Detak Jantung: \(heartFindingDescription) [Live HR: \(liveHR != nil ? "\(Int(liveHR!)) BPM" : "Belum Ada Data"), RHR Hari Ini: \(rhrString), RHR Baseline: \(rhrBaselineString), Workout: \(isWorkout ? (workoutName ?? "Aktif") : "Tidak Ada")]")
        
        // 7. Tentukan Rekomendasi Tindakan (Allowed Actions)
        var allowedActions: [String] = []
        if isAfternoonStepPushNeeded {
            allowedActions.append("Ajak \(parentDisplayName) jalan santai sore 15–20 menit untuk mengejar target langkah, melancarkan aliran darah, dan mendukung kestabilan tensi.")
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
            allowedActions: allowedActions
        )
        
        let summaryPromptDetail: String
        if overallCondition == "STABLE" && baselineSteps < 3000 {
            summaryPromptDetail = "Evaluasi kondisi \(parentDisplayName) hari ini: status \(statusBadge). Kondisi hari ini selaras dengan kebiasaan 14 hari terakhir (\(baselineStepsInt) langkah). Namun jelaskan secara hangat bahwa baseline kebiasaan tersebut sebenarnya masih di bawah target anjuran lansia (3.000–4.000 langkah/hari). Sarankan bahwa walau hari ini stabil, target aktivitas ke depannya baiknya ditingkatkan secara bertahap agar kelenturan pembuluh darah lebih optimal dan menjaga kestabilan tekanan darah."
        } else {
            summaryPromptDetail = "Evaluasi kondisi \(parentDisplayName) hari ini: status \(statusBadge). Bandingkan dengan baseline 14 hari."
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
}
