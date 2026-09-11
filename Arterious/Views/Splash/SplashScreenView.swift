import SwiftUI

/// Simple, elegant splash screen displaying the official Arterious logo and application name.
/// Adheres to Apple's recommended SwiftUI lifecycle and design guidelines.
struct SplashScreenView: View {

    @State private var isAnimating: Bool = false

    var body: some View {
        ZStack {
            AppColor.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.md) {
                ArteriousLogoView()
                    .scaleEffect(isAnimating ? 1.0 : 0.9)
                    .opacity(isAnimating ? 1.0 : 0.0)

                Text("Arterious")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)
                    .opacity(isAnimating ? 1.0 : 0.0)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
