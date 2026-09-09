import SwiftUI
import CloudKit

/// View tab Akses yang mengelola perizinan dan koneksi data kesehatan (Native Apple CKShare: One-Way Read-Only).
/// Bawaan resmi Apple seperti Health Sharing & Notes: tanpa kode, menggunakan UICloudSharingController.
struct AksesView: View {
    @Bindable var syncViewModel: SyncViewModel
    @State private var isSharing: Bool = false
    @State private var showDetailSheet: Bool = false
    @State private var showCloudShareSheet: Bool = false
    @State private var isEditing: Bool = false
    @State private var shareText: String? = nil
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
                        accessContentCard
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
                        // Native Share Button for Parent
                        if isParent {
                            Button {
                                triggerNativeShare()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 38, height: 38)
                                        .shadow(color: Color.black.opacity(0.06), radius: 6, y: 2)

                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.primary)
                                }
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
            // Detail Sheet
            .sheet(isPresented: $showDetailSheet) {
                partnerDetailSheet
            }
            // Native Apple UICloudSharingController Sheet
            .sheet(isPresented: $showCloudShareSheet) {
                if let share = syncViewModel.nativeShare {
                    CloudSharingView(
                        share: share,
                        container: syncViewModel.cloudKitContainer,
                        onDismiss: { showCloudShareSheet = false },
                        onStoppedSharing: {
                            Task { await syncViewModel.disconnect() }
                        }
                    )
                    .ignoresSafeArea()
                }
            }
            // Text Share Sheet (for child reminder message)
            .sheet(isPresented: Binding(
                get: { shareText != nil },
                set: { if !$0 { shareText = nil } }
            )) {
                if let shareText {
                    ActivityViewController(items: [shareText])
                        .presentationDetents([.medium, .large])
                }
            }
            .alert("Peringatan Sinkronisasi", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {
                    syncViewModel.errorMessage = nil
                }
            } message: {
                Text(syncViewModel.errorMessage ?? "Gagal terhubung ke iCloud. Pastikan kamu sudah login ke iCloud di Settings iPhone.")
            }
            .onChange(of: syncViewModel.errorMessage) { _, newMsg in
                if newMsg != nil {
                    showErrorAlert = true
                }
            }
        }
    }

    // MARK: - Access Content Card

    @ViewBuilder
    private var accessContentCard: some View {
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

    // MARK: - Not Paired State Card (.none)

    private var notPairedStateCard: some View {
        VStack(spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: isParent ? "heart.text.square.fill" : "person.crop.circle.badge.plus")
                    .font(.system(size: 32))
                    .foregroundStyle(isParent ? .red : .blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text(isParent ? "Bagikan Data ke Anak" : "Menunggu Akses Orang Tua")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)

                    Text(isParent
                         ? "Bagikan data detak jantung, tidur, dan aktivitas harian kamu agar anak dapat memantau kesehatan kamu secara aman."
                         : "Seperti Apple Health, orang tua kamu perlu membagikan data kesehatannya terlebih dahulu dari aplikasi Arterious di iPhone mereka.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }

            if isParent {
                // Orang Tua: Tombol utama memicu Apple native CloudKit Sharing
                Button {
                    triggerNativeShare()
                } label: {
                    HStack(spacing: 8) {
                        if isSharing || syncViewModel.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .bold))
                        }
                        Text("Bagikan Data ke Anak")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .shadow(color: Color.blue.opacity(0.25), radius: 8, y: 4)
                }
                .disabled(isSharing || syncViewModel.isLoading)
            } else {
                // Anak: Tombol mengirim pengingat ke Orang Tua
                Button {
                    triggerChildReminder()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("Kirim Pesan ke Orang Tua")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .shadow(color: Color.blue.opacity(0.25), radius: 8, y: 4)
                }
            }
        }
        .padding(20)
    }

    // MARK: - Pending State Card (.pending)

    private var pendingStateCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(0.9)

                VStack(alignment: .leading, spacing: 3) {
                    Text(isParent ? "Undangan Aktif" : "Menunggu Konfirmasi")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(isParent
                         ? "Menunggu anak membuka tautan iCloud di iPhone mereka untuk mulai memantau."
                         : "Menunggu orang tua menyetujui pemantauan data kesehatan.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                }
                Spacer()
            }

            if isParent {
                Button {
                    triggerNativeShare()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Kelola / Bagikan Ulang Undangan")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
            }

            Divider().padding(.vertical, 2)

            HStack {
                Spacer()
                Button {
                    Task { await syncViewModel.disconnect() }
                } label: {
                    Text("Batalkan Undangan")
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
                        Text("Terhubung via iCloud Sharing")
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

                    HStack {
                        Text("Izin Akses")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Hanya Lihat (Read-Only)")
                            .font(.subheadline.bold())
                            .foregroundStyle(.blue)
                    }
                    .padding()
                    .background(Color(white: 0.96))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)

                Spacer()

                if isParent && syncViewModel.nativeShare != nil {
                    Button {
                        showDetailSheet = false
                        showCloudShareSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "person.crop.circle.badge.plus")
                            Text("Kelola Peserta Berbagi")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 24)
                }

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

    // MARK: - Actions

    private func triggerNativeShare() {
        Task {
            isSharing = true
            defer { isSharing = false }
            if let _ = await syncViewModel.requestNativeShare() {
                showCloudShareSheet = true
            } else if syncViewModel.errorMessage != nil {
                showErrorAlert = true
            }
        }
    }

    private func triggerChildReminder() {
        shareText = "Halo Pa/Ma, tolong buka aplikasi Arterious di iPhone dan ketuk 'Bagikan Data ke Anak' di tab Akses agar aku bisa memantau kesehatan Papa/Mama ya!"
    }
}

#Preview {
    AksesView(syncViewModel: SyncViewModel())
}
