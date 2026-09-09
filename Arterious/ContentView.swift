import SwiftUI

struct ContentView: View {

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("userRole") private var userRole: String = UserRole.parent.rawValue
    @State private var isShowingSplash: Bool = true

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
        .task {
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation(.easeInOut(duration: 0.35)) {
                isShowingSplash = false
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
