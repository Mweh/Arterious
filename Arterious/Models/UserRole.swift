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
            return "Orang Tua"
        case .child:
            return "Anak"
        }
    }

    /// Descriptive copy for the role selection screen.
    var description: String {
        switch self {
        case .parent:
            return "Gunakan aplikasi untuk memantau dan menjaga kesehatan Anda."
        case .child:
            return "Pantau kondisi orang tua & notifikasi saat ada perubahan penting"
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
