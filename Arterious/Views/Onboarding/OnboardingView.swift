import SwiftUI

struct OnboardingView: View {
    @Bindable var syncViewModel: SyncViewModel
    @Binding var hasCompletedOnboarding: Bool

    @State private var selectedRole: SyncRole = .child
    @State private var currentStep: Int = 1
    @State private var isRequestingHealth: Bool = false

    var body: some View {
        ZStack {
            Color(hue: 0.6, saturation: 0.02, brightness: 0.98)
                .ignoresSafeArea()

            if currentStep == 1 {
                roleSelectionStep
                    .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading)))
            } else {
                healthAccessStep
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.28), value: currentStep)
    }

    // MARK: - Step 1: Role Selection

    private var roleSelectionStep: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Selamat Datang di Arterious")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.primary)

                Text("Pilih peran kamu untuk memulai pemantauan kesehatan keluarga.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)

            VStack(spacing: 16) {
                roleOptionCard(
                    role: .child,
                    icon: "person.2.fill",
                    iconColor: .blue,
                    title: "Saya Anak",
                    subtitle: "Pantau tren kesehatan orang tua dari jauh tanpa perlu menghubungkan Apple Health kamu."
                )

                roleOptionCard(
                    role: .parent,
                    icon: "heart.text.square.fill",
                    iconColor: .red,
                    title: "Saya Orang Tua",
                    subtitle: "Bagikan data detak jantung, tidur, dan aktivitas harian kamu ke anak secara aman."
                )
            }

            Spacer()

            Button {
                if selectedRole == .child {
                    // Child goes directly to Home without HealthKit access!
                    Task {
                        await syncViewModel.switchRole(to: .child)
                        hasCompletedOnboarding = true
                    }
                } else {
                    // Parent moves to Health Access step to trigger native iOS sheet
                    currentStep = 2
                }
            } label: {
                Text("Lanjutkan")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .shadow(color: Color.blue.opacity(0.25), radius: 8, y: 4)
            }
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
    }

    private func roleOptionCard(role: SyncRole, icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        Button {
            selectedRole = role
        } label: {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.primary)

                        Spacer()

                        Image(systemName: selectedRole == role ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundStyle(selectedRole == role ? Color.blue : Color.secondary.opacity(0.4))
                    }

                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(20)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(selectedRole == role ? Color.blue : Color.black.opacity(0.05), lineWidth: selectedRole == role ? 2 : 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 2: Health Access Step

    private var healthAccessStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Button {
                currentStep = 1
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("Kembali")
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.blue)
            }
            .padding(.top, 16)

            VStack(alignment: .leading, spacing: 8) {
                Text("Hubungkan ke Apple Health")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.primary)

                Text("Sebagai orang tua, Arterious membutuhkan izin resmi Apple Health untuk membaca data detak jantung, tidur, dan aktivitas agar dapat dibagikan ke anak kamu.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }
            .padding(.top, 8)

            Spacer()

            // Visual Card
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.12))
                        .frame(width: 90, height: 90)

                    Image(systemName: "heart.fill")
                        .font(.system(size: 46))
                        .foregroundStyle(.red)
                }

                VStack(spacing: 6) {
                    Text("Izin Resmi Apple Health")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text("Ketuk tombol di bawah untuk menampilkan dialog izin sistem Apple Health.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 12, y: 4)

            Spacer()

            // Trigger Real Native Apple Health Permission Sheet
            Button {
                Task {
                    isRequestingHealth = true
                    // Switch role to parent and trigger real native HealthKit authorization dialog
                    await syncViewModel.switchRole(to: .parent)
                    isRequestingHealth = false
                    hasCompletedOnboarding = true
                }
            } label: {
                HStack(spacing: 8) {
                    if isRequestingHealth {
                        ProgressView().tint(.white)
                    }
                    Text("Hubungkan ke Apple Health")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .shadow(color: Color.blue.opacity(0.28), radius: 8, y: 4)
            }
            .disabled(isRequestingHealth)

            // Disclaimer
            Text("Arterious mencerminkan tren kesehatan umum dan bukan pengganti diagnosis medis.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 16)
        }
        .padding(.horizontal, 24)
    }
}

#Preview {
    OnboardingView(
        syncViewModel: SyncViewModel(),
        hasCompletedOnboarding: .constant(false)
    )
}
