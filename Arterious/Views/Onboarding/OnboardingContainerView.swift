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

            VStack(spacing: 0) {
                // Top Navigation Bar
                topNavigationBar

                // Screen Steps
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
            }
        }
    }

    // MARK: - Top Navigation Bar

    private var topNavigationBar: some View {
        HStack {
            if currentStep > 1 {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep -= 1
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColor.textPrimary)
                        .padding(AppSpacing.xs)
                }
            }

            Spacer()
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.xs)
        .frame(height: 44)
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
