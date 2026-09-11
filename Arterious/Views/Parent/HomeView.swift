import SwiftUI

/// The Home screen for the parents flow matching the Figma designs.
struct HomeView: View {

    @Environment(SyncViewModel.self) private var syncViewModel
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = true
    @AppStorage("userRole") private var userRole: String = UserRole.parent.rawValue

    @State private var hasConnectedParent: Bool = false
    @State private var selectedParentName: String = "Orang Tua 1"
    @State private var showingShareSheet: Bool = false
    @State private var showingManualPasteSheet: Bool = false
    @State private var showingParentSelectorSheet: Bool = false
    @State private var manualPastedText: String = ""

    private let parentOptions = ["Orang Tua 1", "Orang Tua 2", "Ibu", "Ayah"]

    private var isActuallyConnected: Bool {
        if userRole == UserRole.parent.rawValue {
            return true
        }
        guard hasConnectedParent else { return false }
        return syncViewModel.syncState.status == .accepted && syncViewModel.healthRecord != nil
    }

    private var displayName: String {
        if userRole == UserRole.parent.rawValue {
            return "Data Saya"
        }
        return syncViewModel.parentName.isEmpty ? selectedParentName : syncViewModel.parentName
    }

    private var isUsingAIEngine: Bool {
        APIConfig.isConfigured && !syncViewModel.isUsingLocalRuleFallback
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
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    if !isActuallyConnected {
                        emptyStateCard
                    } else {
                        connectedDashboardContent
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xxl)
            }
            .background(AppColor.backgroundPrimary.ignoresSafeArea())
            .refreshable {
                await syncViewModel.refreshIfNeeded()
            }
            .task {
                await syncViewModel.refreshIfNeeded()
                syncViewModel.checkClipboardForInvitation()
            }
            .navigationTitle("Beranda")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    roleSwitcherMenu
                }

                ToolbarItem(placement: .topBarTrailing) {
                    toggleModeButton
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ActivityViewController(items: [childInvitationMessage])
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showingManualPasteSheet) {
                manualPasteSheet
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showingParentSelectorSheet) {
                parentSelectorSheet
                    .presentationDetents([.height(260), .fraction(0.35)])
                    .presentationDragIndicator(.visible)
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

    private var roleSwitcherMenu: some View {
        Menu {
            Button {
                let newRole = (userRole == UserRole.parent.rawValue) ? UserRole.child.rawValue : UserRole.parent.rawValue
                userRole = newRole
                Task {
                    await syncViewModel.switchRole(to: newRole == UserRole.parent.rawValue ? .parent : .child)
                }
            } label: {
                Label(
                    userRole == UserRole.parent.rawValue ? "Ganti ke Peran Anak" : "Ganti ke Peran Orang Tua",
                    systemImage: "arrow.triangle.2.circlepath"
                )
            }

            Button("Ulangi Onboarding", systemImage: "arrow.counterclockwise") {
                hasCompletedOnboarding = false
            }

            Divider()

            Text("Peran: \(userRole == UserRole.parent.rawValue ? "Orang Tua" : "Anak")")
        } label: {
            Image(systemName: "person.2.fill")
                .foregroundStyle(AppColor.actionBlue)
        }
    }

    // MARK: - Empty State Card (role-aware)

    private var emptyStateCard: some View {
        let isChild = userRole == UserRole.child.rawValue

        return VStack(spacing: AppSpacing.xxl) {
            HealthOrbitIllustrationView()
                .padding(.top, AppSpacing.xxl)

            VStack(spacing: AppSpacing.sm) {
                Text("Tetap dekat, meski berjauhan")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)
                    .multilineTextAlignment(.center)

                Text(isChild
                    ? "Pantau perubahan pola kesehatan dan aktivitas orang tua dari jauh, agar kamu tahu kapan waktunya mengecek kabar mereka"
                    : "Bagikan data kesehatanmu dengan anggota keluarga agar mereka bisa memantau kondisimu dari jauh"
                )
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .padding(.horizontal, AppSpacing.xxl)

            VStack(spacing: AppSpacing.sm) {
                Button {
                    showingShareSheet = true
                } label: {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .medium))

                        Text(isChild ? "Minta Kontak Membagikan Data" : "Kirim Undangan")
                            .font(AppTypography.buttonLabel)
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, 14)
                    .background(AppColor.actionBlue)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, AppSpacing.xxl)
            .padding(.bottom, AppSpacing.xxl)
        }
        .frame(maxWidth: .infinity)
        .background(AppColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.r32))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 3)
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

    // MARK: - Parent Selector Sheet

    private var parentSelectorSheet: some View {
        VStack(spacing: 0) {
            Text("Orang Tua")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.lg)

            VStack(spacing: 0) {
                Button {
                    selectedParentName = syncViewModel.parentName.isEmpty ? "Nama Ortu 1" : syncViewModel.parentName
                    showingParentSelectorSheet = false
                } label: {
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: selectedParentName != "Nama Ortu 2" ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundStyle(selectedParentName != "Nama Ortu 2" ? AppColor.actionBlue : Color(.systemGray4))

                        Text(syncViewModel.parentName.isEmpty ? "Nama Ortu 1" : syncViewModel.parentName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppColor.textPrimary)

                        Spacer()
                    }
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)

                Divider()

                Button {
                    selectedParentName = syncViewModel.secondaryParentName ?? "Nama Ortu 2"
                    showingParentSelectorSheet = false
                } label: {
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: selectedParentName == "Nama Ortu 2" ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundStyle(selectedParentName == "Nama Ortu 2" ? AppColor.actionBlue : Color(.systemGray4))

                        Text(syncViewModel.secondaryParentName ?? "Nama Ortu 2")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppColor.textPrimary)

                        Spacer()
                    }
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)

                Divider()
            }
            .padding(.horizontal, AppSpacing.lg)

            Spacer()
        }
        .background(AppColor.backgroundPrimary.ignoresSafeArea())
    }

    // MARK: - Connected Dashboard Content

    private var connectedDashboardContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            // Parent Selector Dropdown Menu
            HStack {
                Spacer()

                Button {
                    if userRole == UserRole.child.rawValue {
                        showingParentSelectorSheet = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(displayName)
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(AppColor.textPrimary)

                        if userRole == UserRole.child.rawValue {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(AppColor.textSecondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)

                Spacer()
            }

            // "Ringkasan Hari Ini" Blue Tinted Card
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Ringkasan Hari Ini")
                    .font(AppTypography.subheadlineRegular)
                    .foregroundStyle(AppColor.textSecondary)

                Text(syncViewModel.healthRecord?.summaryTitle ?? "Kondisi cukup stabil")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)
                    .padding(.top, 1)

                Text(syncViewModel.healthRecord?.summaryBody ?? "Pola tidur baik, detak jantung dalam rentang normal, dan aktivitas sedikit lebih baik dari biasanya.")
                    .font(AppTypography.bodyRegular)
                    .foregroundStyle(AppColor.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.Accent.blue12)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.r24))

            // Section "Data Hari Ini"
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Data Hari Ini")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)

                // 1. Detak Jantung / Heart Rate
                NavigationLink {
                    HeartRateDetailView()
                } label: {
                    HealthMetricSummaryCard(
                        iconName: "heart.fill",
                        iconColor: AppColor.Accent.red,
                        iconBgColor: AppColor.Accent.red12,
                        title: "Detak Jantung",
                        value: heartRateDisplayValue,
                        unit: "BPM",
                        subtitle: syncViewModel.healthRecord?.heartRateStatus ?? "Belum ada data",
                        dateString: syncViewModel.healthRecord?.displayDate ?? "Hari Ini",
                        chartValues: heartRateChartValues
                    )
                }
                .buttonStyle(.plain)

                // 2. Waktu Tidur / Sleep
                NavigationLink {
                    SleepDetailView()
                } label: {
                    HealthMetricSummaryCard(
                        iconName: "bed.double.fill",
                        iconColor: Color(red: 0.55, green: 0.45, blue: 0.9),
                        iconBgColor: Color(red: 0.55, green: 0.45, blue: 0.9).opacity(0.12),
                        title: "Waktu Tidur",
                        value: syncViewModel.healthRecord?.sleepFormatted ?? "-",
                        subtitle: syncViewModel.healthRecord?.sleepStatus ?? "Belum ada data",
                        dateString: syncViewModel.healthRecord?.displayDate ?? "Hari Ini",
                        chartValues: sleepChartValues
                    )
                }
                .buttonStyle(.plain)

                // 3. Langkah & Aktivitas / Steps
                NavigationLink {
                    ActivityDetailView()
                } label: {
                    HealthMetricSummaryCard(
                        iconName: "figure.walk",
                        iconColor: AppColor.Accent.green,
                        iconBgColor: AppColor.Accent.green12,
                        title: "Aktivitas",
                        value: syncViewModel.healthRecord?.stepFormatted ?? "-",
                        subtitle: syncViewModel.healthRecord?.activityStatus ?? "Belum ada data",
                        dateString: syncViewModel.healthRecord?.displayDate ?? "Hari Ini",
                        chartValues: stepChartValues
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var heartRateDisplayValue: String {
        if let hr = syncViewModel.healthRecord?.displayHeartRate {
            return "\(Int(hr))"
        }
        return "-"
    }

    private var heartRateChartValues: [CGFloat] {
        let pts = syncViewModel.healthRecord?.recentHeartRatePoints ?? []
        if pts.count >= 3 {
            let maxVal = pts.max() ?? 1
            return pts.map { CGFloat(maxVal > 0 ? $0 / maxVal : 0.5) }
        }
        return [0.4, 0.7, 0.5, 0.9, 0.8, 0.6]
    }

    private var sleepChartValues: [CGFloat] {
        let pts = syncViewModel.healthRecord?.recentSleepPoints ?? []
        if pts.count >= 3 {
            let maxVal = pts.max() ?? 1
            return pts.map { CGFloat(maxVal > 0 ? $0 / maxVal : 0.5) }
        }
        return [0.3, 0.7, 0.4, 0.9, 0.8, 0.5]
    }

    private var stepChartValues: [CGFloat] {
        let pts = syncViewModel.healthRecord?.recentStepPoints ?? []
        if pts.count >= 3 {
            let maxVal = pts.max() ?? 1
            return pts.map { CGFloat(maxVal > 0 ? $0 / maxVal : 0.5) }
        }
        return [0.4, 0.6, 0.5, 0.9, 0.8, 0.3]
    }

    // MARK: - Mode Switcher

    private var toggleModeButton: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                hasConnectedParent.toggle()
            }
        } label: {
            Image(systemName: isActuallyConnected ? "eye.fill" : "eye.slash.fill")
                .font(.system(size: 13))
                .foregroundStyle(AppColor.textSecondary)
                .frame(width: 30, height: 30)
                .background(Color(.systemGray6))
                .clipShape(Circle())
        }
    }

    private func badgeColor(for badge: String) -> Color {
        let lower = badge.lowercased()
        if lower.contains("menurun") || lower.contains("penurunan") {
            return .red
        }
        if lower.contains("membaik") || lower.contains("meningkat") {
            return .green
        }
        return AppColor.actionBlue
    }
}

#Preview {
    HomeView()
        .environment(SyncViewModel())
}
