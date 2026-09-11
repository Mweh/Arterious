//
//  OverallCareStatus.swift
//  Arterious
//
//  Enum overall care status sesuai PRD §10.
//  Menentukan kapan LLM dipakai vs template (§12.1).
//

import Foundation

/// Overall care status dari rule engine — PRD §10
///
/// | Status      | LLM dipakai?                  |
/// |-------------|-------------------------------|
/// | STABLE      | Tidak — pakai template        |
/// | ATTENTION   | Template atau LLM             |
/// | CAUTION     | LLM + structured input + validator |
/// | WARNING     | Template terkontrol, LLM opsional |
/// | URGENT      | Template tetap TANPA LLM      |
enum OverallCareStatus: String, Codable, CaseIterable, Identifiable {
    case stable    = "STABLE"
    case attention = "ATTENTION"
    case caution   = "CAUTION"
    case warning   = "WARNING"
    case urgent    = "URGENT"
    
    var id: String { rawValue }
    
    /// Apakah LLM boleh dipanggil untuk status ini (PRD §12.1)
    var shouldUseLLM: Bool {
        switch self {
        case .stable:    return false
        case .attention: return true   // template atau LLM
        case .caution:   return true   // LLM wajib dengan validator
        case .warning:   return true   // LLM opsional untuk penjelasan non-kritis
        case .urgent:    return false  // template tetap, TANPA LLM
        }
    }
    
    /// Label UI bahasa Indonesia
    var labelID: String {
        switch self {
        case .stable:    return "Stabil"
        case .attention: return "Perlu diperhatikan"
        case .caution:   return "Caution"
        case .warning:   return "Warning"
        case .urgent:    return "Urgent"
        }
    }
}
