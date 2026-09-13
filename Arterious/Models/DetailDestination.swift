import Foundation

/// Value-based navigation destinations used with NavigationStack(path:).
/// Centralises all detail-screen routes so tab-bar visibility can be
/// driven by navigation depth rather than per-view toolbar preferences.
enum DetailDestination: Hashable {
    case heartRate
    case sleep
    case activity
    case llmInsight
    case personalDetails(name: String)
}
