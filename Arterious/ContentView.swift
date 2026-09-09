import SwiftUI

struct ContentView: View {

    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("userRole") private var userRole: String = UserRole.parent.rawValue
    @State private var isShowingSplash: Bool = true
    @State private var syncViewModel = SyncViewModel()

    var body: some View {
        ZStack {
            if isShowingSplash {
                SplashScreenView()
                    .transition(.opacity)
                    .zIndex(1)
            } else {
                mainFlowView
                    .transition(.opacity)
            }
        }
        .environment(syncViewModel)
        .onOpenURL { url in
            Task {
                await syncViewModel.handleIncomingShareURL(url: url)
                if !syncViewModel.showRoleMismatchAlert {
                    hasCompletedOnboarding = true
                }
            }
        }
        .alert("Peran Tidak Sesuai", isPresented: Bindable(syncViewModel).showRoleMismatchAlert) {
            if let target = syncViewModel.pendingRoleSwitchTarget {
                Button("Ganti ke \(target == .parent ? "Orang Tua" : "Anak")") {
                    let newRole = (target == .parent) ? UserRole.parent.rawValue : UserRole.child.rawValue
                    userRole = newRole
                    Task {
                        await syncViewModel.switchRole(to: target)
                        if target == .parent {
                            syncViewModel.shouldShowParentShareFlow = true
                        }
                    }
                }
            }
            Button("Batal", role: .cancel) { }
        } message: {
            Text(syncViewModel.roleMismatchMessage)
        }
        .alert("Gagal Terhubung", isPresented: Binding(
            get: { syncViewModel.errorMessage != nil },
            set: { if !$0 { syncViewModel.errorMessage = nil } }
        )) {
            Button("Tutup", role: .cancel) {
                syncViewModel.errorMessage = nil
            }
        } message: {
            Text(syncViewModel.errorMessage ?? "")
        }
        .overlay(alignment: .top) {
            if syncViewModel.showAcceptedBanner {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColor.Accent.green)
                    Text(syncViewModel.bannerMessage)
                        .font(AppTypography.captionRegular)
                        .foregroundStyle(Color.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.85))
                .clipShape(Capsule())
                .padding(.top, 50)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
                        withAnimation {
                            syncViewModel.showAcceptedBanner = false
                        }
                    }
                }
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation(.easeInOut(duration: 0.35)) {
                isShowingSplash = false
            }
            await syncViewModel.refreshIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await syncViewModel.refreshIfNeeded()
                }
            }
        }
    }

    // MARK: - Main Application Flow

    @ViewBuilder
    private var mainFlowView: some View {
        if !hasCompletedOnboarding {
            OnboardingContainerView()
        } else {
            // Main container coordinating Home, History, and Access tabs with floating tab bar
            MainContainerView()
        }
    }
}

#Preview {
    ContentView()
}
