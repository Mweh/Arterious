import SwiftUI
import CloudKit

/// Confirmation and invitation view matching Apple Health Sharing screens in full Indonesian.
/// Features a single "Bagikan Tautan" button and a clean checkmark confirmation on completion.
struct ShareDataView: View {

    @Environment(SyncViewModel.self) private var syncViewModel

    var contactName: String = "Keluarga"
    var contactPhone: String = ""
    let onBack: () -> Void
    let onDismiss: () -> Void
    let onConfirm: () -> Void

    @State private var currentStep: Int = 1 // 1: Review & Share, 2: Invitation Sent
    @State private var isPreparingShare: Bool = false

    var body: some View {
        ZStack {
            AppColor.backgroundPrimary
                .ignoresSafeArea()

            if currentStep == 1 {
                reviewAndShareContent
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                    ))
            } else {
                invitationSentContent
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 1.05)),
                        removal: .opacity
                    ))
            }
        }
        .task {
            // Pre-warm the native share link immediately in background upon view load
            if syncViewModel.nativeShare == nil {
                _ = await syncViewModel.requestNativeShare(suppressErrorMessage: true)
            }
        }
    }

    // MARK: - Step 1: "Data yang Akan Dibagikan" (Apple Health style in full Indonesian)

    private var reviewAndShareContent: some View {
        VStack(spacing: 0) {
            // Native Top Bar: Exactly matching iOS native sheet with only the X button on the top right
            HStack {
                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
            .padding(.bottom, AppSpacing.xs)

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    // Center Graphic: Health Card → Family Icon (No initials)
                    HStack(spacing: AppSpacing.lg) {
                        Spacer()

                        // Health Document Card
                        ZStack {
                            RoundedRectangle(cornerRadius: AppRadius.md)
                                .fill(LinearGradient(
                                    colors: [Color(red: 0.45, green: 0.45, blue: 0.95), Color(red: 0.0, green: 0.78, blue: 0.75)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 54, height: 60)

                            VStack(spacing: 5) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.white)

                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.white.opacity(0.85))
                                    .frame(width: 24, height: 2.5)

                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.white.opacity(0.85))
                                    .frame(width: 16, height: 2.5)
                            }
                        }

                        Image(systemName: "arrow.right")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color(red: 0.0, green: 0.78, blue: 0.75))

                        // Recipient Family Avatar
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Color(red: 0.65, green: 0.72, blue: 0.95), Color(red: 0.52, green: 0.58, blue: 0.88)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 60, height: 60)

                            Image(systemName: "person.2.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(Color.white)
                        }

                        Spacer()
                    }
                    .padding(.top, AppSpacing.sm)

                    // Title & Description in Indonesian
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("Data yang Akan Dibagikan")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppColor.textPrimary)
                            .lineSpacing(2)

                        Text("Anda akan membagikan data kesehatan berikut kepada keluarga Anda. Anda dapat menghentikan pembagian kapan saja melalui pengaturan.")
                            .font(AppTypography.subheadlineRegular)
                            .foregroundStyle(AppColor.textSecondary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Topik Kesehatan Section
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Topik Kesehatan")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(AppColor.textPrimary)

                        VStack(spacing: 0) {
                            topicRow(icon: "heart.fill", color: AppColor.Accent.red, title: "Detak Jantung", subtitle: "BPM harian & rentang normal")
                            Divider().padding(.leading, 52)
                            topicRow(icon: "bed.double.fill", color: Color(red: 0.55, green: 0.45, blue: 0.9), title: "Waktu Tidur", subtitle: "Durasi tidur & pola istirahat")
                            Divider().padding(.leading, 52)
                            topicRow(icon: "figure.walk", color: AppColor.Accent.green, title: "Langkah & Aktivitas", subtitle: "Jumlah langkah harian")
                        }
                        .background(AppColor.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.r24))
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xxl)
            }

            // Bottom Action: "Bagikan Tautan"
            VStack {
                Button(action: handleShare) {
                    HStack(spacing: AppSpacing.xs) {
                        if isPreparingShare {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15, weight: .medium))
                        }

                        Text("Bagikan Tautan")
                            .font(AppTypography.buttonLabel)
                    }
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppColor.actionBlue)
                    .clipShape(Capsule())
                }
                .disabled(isPreparingShare)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
    }

    // MARK: - Step 2: Invitation Sent Confirmation

    private var invitationSentContent: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            // Checkmark animation
            ZStack {
                Circle()
                    .fill(AppColor.Accent.green.opacity(0.12))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(AppColor.Accent.green)
            }
            .padding(.bottom, AppSpacing.xl)

            // Content Copy
            VStack(alignment: .center, spacing: AppSpacing.sm) {
                Text("Bagikan Data")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Memberikan akses memungkinkan orang yang kamu pilih untuk melihat tren kesehatanmu secara berkala dan menerima pembaruan saat ada perubahan.")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }

            Spacer()

            // Actions
            VStack(spacing: AppSpacing.sm) {
                AppButton(
                    title: "Lanjut",
                    isFullWidth: true,
                    action: onConfirm
                )

                Button(action: onDismiss) {
                    Text("Batal")
                        .font(AppTypography.buttonLabel)
                        .foregroundStyle(AppColor.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .background(Color(.systemGray6))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
    }

    // MARK: - Topic Row Helper

    private func topicRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColor.textPrimary)

                Text(subtitle)
                    .font(AppTypography.captionRegular)
                    .foregroundStyle(AppColor.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 12)
    }

    // MARK: - Sharing Actions

    private func constructInvitationMessage(code: String, rawURL: String) -> String {
        return rawURL
    }

    private func handleShare() {
        isPreparingShare = true

        Task {
            let (code, rawURL) = await syncViewModel.prepareSingleUseShareInvite()
            let message = constructInvitationMessage(code: code, rawURL: rawURL)

            await MainActor.run {
                self.isPreparingShare = false
                presentShareSheet(message: message)
            }
        }
    }

    private func presentShareSheet(message: String) {
        guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
                ?? UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return
        }
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        let activityVC = UIActivityViewController(activityItems: [message], applicationActivities: nil)
        activityVC.completionWithItemsHandler = { _, completed, _, _ in
            if completed {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                    currentStep = 2
                }
            }
        }
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        topVC.present(activityVC, animated: true)
    }
}

#Preview {
    ShareDataView(
        contactName: "Keluarga",
        contactPhone: "",
        onBack: { },
        onDismiss: { },
        onConfirm: { }
    )
    .environment(SyncViewModel())
}

