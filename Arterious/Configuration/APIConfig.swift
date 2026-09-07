//
//  APIConfig.swift
//  Arterious
//
//  Konfigurasi API untuk Gemini LLM.
//  API key dimuat secara otomatis dan aman dari file .env (atau Environment variable).
//

import Foundation

// MARK: - Gemini Models

/// Model Gemini yang tersedia di Google Generative Language API.
enum GeminiModel: String, CaseIterable, Identifiable {
    /// Pilihan utama: Sangat cepat, hemat, dan akurat untuk JSON terstruktur (Recommended)
    case gemini35FlashLite = "gemini-3.5-flash-lite"
    
    /// Model generasi 3.5 serba guna dan seimbang
    case gemini35Flash = "gemini-3.5-flash"
    
    /// Model Gemini 3.6 Flash
    case gemini36Flash = "gemini-3.6-flash"
    
    /// Auto-alias ke model Flash-Lite terbaru
    case geminiFlashLiteLatest = "gemini-flash-lite-latest"
    
    /// Auto-alias ke model Flash terbaru
    case geminiFlashLatest = "gemini-flash-latest"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .gemini35FlashLite: return "Gemini 3.5 Flash-Lite (Fast & Recommended)"
        case .gemini35Flash: return "Gemini 3.5 Flash"
        case .gemini36Flash: return "Gemini 3.6 Flash"
        case .geminiFlashLiteLatest: return "Gemini Flash-Lite Latest"
        case .geminiFlashLatest: return "Gemini Flash Latest"
        }
    }
}

// MARK: - API Configuration

enum APIConfig {
    
    // MARK: - Settings
    
    /// Base URL Google Generative Language API
    static let baseURL = "https://generativelanguage.googleapis.com/v1beta"
    
    /// Model Gemini aktif yang dipakai saat ini
    static var activeModel: GeminiModel = .gemini35FlashLite
    
    /// API Key Gemini yang diambil otomatis dari file .env
    static var apiKey: String {
        DotEnv.get("GEMINI_API_KEY") ?? ""
    }
    
    /// Status apakah API key sudah berhasil terbaca
    static var isConfigured: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Endpoints
    
    /// URL endpoint generateContent untuk model tertentu
    static func endpointURL(for model: GeminiModel = activeModel) -> URL? {
        var components = URLComponents(string: "\(baseURL)/models/\(model.rawValue):generateContent")
        components?.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        return components?.url
    }
    
    // MARK: - Backward Compatibility Aliases
    
    static var geminiAPIKey: String { apiKey }
    static var geminiModel: String { activeModel.rawValue }
    static var geminiBaseURL: String { baseURL }
    static var geminiGenerateContentURL: String {
        endpointURL()?.absoluteString ?? "\(baseURL)/models/\(activeModel.rawValue):generateContent?key=\(apiKey)"
    }
    static var isAPIKeyConfigured: Bool { isConfigured }
}

// MARK: - DotEnv Reader (Private Utility)

/// Modul internal untuk memuat dan mem-parsing key-value dari .env secara efisien
private enum DotEnv {
    
    /// Cache memory agar file disk hanya dibaca satu kali
    private static var values: [String: String]? = {
        loadVariables()
    }()
    
    static func get(_ key: String) -> String? {
        if let envVal = ProcessInfo.processInfo.environment[key], !envVal.isEmpty {
            return envVal
        }
        return values?[key]
    }
    
    private static func loadVariables() -> [String: String] {
        var parsed: [String: String] = [:]
        
        for url in candidateURLs {
            guard FileManager.default.fileExists(atPath: url.path),
                  let content = try? String(contentsOf: url, encoding: .utf8) else {
                continue
            }
            
            for rawLine in content.components(separatedBy: .newlines) {
                let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !line.isEmpty && !line.hasPrefix("#") else { continue }
                
                let parts = line.split(separator: "=", maxSplits: 1).map { String($0) }
                guard parts.count == 2 else { continue }
                
                let k = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let v = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                               .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                parsed[k] = v
            }
            
            if !parsed.isEmpty { break }
        }
        
        return parsed
    }
    
    private static var candidateURLs: [URL] {
        var urls: [URL] = []
        
        // 1. Path di sebelah file APIConfig.swift (Simulator & Previews)
        let fileDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        urls.append(fileDir.appendingPathComponent(".env"))
        
        // 2. Path relative project root
        let rootDir = fileDir.deletingLastPathComponent().deletingLastPathComponent()
        urls.append(rootDir.appendingPathComponent(".env"))
        urls.append(rootDir.appendingPathComponent("Arterious/Configuration/.env"))
        
        // 3. Current working directory
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        urls.append(cwd.appendingPathComponent("Arterious/Configuration/.env"))
        urls.append(cwd.appendingPathComponent(".env"))
        
        // 4. App Bundle resources
        if let bundleURL = Bundle.main.url(forResource: ".env", withExtension: nil) {
            urls.append(bundleURL)
        }
        
        return urls
    }
}
