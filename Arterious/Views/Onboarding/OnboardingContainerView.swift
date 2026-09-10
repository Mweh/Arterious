import SwiftUI

/// Container managing the 3-step onboarding flow for Arterious.
struct OnboardingContainerView: View {

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("userRole") private var storedUserRole: String = UserRole.parent.rawValue

    @State private var currentStep: Int = 1
    @State private var selectedRole: UserRole = .parent

    var onFinish: (() -> Void)?

    var body: some View {
        ZStack {
            AppColor.backgroundPrimary
                .ignoresSafeArea()

            // Step Content
            Group {
                switch currentStep {
                case 1:
                    OnboardingWelcomeView {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep = 2
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .move(edge: .leading))
                    ))

                case 2:
                    OnboardingRoleView(selectedRole: $selectedRole) {
                        storedUserRole = selectedRole.rawValue
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep = 3
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .move(edge: .leading))
                    ))

                case 3:
                    OnboardingHealthView {
                        completeOnboarding()
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .move(edge: .leading))
                    ))

                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.width > 60 && currentStep > 1 {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep -= 1
                        }
                    }
                }
        )
    }

    // MARK: - Completion

    private func completeOnboarding() {
        storedUserRole = selectedRole.rawValue
        withAnimation(.easeInOut(duration: 0.35)) {
            hasCompletedOnboarding = true
            onFinish?()
        }
    }
}

#Preview {
    OnboardingContainerView()
}
