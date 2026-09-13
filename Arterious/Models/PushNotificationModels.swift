//
//  PushNotificationModels.swift
//  Arterious
//
//  Model data untuk Triage Push Notification dan AI Insight Caregiver
//  Sesuai PRD_Push_Notification_and_AI_Insight.md
//

import Foundation

/// Kelas tingkatan push notification (PRD Section 3)
enum PushNotificationClass: String, Codable, Sendable, Comparable {
    case p0 = "P0" // Informational - Dashboard only
    case p1 = "P1" // Attention - Dashboard / daily summary
    case p2 = "P2" // Check-in caution - Push max 1/domain/24h, max 2 non-urgent/caregiver/hari
    case p3 = "P3" // Escalated warning - Push prioritas
    case p4 = "P4" // Urgent safety - Immediate push + template tetap

    var severityRank: Int {
        switch self {
        case .p0: return 0
        case .p1: return 1
        case .p2: return 2
        case .p3: return 3
        case .p4: return 4
        }
    }

    var requiresPush: Bool {
        return severityRank >= 2
    }

    static func < (lhs: PushNotificationClass, rhs: PushNotificationClass) -> Bool {
        return lhs.severityRank < rhs.severityRank
    }
}

/// Status concern state machine (PRD Section 1 & 6.2)
enum ConcernState: String, Codable, Sendable {
    case observation = "OBSERVATION"
    case newConcern = "NEW_CONCERN"
    case persistentConcern = "PERSISTENT_CONCERN"
    case escalatedConcern = "ESCALATED_CONCERN"
    case urgentOverride = "URGENT_OVERRIDE"
}

/// Trigger evaluasi rule push individu (PRD Section 5)
struct PushRuleTrigger: Codable, Equatable, Sendable {
    let ruleId: String          // e.g. "P-S3", "P-A2", "P-H4", "P-R4", "P-A7"
    let domain: String          // "sleep", "activity", "heart", "multi", "safety"
    let ruleName: String
    let pushClass: PushNotificationClass
    let reason: String
    let action: String
}

/// Konten payload push notification yang dikirim ke caregiver (PRD Section 8.2)
struct CaregiverPushPayload: Codable, Equatable, Sendable {
    let title: String
    let body: String            // Maksimal 160 karakter, wajib menyebut tindakan
    let urgency: PushNotificationClass
    let ruleIds: [String]
    let domain: String
    let eventId: String?        // Digunakan untuk deduplikasi event P4
    let timestamp: Date
}

/// Keputusan lengkap dari Rule Engine Push Triage (PRD Section 1, 2, 6)
struct PushTriageDecision: Codable, Equatable, Sendable {
    let shouldPush: Bool
    let pushClass: PushNotificationClass
    let concernState: ConcernState
    let triggeredRules: [PushRuleTrigger]
    let payload: CaregiverPushPayload?
    let suppressionReason: String? // "no_actionable_push", "cooldown_active", "daily_limit_reached", dll.
}
