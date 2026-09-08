import SwiftUI

struct ContentView: View {

    @State private var dashboardVM = DashboardViewModel()
    @State private var selectedTab: Int = 0
    @State private var showConnectedAlert: Bool = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView(
                    syncViewModel: dashboardVM.syncViewModel,
                    hasCompletedOnboarding: $hasCompletedOnboarding
                )
            } else {
                mainAppView
            }
        }
        .onOpenURL { url in
            // Handle arterious://invite?code=XXXX deep links
            guard url.scheme?.lowercased() == "arterious" else { return }
            Task {
                await dashboardVM.syncViewModel.handleIncomingInvite(url: url)
                hasCompletedOnboarding = true
                selectedTab = 2
                showConnectedAlert = true
            }
        }
        .alert("Berhasil Terhubung!", isPresented: $showConnectedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Data kesehatan kamu sekarang terhubung dan otomatis dikirimkan ke anak kamu secara aman via iCloud.")
        }
        .task {
            await dashboardVM.syncViewModel.refreshIfNeeded()
        }
    }

    // MARK: - Main App View

    private var mainAppView: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case 0:
                    DashboardView(viewModel: dashboardVM)
                case 1:
                    NavigationStack {
                        ZStack {
                            Color(hue: 0.6, saturation: 0.02, brightness: 0.97).ignoresSafeArea()
                            ContentUnavailableView(
                                "Riwayat Segera Hadir",
                                systemImage: "clock.arrow.circlepath",
                                description: Text("Pantau tren 7-30 hari kesehatan orang tua kamu.")
                            )
                        }
                        .navigationTitle("Riwayat")
                    }
                case 2:
                    AksesView(syncViewModel: dashboardVM.syncViewModel)
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Floating Pill Tab Bar (Screenshot 1 & 2)
            FloatingTabBar(selectedTab: $selectedTab)
                .padding(.bottom, 12)
        }
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Floating Bottom Tab Bar

struct FloatingTabBar: View {
    @Binding var selectedTab: Int

    var body: some View {
        HStack(spacing: 6) {
            tabItem(title: "Beranda", icon: "house.fill", tag: 0)
            tabItem(title: "Riwayat", icon: "clock.arrow.circlepath", tag: 1)
            tabItem(title: "Akses", icon: "link", tag: 2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white)
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.09), radius: 16, x: 0, y: 5)
        .overlay(
            Capsule()
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
    }

    private func tabItem(title: String, icon: String, tag: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                selectedTab = tag
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                Text(title)
                    .font(.system(size: 10, weight: selectedTab == tag ? .semibold : .regular))
            }
            .frame(width: 68, height: 50)
            .background(
                selectedTab == tag
                    ? Color(hue: 0.58, saturation: 0.14, brightness: 0.94)
                    : Color.clear
            )
            .foregroundStyle(selectedTab == tag ? Color.blue : Color.secondary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
}
