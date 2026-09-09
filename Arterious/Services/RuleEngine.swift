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
    
    var headline: String {
        RuleEngine.overviewHeadline(for: conditionStatus)
    }
}

@MainActor
final class RuleEngine {
    
    static let shared = RuleEngine()
    
    private init() {}
    
    static func overviewHeadline(for conditionStatus: String) -> String {
        switch conditionStatus.uppercased() {
        case "IMPROVED":
            return "Kondisi Menunjukkan Peningkatan"
        case "DECLINED":
            return "Perubahan Pola Perlu Diperhatikan"
        default:
            return "Kondisi Stabil Dibandingkan Baseline"
        }
    }
    
    /// Fungsi eksplisit menghitung baseline 14 hari dari riwayat HealthKit
    func calculateBaseline(from history: [DailyHealthSummary]) -> HealthBaseline {
        let validSteps = history.compactMap(\.stepCount).filter { $0 > 0 }
        let baselineSteps = validSteps.isEmpty ? 2850.0 : (validSteps.reduce(0, +) / Double(validSteps.count))
        
        let validSleep = history.compactMap(\.sleepHours).filter { $0 > 0 }
        let baselineSleep = validSleep.isEmpty ? 6.6 : (validSleep.reduce(0, +) / Double(validSleep.count))
        
        let validHeart = history.compactMap { $0.latestHeartRate ?? $0.meanHeartRate24h }.filter { $0 > 0 }
        let baselineHR = validHeart.isEmpty ? 70.0 : (validHeart.reduce(0, +) / Double(validHeart.count))
        
        let validSleepDetails = history.compactMap(\.sleepDetails)
        let baselineEfficiency = validSleepDetails.isEmpty ? 88.4 : (validSleepDetails.map(\.sleepEfficiency).reduce(0, +) / Double(validSleepDetails.count))
        let baselineAwake = validSleepDetails.isEmpty ? 45.0 : (validSleepDetails.map(\.awakeMinutes).reduce(0, +) / Double(validSleepDetails.count))
        let baselineBedtime = validSleepDetails.first?.formattedBedtime ?? "22:30"
        let baselineWakeTime = validSleepDetails.first?.formattedWakeTime ?? "06:00"
        
        return HealthBaseline(
            steps: baselineSteps,
            sleepHours: baselineSleep,
            heartRate: baselineHR,
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
        let baselineHR = baseline.heartRate
        
        // 2. Evaluasi Domain Aktivitas Fisik (Steps)
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
                activityFindingDescription = "Aktivitas langkah kaki hari ini telah mencapai \(Int(currentSteps)) langkah (+ \(deltaPercentInt)% melampaui baseline harian \(Int(baselineSteps)) langkah). Capaian aktif ini sangat baik dalam melancarkan aliran darah tepi (sirkulasi perifer), melatih kelenturan dinding pembuluh darah, dan menjaga kestabilan tekanan darah."
            } else if currentHour < 16 {
                // Pagi hingga Siang (belum melebihi baseline): Langkah masih berproses diakumulasi
                activityStatus = "STABLE"
                activityStatusBadge = "Sedang Berjalan"
                activityFindingDescription = "Langkah pagi hingga siang ini tercatat \(Int(currentSteps)) langkah. Masih ada selisih sekitar \(remainingHours) jam menuju waktu tidur biasanya (pukul \(baseline.bedtimeString)). Langkah \(parentDisplayName) masih akan terus bertambah seiring rutinitas harian. Aktivitas langkah kaki yang teratur sangat bermanfaat membantu kelenturan dinding pembuluh darah dan menjaga kestabilan tekanan darah."
            } else if currentHour < 21 {
                // Sore hingga Menjelang Malam (16:00 - 21:00): Checkpoint langkah sore
                let afternoonCheckpointTarget = baselineSteps * 0.70 // Acuan sore ~70% dari baseline
                if currentSteps < afternoonCheckpointTarget {
                    isAfternoonStepPushNeeded = true
                    activityStatus = "STABLE"
                    activityStatusBadge = "Perlu Gerak"
                    activityFindingDescription = "Waktu aktif hari ini tersisa selisih sekitar \(remainingHours) jam sebelum jam tidur biasanya (pukul \(baseline.bedtimeString)), namun langkah kaki \(parentDisplayName) (\(Int(currentSteps)) langkah) masih di bawah ritme aktivitas sore (acuan target ~\(Int(afternoonCheckpointTarget)) langkah). Caregiver disarankan mengajak \(parentDisplayName) sedikit bergerak atau jalan santai sore 15–20 menit untuk mengejar target langkah. Rutin memenuhi target langkah kaki harian terbukti membantu elastisitas pembuluh darah dan menjaga tekanan darah tetap stabil."
                } else {
                    activityStatus = "STABLE"
                    activityStatusBadge = "Sedang Berjalan"
                    activityFindingDescription = "Langkah sore terpantau on-track di \(Int(currentSteps)) langkah dengan selisih sekitar \(remainingHours) jam menuju jam tidur biasanya (pukul \(baseline.bedtimeString)). Rutinitas berjalan santai ini sangat baik untuk sirkulasi darah dan mendukung kestabilan tensi."
                }
            } else {
                // Malam hari (>= 21:00): Evaluasi penutupan hari
                if stepsDelta <= -25.0 {
                    activityStatus = "DECLINED"
                    activityStatusBadge = "Menurun"
                    activityFindingDescription = "Hingga malam hari menjelang jam tidur (pukul \(baseline.bedtimeString)), langkah kaki tercatat \(Int(currentSteps)) langkah (berkurang \(abs(Int(stepsDelta)))% dari baseline \(Int(baselineSteps)) langkah). Pastikan \(parentDisplayName) beristirahat cukup malam ini untuk memulihkan kebugaran dan menstabilkan tekanan darah."
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
                isSleep3DayConcern = true
                sleepStatus = "DECLINED"
                sleepStatusBadge = "Perlu Perhatian"
                let hoursLost = String(format: "%.1f", max(0.5, baselineSleep - currentSleep))
                sleepFindingDescription = "Sudah 3 hari ini \(parentDisplayName) selalu terbangun di sekitar jam \(typicalAwakeTime), dan ini menyebabkan tidur \(parentDisplayName) jadi sedikit sehingga berkurang \(hoursLost) jam dari baseline. Kondisi fragmentasi tidur 3 hari ini cukup perlu diperhatikan karena dapat memicu peningkatan tekanan darah saat tidur dan kelelahan."
            } else if currentSleep < 6.0 || sleepDelta <= -20.0 || (efficiency != nil && efficiency! < 75.0) {
                sleepStatus = "DECLINED"
                sleepStatusBadge = "Menurun"
                sleepFindingDescription = "Tidur semalam tercatat \(String(format: "%.1f jam", currentSleep)) (berkurang \(abs(Int(sleepDelta)))% dari baseline \(String(format: "%.1f jam", baselineSleep)), efisiensi tidur \(String(format: "%.0f%%", efficiency ?? 80.0))). Waktu terbangun tercatat \(typicalAwakeDuration) menit."
            } else if (awakeMinutes ?? 0) >= 35.0 || (efficiency != nil && efficiency! < 85.0) {
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
        
        // 4. Evaluasi Domain Detak Jantung (Heart Rate Tunggal, Tanpa RHR)
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
                // Saat Berolahraga: Peningkatan detak jantung adalah respon alami & baik
                heartStatus = "IMPROVED"
                heartStatusBadge = "Meningkat Wajar (Olahraga)"
                heartFindingDescription = "Detak jantung terkini terpantau \(currentHRInt) BPM, meningkat secara wajar karena \(parentDisplayName) sedang atau baru saja berolahraga (\(workoutName ?? "aktivitas fisik")). Respon kardiovaskular ini baik untuk melatih kekuatan jantung."
            } else if currentHR > (baselineHR + 8.0) || currentHR > 85.0 {
                // Saat Santai / Tanpa Olahraga tapi Denyut Meningkat: BUKAN hal bagus!
                // Menandakan beban vaskular berlebih, kelelahan, kurang hidrasi, atau stres
                isLiveHRElevatedWithoutWorkout = true
                heartStatus = "DECLINED"
                heartStatusBadge = "Meningkat (Perlu Perhatian)"
                heartFindingDescription = "Detak jantung terkini terpantau \(currentHRInt) BPM saat kondisi santai, lebih tinggi dari baseline 14 hari (\(hrBaselineInt) BPM). Denyut yang meningkat di saat istirahat dapat mengindikasikan tubuh mengalami kelelahan, kurang cairan (dehidrasi), atau beban kardiovaskular berlebih. Pastikan \(parentDisplayName) minum segelas air putih dan beristirahat santai sejenak."
            } else if currentHR < 55.0 {
                // Denyut Cenderung Lambat (Bradikardia ringan pada lansia)
                heartStatus = "DECLINED"
                heartStatusBadge = "Cenderung Lambat"
                heartFindingDescription = "Detak jantung terkini tercatat \(currentHRInt) BPM (lebih lambat dari baseline \(hrBaselineInt) BPM). Tanyakan apakah \(parentDisplayName) merasa pusing atau lemas, dan pastikan istirahat cukup."
            } else {
                // Normal & Stabil (60 - 80 BPM, dekat dengan baseline)
                heartStatus = "STABLE"
                heartStatusBadge = "Stabil"
                heartFindingDescription = "Detak jantung terkini terpantau \(currentHRInt) BPM dalam ritme santai, stabil selaras dengan baseline 14 hari (\(hrBaselineInt) BPM). Rentang denyut ini sangat baik dan aman bagi orang tua."
            }
        } else {
            hrDelta = 0.0
            heartStatus = "Belum Ada Data"
            heartStatusBadge = "Belum Ada Data"
            heartFindingDescription = "Belum ada catatan detak jantung hari ini di Apple Health."
        }
        
        let evaluatedHeart = EvaluatedDomainMetric(
            domainName: "Detak Jantung",
            currentValue: hasHeart ? currentHR : nil,
            baselineValue: baselineHR,
            deltaPercentage: hrDelta,
            status: heartStatusBadge,
            formattedCurrent: hasHeart ? "\(Int(currentHR)) BPM" : "—",
            formattedBaseline: "\(Int(baselineHR)) BPM",
            hasData: hasHeart,
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
        } else if declinedCount >= 1 && (stepsDelta <= -25.0 || sleepDelta <= -25.0 || hrDelta >= 12.0 || isLiveHRElevatedWithoutWorkout || declinedCount >= 2) {
            overallCondition = "DECLINED"
            let drops = [hasSteps ? stepsDelta : 0, hasSleep ? sleepDelta : 0, hasHeart ? -hrDelta : 0].filter { $0 < 0 }
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
        facts.append("Detak Jantung: \(heartFindingDescription) [Detak Jantung: \(evaluatedHeart.formattedCurrent) vs baseline \(evaluatedHeart.formattedBaseline), status: \(heartStatusBadge), Olahraga: \(isWorkout ? (workoutName ?? "Aktif") : "Tidak Ada")]")
        
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
    
    // MARK: - Local Fallback Generator
    
    func makeLocalFallbackInsight(from overview: EvaluatedHealthOverview, parentName: String = "Ibu") -> LLMInsightOutput {
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
        } else if overview.isWorkoutActive {
            heartInsight = "Detak jantung meningkat wajar saat berolahraga (\(overview.workoutName ?? "aktivitas fisik"))."
        } else if overview.heart.deltaPercentage >= 8.0 {
            heartInsight = "Detak jantung saat santai sedikit meningkat dibanding baseline. Ingatkan untuk cukup minum air dan beristirahat santai sejenak."
        } else {
            heartInsight = "Detak jantung berada di rentang normal dan stabil."
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
    
    func sanitizeInsightOutput(_ output: LLMInsightOutput, overview: EvaluatedHealthOverview) -> LLMInsightOutput {
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
            insight: output.activityInsight.insight
        )
        
        let cleanedSleep = DomainMetricInsight(
            currentValue: overview.sleep.formattedCurrent,
            baselineValue: overview.sleep.formattedBaseline,
            deltaPercentage: overview.sleep.deltaPercentage,
            status: overview.sleep.status,
            insight: output.sleepInsight.insight
        )
        
        let cleanedHeart = DomainMetricInsight(
            currentValue: overview.heart.formattedCurrent,
            baselineValue: overview.heart.formattedBaseline,
            deltaPercentage: overview.heart.deltaPercentage,
            status: overview.heart.status,
            insight: output.heartInsight.insight
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
