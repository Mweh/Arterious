import SwiftUI

/// Defines the 3 bottom navigation tabs for Arterious.
enum AppTab: Int, CaseIterable, Identifiable {
    case home = 0
    case history = 1
    case access = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .history: return "History"
        case .access: return "Access"
        }
    }

    var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .history: return "clock.arrow.circlepath"
        case .access: return "link"
        }
    }
}

typealias ParentTab = AppTab
