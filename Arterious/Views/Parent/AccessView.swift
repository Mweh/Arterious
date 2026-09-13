import SwiftUI
import CloudKit

/// The "Akses" tab screen with edit mode, delete confirmation modal, and personal details navigation.
struct AccessView: View {

    @Environment(SyncViewModel.self) private var syncViewModel
    @AppStorage("userRole") private var userRole: String = UserRole.parent.rawValue

    @State private var isEditMode: Bool = false
    @State private var showingDeleteConfirmationAlert: Bool = false
    @State private var itemToDelete: String = ""

    @State private var showingShareDataView: Bool = false
    @State private var showingChildConnectSheet: Bool = false
    @State private var showingShareSheet: Bool = false
    @State private var showingManualPasteSheet: Bool = false
    @State private var manualPastedText: String = ""
    @State private var navigationPath = NavigationPath()

    private var isConnected: Bool {
        syncViewModel.syncState.status == .accepted && syncViewModel.syncState.inviteCode != nil && !syncViewModel.syncState.inviteCode!.isEmpty && (syncViewModel.syncState.partnerName != nil || !syncViewModel.parentName.isEmpty)
    }

    private var partnerDisplayName: String {
        if !syncViewModel.parentName.isEmpty {
            return syncViewModel.parentName
        }
        if let partner = syncViewModel.syncState.partnerName, !partner.isEmpty {
            return partner
        }
        return userRole == UserRole.parent.rawValue ? "Anak" : "Orang Tua"
    }

    private var childInvitationMessage: String {
        let childName = !syncViewModel.userDisplayName.isEmpty ? syncViewModel.userDisplayName : (UIDevice.current.name.isEmpty ? "Anak" : UIDevice.current.name)
        let encodedName = childName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? childName
        return "arterious://ask-parent?name=\(encodedName)"
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                AppColor.backgroundPrimary.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {

                        if !isConnected {
                            emptyStateView
                        } else {
                            connectedAccountsCard
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.sm)
                    .padding(.bottom, AppSpacing.xxl)
                }
            }
            .navigationTitle("Akses")
            .toolbar {
                if isConnected {
                    if isEditMode {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Selesai") {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isEditMode = false
                                }
                            }
                            .fontWeight(.semibold)
                        }
                    } else {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isEditMode = true
                                }
                            } label: {
                                Image(systemName: "pencil")
                            }
                        }

                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                handlePlusButtonTapped()
                            } label: {
                                Image(systemName: "plus")
                            }
                        }
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            handlePlusButtonTapped()
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .toolbar(navigationPath.isEmpty ? .visible : .hidden, for: .tabBar)
            .navigationDestination(for: DetailDestination.self) { destination in
                switch destination {
                case .heartRate: HeartRateDetailView()
                case .sleep: SleepDetailView()
                case .activity: ActivityDetailView()
                case .llmInsight: LLMInsightView()
                case .historicalInsight(let date): LLMInsightView(targetDate: date)
                case .personalDetails(let name): PersonalDetailsView(name: name)
                }
            }
            .refreshable {
                await syncViewModel.refreshIfNeeded()
            }
            .task {
                await syncViewModel.refreshIfNeeded()
            }
            .alert("Hapus Akses?", isPresented: $showingDeleteConfirmationAlert) {
                Button("Hapus", role: .destructive) {
                    handleDeleteAccess()
                }
                Button("Batal", role: .cancel) { }
            } message: {
                Text("Kontak ini tidak lagi dapat mengakses seluruh riwayat atau data kesehatan Anda.")
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
        }
    }

    // MARK: - Empty State

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

    // MARK: - Connected Accounts Card

    private var connectedAccountsCard: some View {
        VStack(spacing: 0) {
            accountRow(name: partnerDisplayName)

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
            Button {
                itemToDelete = name
                showingDeleteConfirmationAlert = true
            } label: {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.red)

                    Text(name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppColor.textPrimary)

                    Spacer()
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, 18)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            Button {
                navigationPath.append(DetailDestination.personalDetails(name: name))
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
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func handleDeleteAccess() {
        Task {
            await syncViewModel.disconnect()
            withAnimation(.easeInOut(duration: 0.2)) {
                isEditMode = false
            }
        }
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

// MARK: - Personal Details View ("Rincian")

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
                VStack(spacing: 0) {
                    detailRow(label: "Nama", value: name.isEmpty ? "Orang Tua" : name)
                    Divider().padding(.horizontal, AppSpacing.lg)
                    detailRow(label: "Gender", value: userProfile.gender != "-" ? userProfile.gender : "Laki-Laki")
                    Divider().padding(.horizontal, AppSpacing.lg)
                    detailRow(label: "Umur", value: userProfile.age != nil ? "\(userProfile.age!)" : "50")
                }
                .background(AppColor.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.r24))
                .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
                
                Spacer()
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.xl)
            }
            .navigationTitle("Rincian")
        }
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
