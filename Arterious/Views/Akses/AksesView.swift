import SwiftUI

struct AksesView: View {
    @Bindable var syncViewModel: SyncViewModel
    @State private var isSharing: Bool = false
    @State private var showDetailSheet: Bool = false
    @State private var isEditing: Bool = false
    @State private var showEnterCodeAlert: Bool = false
    @State private var inputCode: String = ""
    @State private var copiedToClipboard: Bool = false
    @State private var showErrorAlert: Bool = false

    private var isParent: Bool {
        syncViewModel.syncState.role == .parent
    }

    private var partnerDisplayName: String {
        if let partner = syncViewModel.syncState.partnerName, !partner.isEmpty {
            return partner
        }
        return isParent ? "Anak" : syncViewModel.parentName
    }

    private var partnerRoleSubtitle: String {
        isParent ? "Anak (Pemantau)" : "Orang Tua"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hue: 0.6, saturation: 0.02, brightness: 0.97)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // White card containing list of connected access
                        VStack(spacing: 0) {
                            switch syncViewModel.syncState.status {
                            case .accepted:
                                partnerRow(name: partnerDisplayName, roleSubtitle: partnerRoleSubtitle) {
                                    showDetailSheet = true
                                }
                            case .pending:
                                pendingStateCard
                            case .none:
                                notPairedStateCard
                            }
                        }
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.black.opacity(0.03), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Akses")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if syncViewModel.syncState.status == .accepted {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        // Circular '+' Button to Invite
                        Button {
                            triggerShare()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 38, height: 38)
                                    .shadow(color: Color.black.opacity(0.06), radius: 6, y: 2)

                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.primary)
                            }
                        }

                        // Circular 'Edit' (Pencil) Button
                        Button {
                            withAnimation {
                                isEditing.toggle()
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 38, height: 38)
                                    .shadow(color: Color.black.opacity(0.06), radius: 6, y: 2)

                                Image(systemName: "pencil")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(isEditing ? Color.blue : Color.primary)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showDetailSheet) {
                partnerDetailSheet
            }
            .alert("Masukkan Kode Undangan", isPresented: $showEnterCodeAlert) {
                TextField("Contoh: AJ7YZ5B5", text: $inputCode)
                    .textInputAutocapitalization(.characters)
                Button("Hubungkan") {
                    let clean = inputCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                    guard !clean.isEmpty, let url = URL(string: "arterious://invite?code=\(clean)") else { return }
                    Task {
                        await syncViewModel.handleIncomingInvite(url: url)
                        inputCode = ""
                        if syncViewModel.errorMessage != nil {
                            showErrorAlert = true
                        }
                    }
                }
                Button("Batal", role: .cancel) {
                    inputCode = ""
                }
            } message: {
                Text("Masukkan 8 digit kode undangan dari HP keluarga kamu.")
            }
            .alert("Peringatan Gagal", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {
                    syncViewModel.errorMessage = nil
                }
            } message: {
                Text(syncViewModel.errorMessage ?? "Terjadi kesalahan saat menghubungkan.")
            }
            .onChange(of: syncViewModel.errorMessage) { _, newMsg in
                if newMsg != nil {
                    showErrorAlert = true
                }
            }
        }
    }

    // MARK: - Not Paired State Card (.none)

    private var notPairedStateCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 28))
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Belum ada akses terhubung")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(isParent
                         ? "Hubungkan ke anak kamu untuk mulai membagikan data kesehatan secara aman."
                         : "Hubungkan ke orang tua kamu untuk memantau tren kesehatan dari jauh.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }

            Button {
                triggerShare()
            } label: {
                HStack(spacing: 6) {
                    if isSharing || syncViewModel.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                    }
                    Text(isParent ? "Hubungkan ke Anak" : "Hubungkan ke Orang Tua")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
            .disabled(isSharing || syncViewModel.isLoading)

            Button {
                showEnterCodeAlert = true
            } label: {
                Text("Punya kode undangan? Masukkan Kode")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.blue)
            }
            .padding(.top, 2)
        }
        .padding(20)
    }

    // MARK: - Pending State Card (.pending)

    private var pendingStateCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(0.9)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Menunggu Koneksi…")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    
                    Text("Minta lawan memasukkan kode ini atau klik link undangan.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if let code = syncViewModel.syncState.inviteCode {
                VStack(spacing: 8) {
                    Text("KODE UNDANGAN KAMU")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                    
                    Text(code)
                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                        .foregroundStyle(.blue)
                        .tracking(3)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )

                HStack(spacing: 10) {
                    // Copy Code Button
                    Button {
                        UIPasteboard.general.string = code
                        copiedToClipboard = true
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            copiedToClipboard = false
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: copiedToClipboard ? "checkmark" : "doc.on.doc")
                            Text(copiedToClipboard ? "Tersalin!" : "Salin Kode")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(copiedToClipboard ? Color.green.opacity(0.12) : Color.black.opacity(0.05))
                        .foregroundStyle(copiedToClipboard ? Color.green : Color.primary)
                        .clipShape(Capsule())
                    }

                    // Share Link Button
                    Button {
                        triggerShare()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Bagikan Link")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                }
            }

            Divider().padding(.vertical, 2)

            HStack {
                Button {
                    showEnterCodeAlert = true
                } label: {
                    Text("Lawan sudah punya kode? Masukkan Kode")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.blue)
                }
                Spacer()
                Button {
                    Task { await syncViewModel.disconnect() }
                } label: {
                    Text("Batal")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(20)
    }

    // MARK: - Partner Row Component

    private func partnerRow(name: String, roleSubtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 28))
                    .foregroundStyle(.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.primary)

                    Text(roleSubtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isEditing {
                    Button(role: .destructive) {
                        Task { await syncViewModel.disconnect() }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.red)
                    }
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Detail / Manage Sheet

    private var partnerDetailSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.blue.gradient)

                    Text(partnerDisplayName)
                        .font(.title2.bold())

                    HStack(spacing: 6) {
                        Circle().fill(Color.green).frame(width: 8, height: 8)
                        Text("Terhubung via iCloud")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 24)

                VStack(spacing: 12) {
                    HStack {
                        Text("Sinkronisasi Terakhir")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(syncViewModel.lastSyncDate.map { $0.formatted(.relative(presentation: .named)) } ?? "Hari ini")
                            .font(.subheadline.bold())
                    }
                    .padding()
                    .background(Color(white: 0.96))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    HStack {
                        Text("Peran Kamu")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(isParent ? "Orang Tua (Pemberi Data)" : "Anak (Pemantau)")
                            .font(.subheadline.bold())
                    }
                    .padding()
                    .background(Color(white: 0.96))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)

                Spacer()

                Button(role: .destructive) {
                    Task {
                        await syncViewModel.disconnect()
                        showDetailSheet = false
                    }
                } label: {
                    Text("Putuskan Hubungan")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.12))
                        .foregroundStyle(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .navigationTitle("Detail Akses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Tutup") { showDetailSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func triggerShare() {
        Task {
            isSharing = true
            if let url = await syncViewModel.requestShareLink() {
                let msg = isParent
                    ? "Halo! Ini link untuk memantau data kesehatanku di Arterious:\n\(url.absoluteString)"
                    : "Halo! Ayo hubungkan data kesehatan kamu di Arterious agar aku bisa memantau kondisimu:\n\(url.absoluteString)"
                ShareSheetHelper.share(url: url, customMessage: msg)
            } else if syncViewModel.errorMessage != nil {
                showErrorAlert = true
            }
            isSharing = false
        }
    }
}

#Preview {
    AksesView(syncViewModel: SyncViewModel())
}

