import SwiftUI

struct SyncSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: SyncViewModel
    @State private var copiedToClipboard: Bool = false

    @MainActor
    init(syncViewModel: SyncViewModel) {
        self.viewModel = syncViewModel
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(hue: 0.0, saturation: 0.8, brightness: 0.2),
                             Color(hue: 0.95, saturation: 0.6, brightness: 0.12)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        roleSection
                        stateSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                }
            }
            .navigationTitle("Family Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.wave.2.fill")
                .font(.system(size: 52))
                .foregroundStyle(.red.gradient)
                .symbolEffect(.pulse)

            Text("Connect with Parent")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("Share your parent's Apple Health data\nso you can stay connected to their wellness.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Role Picker Section

    @ViewBuilder
    private var roleSection: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Peran Perangkat Ini")
                    .font(.headline)
                    .foregroundStyle(.white)

                Picker("Peran", selection: Binding(
                    get: { viewModel.syncState.role },
                    set: { newRole in
                        Task { await viewModel.switchRole(to: newRole) }
                    }
                )) {
                    Text("Saya Anak").tag(SyncRole.child)
                    Text("Saya Orang Tua").tag(SyncRole.parent)
                }
                .pickerStyle(.segmented)

                if viewModel.syncState.role == .child {
                    Text("📱 Sebagai Anak: Aplikasi hanya memantau data orang tua dari iCloud. Aplikasi TIDAK meminta izin ke Apple Health kamu.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineSpacing(2)
                } else {
                    Text("❤️ Sebagai Orang Tua: Aplikasi meminta izin Apple Health untuk mengirimkan detak jantung, tidur, dan langkah ke anak kamu.")
                        .font(.caption)
                        .foregroundStyle(.green.opacity(0.9))
                        .lineSpacing(2)
                }
            }
            .padding(18)
        }
    }

    // MARK: - Dynamic State Section

    @ViewBuilder
    private var stateSection: some View {
        switch viewModel.syncState.status {
        case .none:
            notConnectedView
        case .pending:
            pendingView
        case .accepted:
            connectedView
        }
    }

    // MARK: - Not Connected View

    private var notConnectedView: some View {
        VStack(spacing: 16) {
            glassCard {
                VStack(spacing: 20) {
                    Image(systemName: "shareplay")
                        .font(.system(size: 40))
                        .foregroundStyle(.red)

                    VStack(spacing: 8) {
                        Text("Hubungkan dengan Orang Tua")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Kirim link ke HP orang tua via WhatsApp atau Messages. Begitu orang tua klik link-nya, data kesehatan langsung terhubung secara otomatis.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }

                    actionButton(
                        title: viewModel.isLoading ? "Membuat Link…" : "Bagikan Link ke Orang Tua",
                        icon: "square.and.arrow.up.fill",
                        isLoading: viewModel.isLoading
                    ) {
                        Task {
                            if let url = await viewModel.requestShareLink() {
                                ShareSheetHelper.share(url: url)
                            }
                        }
                    }
                }
                .padding(24)
            }

            if let error = viewModel.errorMessage {
                errorBanner(error)
            }
        }
    }

    // MARK: - Pending View

    private var pendingView: some View {
        VStack(spacing: 16) {
            glassCard {
                VStack(spacing: 20) {
                    ProgressView()
                        .tint(.red)
                        .scaleEffect(1.4)

                    VStack(spacing: 8) {
                        Text("Menunggu Orang Tua Terhubung…")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Kirim link ke orang tua dan minta mereka klik link tersebut. Halaman ini akan otomatis terupdate begitu mereka terhubung.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }

                    if let url = viewModel.inviteURL {
                        VStack(spacing: 12) {
                            Button {
                                ShareSheetHelper.share(url: url)
                            } label: {
                                Label("Buka Menu Share Lagi", systemImage: "square.and.arrow.up.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(.red.gradient)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }

                            Button {
                                UIPasteboard.general.string = url.absoluteString
                                copiedToClipboard = true
                                Task {
                                    try? await Task.sleep(for: .seconds(2))
                                    copiedToClipboard = false
                                }
                            } label: {
                                Label(copiedToClipboard ? "Link Disalin!" : "Salin Link",
                                      systemImage: copiedToClipboard ? "checkmark" : "doc.on.doc")
                                    .font(.subheadline.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(.white.opacity(0.1))
                                    .foregroundStyle(copiedToClipboard ? .green : .white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }
                .padding(24)
            }

            if let error = viewModel.errorMessage {
                errorBanner(error)
            }
        }
    }

    // MARK: - Connected View

    private var connectedView: some View {
        VStack(spacing: 16) {
            glassCard {
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(.green.opacity(0.2))
                                .frame(width: 48, height: 48)
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.green)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Connected")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Syncing \(viewModel.parentName)'s health data")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        Spacer()
                    }

                    Divider().background(.white.opacity(0.15))

                    HStack {
                        Label("Last synced", systemImage: "clock.arrow.circlepath")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                        Spacer()
                        Text(viewModel.lastSyncDate.map { $0.formatted(.relative(presentation: .named)) } ?? "Never")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    if viewModel.syncState.role == .child {
                        HStack {
                            Label("Updates", systemImage: "bell.badge.fill")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                            Spacer()
                            Text("Near real-time via CloudKit")
                                .font(.caption.bold())
                                .foregroundStyle(.green.opacity(0.9))
                        }
                    }
                }
                .padding(20)
            }

            Button(role: .destructive) {
                Task { await viewModel.disconnect() }
            } label: {
                Label("Disconnect", systemImage: "xmark.circle")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.white.opacity(0.08))
                    .foregroundStyle(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: - Reusable Components

    @ViewBuilder
    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(.ultraThinMaterial.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            )
    }

    @ViewBuilder
    private func actionButton(title: String, icon: String, isLoading: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isLoading ? AnyShapeStyle(Color.gray) : AnyShapeStyle(Color.red.gradient))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(isLoading)
    }

    @ViewBuilder
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white)
        }
        .padding(14)
        .background(.red.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Share Sheet Helper

@MainActor
enum ShareSheetHelper {
    static func share(url: URL, customMessage: String? = nil) {
        let message = customMessage ?? "Hubungkan data kesehatan kita di Arterious:\n\(url.absoluteString)"
        let activityVC = UIActivityViewController(activityItems: [url, message], applicationActivities: nil)

        guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene ?? UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        topVC.present(activityVC, animated: true)
    }
}

// MARK: - Preview

#Preview {
    SyncSetupView(syncViewModel: SyncViewModel())
}

