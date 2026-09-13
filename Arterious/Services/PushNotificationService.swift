//
//  PushNotificationService.swift
//  Arterious
//
//  Layanan Triage & Pengiriman Push Notification Caregiver
//  Menerapkan batas harian (max 2 push non-urgent/hari), cooldown 24–72 jam,
//  deduplikasi, dan bypass P4 urgent sesuai PRD_Push_Notification_and_AI_Insight.md
//

import Foundation
import UserNotifications

@MainActor
final class PushNotificationService {
    
    static let shared = PushNotificationService()
    
    private let userDefaults = UserDefaults.standard
    private let notificationCenter = UNUserNotificationCenter.current()
    
    // Key storage
    private let dailyCountPrefix = "arterious.push.dailyCount."
    private let domainCooldownPrefix = "arterious.push.cooldown.domain."
    private let episodeCooldownKey = "arterious.push.cooldown.lastEpisodeTime"
    private let handledEventsKey = "arterious.push.handledEventIds"
    
    private init() {}
    
    // MARK: - Process and Deliver
    
    /// Evaluasi apakah push diizinkan berdasarkan triage policy PRD Bab 6, lalu kirimkan via UNUserNotificationCenter jika lolos
    @discardableResult
    func processAndDeliver(_ decision: PushTriageDecision) async -> Bool {
        guard decision.shouldPush, let payload = decision.payload else {
            return false
        }
        
        // 1. Cek izin notifikasi sistem
        let settings = await notificationCenter.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            print("⚠️ PushNotificationService: Izin notifikasi belum diberikan.")
            return false
        }
        
        // 2. Evaluasi Cooldown & Rate Limit berdasarkan Kelas Push (PRD Bab 6)
        let check = evaluatePolicy(for: payload, pushClass: decision.pushClass)
        guard check.isAllowed else {
            print("🛡️ PushNotificationService: Push ditekan (\(payload.urgency.rawValue)) - Alasan: \(check.reason ?? "cooldown")")
            return false
        }
        
        // 3. Bangun konten notifikasi
        let content = UNMutableNotificationContent()
        content.title = payload.title
        content.body = payload.body
        content.sound = (payload.urgency == .p4) ? .defaultCritical : .default
        content.userInfo = [
            "urgency": payload.urgency.rawValue,
            "ruleIds": payload.ruleIds,
            "domain": payload.domain
        ]
        
        let identifier = "arterious.push.\(payload.domain).\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        
        do {
            try await notificationCenter.add(request)
            recordPushDelivery(payload: payload, pushClass: decision.pushClass)
            print("✅ PushNotificationService: Berhasil mengirim push [\(payload.urgency.rawValue)] \(payload.title)")
            return true
        } catch {
            print("❌ PushNotificationService: Gagal menjadwalkan notifikasi: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Policy Evaluation (PRD Section 6)
    
    private func evaluatePolicy(for payload: CaregiverPushPayload, pushClass: PushNotificationClass) -> (isAllowed: Bool, reason: String?) {
        let now = Date()
        
        // KASUS P4: Urgent Safety (Fall, Apple Irregular Rhythm)
        // Bebas dari cooldown dan limit harian, tetapi wajib dideduplikasi berdasarkan eventId (PRD Bab 6.1 & 6.2)
        if pushClass == .p4 {
            if let eventId = payload.eventId, !eventId.isEmpty {
                let handled = Set(userDefaults.stringArray(forKey: handledEventsKey) ?? [])
                if handled.contains(eventId) {
                    return (false, "Event ID \(eventId) sudah pernah dikirim sebelumnya.")
                }
            }
            return (true, nil)
        }
        
        // KASUS P2 & P3: Non-Urgent Caregiver Push
        // 1. Cek Batas Maksimal Harian: Maksimal 2 push non-urgent per caregiver per hari (PRD Bab 6.1)
        let todayKey = dailyKey(for: now)
        let countToday = userDefaults.integer(forKey: todayKey)
        if countToday >= 2 {
            return (false, "Batas maksimal 2 push non-urgent/hari telah tercapai.")
        }
        
        // 2. Cek Cooldown per Domain (P2: 1 push per domain per 24 jam)
        if pushClass == .p2 {
            let domainKey = domainCooldownPrefix + payload.domain
            if let lastTime = userDefaults.object(forKey: domainKey) as? Date {
                let hoursElapsed = now.timeIntervalSince(lastTime) / 3600.0
                if hoursElapsed < 24.0 {
                    return (false, "Cooldown 24 jam domain \(payload.domain) masih aktif (\(Int(24 - hoursElapsed)) jam tersisa).")
                }
            }
        }
        
        // 3. Cek Cooldown Episode (P3: 1 push per episode per 24 jam)
        if pushClass == .p3 {
            if let lastEpisodeTime = userDefaults.object(forKey: episodeCooldownKey) as? Date {
                let hoursElapsed = now.timeIntervalSince(lastEpisodeTime) / 3600.0
                if hoursElapsed < 24.0 {
                    return (false, "Cooldown 24 jam episode eskalasi masih aktif.")
                }
            }
        }
        
        return (true, nil)
    }
    
    // MARK: - State Recording
    
    private func recordPushDelivery(payload: CaregiverPushPayload, pushClass: PushNotificationClass) {
        let now = Date()
        
        if pushClass == .p4, let eventId = payload.eventId, !eventId.isEmpty {
            var handled = Set(userDefaults.stringArray(forKey: handledEventsKey) ?? [])
            handled.insert(eventId)
            userDefaults.set(Array(handled), forKey: handledEventsKey)
            return
        }
        
        // Tambahkan hitungan harian
        let todayKey = dailyKey(for: now)
        let currentCount = userDefaults.integer(forKey: todayKey)
        userDefaults.set(currentCount + 1, forKey: todayKey)
        
        // Simpan waktu per domain
        let domainKey = domainCooldownPrefix + payload.domain
        userDefaults.set(now, forKey: domainKey)
        
        // Jika P3, simpan waktu episode
        if pushClass == .p3 {
            userDefaults.set(now, forKey: episodeCooldownKey)
        }
    }
    
    private func dailyKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return dailyCountPrefix + formatter.string(from: date)
    }
}
