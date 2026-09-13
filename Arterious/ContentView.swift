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
            get: { syncViewModel.errorMessage != nil && syncViewModel.connectionHUD == nil },
            set: { if !$0 { syncViewModel.errorMessage = nil } }
        )) {
            Button("Tutup", role: .cancel) {
                syncViewModel.errorMessage = nil
            }
        } message: {
            Text(syncViewModel.errorMessage ?? "")
        }
        .overlay {
            if syncViewModel.isInitialConnecting {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    VStack(spacing: AppSpacing.md) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(AppColor.actionBlue)

                        Text(syncViewModel.loadingStatusMessage.isEmpty ? "Menghubungkan ke Orang Tua..." : syncViewModel.loadingStatusMessage)
                            .font(AppTypography.bodySemibold)
                            .foregroundStyle(AppColor.textPrimary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.vertical, AppSpacing.lg)
                    .background(AppColor.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.r24))
                    .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 6)
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: syncViewModel.isInitialConnecting)
            }
        }
        .overlay {
            if let hud = syncViewModel.connectionHUD {
                NativeStatusHUD(
                    type: hud.type,
                    title: hud.title,
                    message: hud.message,
                    onDismiss: {
                        syncViewModel.dismissHUD()
                    }
                )
                .transition(.scale(scale: 0.88).combined(with: .opacity))
                .zIndex(999)
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
