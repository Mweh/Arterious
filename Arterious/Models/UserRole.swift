import Foundation

/// Represents the user's role in the Arterious application.
enum UserRole: String, Codable, CaseIterable, Identifiable {
    case parent = "parent"
    case child = "child"

    var id: String { rawValue }

    /// Title for the role.
    var title: String {
        switch self {
        case .parent:
            return "Parent"
        case .child:
            return "Child"
        }
    }

    /// Descriptive copy for the role selection screen.
    var description: String {
        switch self {
        case .parent:
            return "Use the app to monitor and maintain your wellness."
        case .child:
            return "Monitor parent wellness trends & receive notifications on important changes."
        }
    }

    /// SF Symbol icon representing the role.
    var iconName: String {
        switch self {
        case .parent:
            return "person.fill"
        case .child:
            return "person.2.fill"
        }
    }
}
