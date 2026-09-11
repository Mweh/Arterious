import SwiftUI

/// Main container using Apple's native TabView with built-in liquid glass tab bar.
struct MainContainerView: View {

    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Beranda", systemImage: "house.fill", value: .home) {
                HomeView()
            }

            Tab("Riwayat", systemImage: "clock.arrow.circlepath", value: .history) {
                HistoryView()
            }

            Tab("Akses", systemImage: "link", value: .access) {
                AccessView()
            }
        }
        .tint(AppColor.actionBlue)
    }
}

typealias ParentHomeView = MainContainerView

#Preview {
    MainContainerView()
}
