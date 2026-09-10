import SwiftUI
import CloudKit

/// The "Akses" tab screen matching Figma designs with edit mode, delete confirmation modal, and personal details navigation.
struct AccessView: View {

    @Environment(SyncViewModel.self) private var syncViewModel
    @AppStorage("userRole") private var userRole: String = UserRole.parent.rawValue

    @State private var isEditMode: Bool = false
    @State private var showingDeleteConfirmationModal: Bool = false
    @State private var itemToDelete: String = ""

    @State private var showingShareDataView: Bool = false
    @State private var showingChildConnectSheet: Bool = false
    @State private var showingShareSheet: Bool = false
    @State private var showingManualPasteSheet: Bool = false
    @State private var manualPastedText: String = ""

    private var isConnected: Bool {
        syncViewModel.syncState.status == .accepted && (syncViewModel.syncState.partnerName != nil || !syncViewModel.parentName.isEmpty)
    }

    private var partnerDisplayName: String {
        if !syncViewModel.parentName.isEmpty {
            return syncViewModel.parentName
        }
        if let partner = syncViewModel.syncState.partnerName, !partner.isEmpty {
            return partner
        }
        return userRole == UserRole.parent.rawValue ? "Anak" : "Nama Ortu 1"
    }

    private var childInvitationMessage: String {
        let childName = !syncViewModel.userDisplayName.isEmpty ? syncViewModel.userDisplayName : (UIDevice.current.name.isEmpty ? "Anak" : UIDevice.current.name)
        let encodedName = childName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? childName
        return """
        Halo! Mari terhubung di aplikasi Arterious.
        1. Buka tautan ini di iPhone:
        arterious://ask-parent?name=\(encodedName)

        2. Atau buka Arterious dan masuk sebagai Orang Tua untuk mulai membagikan data kesehatan.
        """
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.backgroundPrimary.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        if !isConnected {
                            // Profile / Empty State (Figma Screenshot 3 Left)
                            emptyStateView
                        } else {
                            // Profile / Default & Edit Mode (Figma Screenshot 1)
                            connectedAccountsCard
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.sm)
                    .padding(.bottom, AppSpacing.xxl)
                }

                // Delete Confirmation Modal (Figma Screenshot 1 Right)
                if showingDeleteConfirmationModal {
                    deleteConfirmationModal
                }
            }
            .navigationTitle("Akses")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    toolbarActionButtons
                }
            }
            .refreshable {
                await syncViewModel.refreshIfNeeded()
                syncViewModel.checkClipboardForInvitation()
            }
            .task {
                await syncViewModel.refreshIfNeeded()
                syncViewModel.checkClipboardForInvitation()
            }
            .sheet(isPresented: Binding(
                get: { showingShareDataView || syncViewModel.shouldShowParentShareFlow },
                set: { newValue in
                    showingShareDataView = newValue
                    syncViewModel.shouldShowParentShareFlow = newValue
                }
            )) {
                ShareDataView(
                    contactName: syncViewModel.shouldShowParentShareFlow ? syncViewModel.pendingParentShareName : "Keluarga",
                    contactPhone: "",
                    onBack: {
                        showingShareDataView = false
                        syncViewModel.shouldShowParentShareFlow = false
                    },
                    onDismiss: {
                        showingShareDataView = false
                        syncViewModel.shouldShowParentShareFlow = false
                    },
                    onConfirm: {
                        showingShareDataView = false
                        syncViewModel.shouldShowParentShareFlow = false
                    }
                )
                .presentationDetents([.fraction(0.9), .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingShareSheet) {
                ActivityViewController(items: [childInvitationMessage])
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showingManualPasteSheet) {
                manualPasteSheet
                    .presentationDetents([.medium])
            }
            .confirmationDialog(
                "Hubungkan Akun",
                isPresented: $showingChildConnectSheet,
                titleVisibility: .visible
            ) {
                Button("Minta Akses dari Orang Tua") {
                    showingShareSheet = true
                }
                Button("Tempel Tautan dari Orang Tua") {
                    handlePasteFromParent()
                }
                Button("Batal", role: .cancel) { }
            } message: {
                Text("Pilih cara untuk menghubungkan akun dengan orang tua:")
            }
            .alert("Tautan Undangan Terdeteksi", isPresented: Bindable(syncViewModel).showDetectedClipboardPrompt) {
                Button("Hubungkan") {
                    if let url = syncViewModel.detectedClipboardURL {
                        Task {
                            await syncViewModel.handleIncomingShareURL(url: url)
                        }
                    }
                }
                Button("Abaikan", role: .cancel) { }
            } message: {
                Text("Ditemukan tautan berbagi data kesehatan dari papan klip. Ingin langsung menghubungkan dan memantau?")
            }
        }
    }

    // MARK: - Toolbar Buttons

    @ViewBuilder
    private var toolbarActionButtons: some View {
        if isConnected {
            if isEditMode {
                // In Edit Mode: Checkmark (✓) button to finish editing
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditMode = false
                    }
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppColor.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
            } else {
                HStack(spacing: AppSpacing.sm) {
                    // Plus (+) button
                    Button {
                        handlePlusButtonTapped()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppColor.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                    }

                    // Edit (pencil) button
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isEditMode = true
                        }
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppColor.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                    }
                }
            }
        } else {
            // When empty, show Plus (+) button
            Button {
                handlePlusButtonTapped()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColor.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Profile / Empty State

    private var emptyStateView: some View {
        VStack(spacing: AppSpacing.xs) {
            Text("Belum Ada Akun Terhubung")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(.systemGray))
                .multilineTextAlignment(.center)

            Text("Ketuk tombol (+) di atas atau kembali ke Beranda untuk mulai menghubungkan akun.")
                .font(AppTypography.subheadlineRegular)
                .foregroundStyle(Color(.systemGray2))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, AppSpacing.xl)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 160)
    }

    // MARK: - Connected Accounts Card (Matching Figma Screenshot 1)

    private var connectedAccountsCard: some View {
        VStack(spacing: 0) {
            // Row 1: Active Connected Account
            accountRow(name: partnerDisplayName)

            // Optional Row 2: Secondary Parent
            if let sec = syncViewModel.secondaryParentName {
                Divider()
                    .padding(.horizontal, AppSpacing.lg)

                accountRow(name: sec)
            }
        }
        .background(AppColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.r24))
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
    }

    @ViewBuilder
    private func accountRow(name: String) -> some View {
        if isEditMode {
            // Edit Mode: Tapping shows the Delete Confirmation Modal
            Button {
                itemToDelete = name
                withAnimation(.easeInOut(duration: 0.2)) {
                    showingDeleteConfirmationModal = true
                }
            } label: {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.red)

                    Text(name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppColor.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(.systemGray3))
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, 18)
            }
            .buttonStyle(.plain)
        } else {
            // Normal Mode: Tapping navigates to "Rincian" (Figma Screenshot 2)
            NavigationLink {
                PersonalDetailsView(name: name)
            } label: {
                HStack {
                    Text(name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppColor.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(.systemGray3))
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, 18)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Delete Confirmation Modal (Figma Screenshot 1 Right)

    private var deleteConfirmationModal: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingDeleteConfirmationModal = false
                    }
                }

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Hapus Akses?")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)

                Text("Kontak ini tidak lagi dapat mengakses seluruh riwayat atau data kesehatan kamu.")
                    .font(AppTypography.subheadlineRegular)
                    .foregroundStyle(AppColor.textSecondary)
                    .lineSpacing(2)
                    .padding(.bottom, AppSpacing.sm)

                HStack(spacing: AppSpacing.md) {
                    // Ya (Destructive delete)
                    Button {
                        Task {
                            await syncViewModel.disconnect()
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showingDeleteConfirmationModal = false
                                isEditMode = false
                            }
                        }
                    } label: {
                        Text("Ya")
                            .font(AppTypography.buttonLabel)
                            .foregroundStyle(AppColor.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                    }

                    // Tidak (Cancel)
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingDeleteConfirmationModal = false
                        }
                    } label: {
                        Text("Tidak")
                            .font(AppTypography.buttonLabel)
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppColor.actionBlue)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(AppSpacing.lg)
            .background(AppColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.r24))
            .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 8)
            .padding(.horizontal, AppSpacing.xl)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .zIndex(10)
    }

    // MARK: - Actions

    private func handlePlusButtonTapped() {
        if userRole == UserRole.parent.rawValue {
            showingShareDataView = true
        } else {
            showingChildConnectSheet = true
        }
    }

    private func handlePasteFromParent() {
        if let pasteboardString = UIPasteboard.general.string,
           pasteboardString.contains("icloud.com/share") || pasteboardString.contains("arterious://") {
            Task {
                await syncViewModel.handlePastedLink(pasteboardString)
            }
        } else {
            showingManualPasteSheet = true
        }
    }

    private var manualPasteSheet: some View {
        VStack(spacing: AppSpacing.md) {
            Text("Tempel Tautan Undangan")
                .font(AppTypography.headline)
                .foregroundStyle(AppColor.textPrimary)
                .padding(.top, AppSpacing.md)

            Text("Salin pesan atau tautan dari orang tua di WhatsApp, lalu tempel di bawah:")
                .font(AppTypography.subheadlineRegular)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.md)

            TextField("Tempel tautan arterious:// atau icloud.com...", text: $manualPastedText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, AppSpacing.md)

            Button {
                let textToProcess = manualPastedText.isEmpty ? (UIPasteboard.general.string ?? "") : manualPastedText
                showingManualPasteSheet = false
                Task {
                    await syncViewModel.handlePastedLink(textToProcess)
                }
            } label: {
                Text("Hubungkan")
                    .font(AppTypography.buttonLabel)
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppColor.actionBlue)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.xs)

            Spacer()
        }
        .padding()
        .background(AppColor.backgroundPrimary.ignoresSafeArea())
    }
}

// MARK: - Personal Details View (Figma Screenshot 2: "Rincian")

struct PersonalDetailsView: View {
    let name: String
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncViewModel.self) private var syncViewModel

    private var userProfile: (gender: String, age: Int?) {
        HealthKitManager.shared.fetchUserProfile()
    }

    var body: some View {
        ZStack {
            AppColor.backgroundPrimary.ignoresSafeArea()

            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                // Custom Back Button
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppColor.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
                .padding(.top, AppSpacing.sm)

                Text("Rincian")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)

                // Grouped Card
                VStack(spacing: 0) {
                    detailRow(label: "Nama", value: name.isEmpty ? "Actifed" : name)
                    Divider().padding(.horizontal, AppSpacing.lg)
                    detailRow(label: "Gender", value: userProfile.gender != "-" ? userProfile.gender : "Laki-Laki")
                    Divider().padding(.horizontal, AppSpacing.lg)
                    detailRow(label: "Umur", value: userProfile.age != nil ? "\(userProfile.age!)" : "50")
                }
                .background(AppColor.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.r24))
                .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)

                Spacer()
            }
            .padding(.horizontal, AppSpacing.lg)
        }
        .navigationBarBackButtonHidden(true)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(AppColor.textPrimary)

            Spacer()

            Text(value)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(AppColor.textPrimary)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, 18)
    }
}

#Preview {
    AccessView()
        .environment(SyncViewModel())
}
