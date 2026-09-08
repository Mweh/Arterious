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
                    // Parent moves to Health Access step
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

    // MARK: - Step 2: Health Access Step (Screenshot 2)

    private var healthAccessStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header Text
            VStack(alignment: .leading, spacing: 8) {
                Text("Hubungkan ke Health")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.primary)

                Text("Arterious membutuhkan izin akses data kesehatan agar dapat berfungsi dengan optimal. Tenang saja, data kesehatanmu hanya disimpan secara lokal di perangkat dan tidak akan pernah diunggah.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }
            .padding(.top, 24)

            // Mockup Graphic (Replicating Screenshot 2 illustration)
            healthPermissionMockupView
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)

            Spacer()

            // "Hubungkan" Action Button
            Button {
                Task {
                    isRequestingHealth = true
                    await syncViewModel.switchRole(to: .parent)
                    isRequestingHealth = false
                    hasCompletedOnboarding = true
                }
            } label: {
                HStack(spacing: 8) {
                    if isRequestingHealth {
                        ProgressView().tint(.white)
                    }
                    Text("Hubungkan")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .shadow(color: Color.blue.opacity(0.28), radius: 8, y: 4)
            }
            .disabled(isRequestingHealth)

            // Medical Disclaimer
            Text("Data kamu tidak pernah meninggalkan perangkat ini. Arterious bukan pengganti saran medis profesional. Selalu konsultasikan dengan dokter.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 16)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Health Mockup Graphic

    private var healthPermissionMockupView: some View {
        VStack(spacing: 12) {
            // Heart Icon with Shadow
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
                    .frame(width: 60, height: 60)
                    .shadow(color: Color.black.opacity(0.08), radius: 8, y: 3)

                Image(systemName: "heart.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.red)
            }
            .padding(.top, 16)

            Text("Health")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)

            // Simulated "Turn On All" pill
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(white: 0.92))
                .frame(height: 32)
                .overlay(
                    HStack {
                        Text("Turn On All")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                )
                .padding(.horizontal, 20)

            // Simulated permission rows
            VStack(spacing: 10) {
                mockPermissionRow(title: "Heart Rate")
                Divider()
                mockPermissionRow(title: "HRV")
                Divider()
                mockPermissionRow(title: "Sleep")
                Divider()
                mockPermissionRow(title: "Activity")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(Color(white: 0.98))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 12, y: 4)
    }

    private func mockPermissionRow(title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.secondary)
            Spacer()
            Text("Detail")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Image(systemName: "chevron.right")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }
}

#Preview {
    OnboardingView(
        syncViewModel: SyncViewModel(),
        hasCompletedOnboarding: .constant(false)
    )
}
