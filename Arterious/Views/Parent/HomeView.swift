import SwiftUI

/// The Home screen for the parents flow matching the Figma designs.
struct HomeView: View {

    @Environment(SyncViewModel.self) private var syncViewModel
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = true
    @AppStorage("userRole") private var userRole: String = UserRole.parent.rawValue

    @State private var hasConnectedParent: Bool = true
    @State private var selectedParentName: String = "Parent 1"
    @State private var showingShareSheet: Bool = false
    @State private var showingManualPasteSheet: Bool = false
    @State private var manualPastedText: String = ""

    private var isActuallyConnected: Bool {
        if userRole == UserRole.parent.rawValue {
            return true
        }
        return syncViewModel.syncState.status == .accepted && hasConnectedParent
    }

    private var displayName: String {
        if userRole == UserRole.parent.rawValue {
            return "Data Saya"
        }
        return syncViewModel.parentName.isEmpty ? selectedParentName : syncViewModel.parentName
    }

    private var childInvitationMessage: String {
        let childName = UIDevice.current.name.isEmpty ? "Anak" : UIDevice.current.name
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

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        if !isActuallyConnected {
                            // Empty state: Requesting parent to share data
                            emptyStateCard
                        } else {
                            // Active parent wellness monitoring dashboard
                            connectedDashboardContent
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.sm)
                    .padding(.bottom, AppSpacing.xxl)
                }
            }
            .refreshable {
                await syncViewModel.refreshIfNeeded()
            }
            .task {
                await syncViewModel.refreshIfNeeded()
                syncViewModel.checkClipboardForInvitation()
            }
            .navigationTitle("Home")
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

    // MARK: - Empty State Card

    private var emptyStateCard: some View {
        VStack(spacing: AppSpacing.lg) {
            HealthOrbitIllustrationView()
                .padding(.top, AppSpacing.md)

            VStack(spacing: AppSpacing.xs) {
                Text("Stay close, even from afar")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Monitor pola kesehatan dan aktivitas orang tua dari jarak jauh, agar Anda tahu kapan harus menyapa mereka.")
                    .font(AppTypography.subheadlineRegular)
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, AppSpacing.sm)
            }

            VStack(spacing: AppSpacing.sm) {
                // Button 1: Share sheet
                Button {
                    showingShareSheet = true
                } label: {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .medium))

                        Text("Bagikan Tautan")
                            .font(AppTypography.buttonLabel)
                    }
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppColor.actionBlue)
                    .clipShape(Capsule())
                }

                // Button 2: Paste link from parent
                Button {
                    handlePasteFromParent()
                } label: {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 14, weight: .medium))

                        Text("Tempel Tautan dari Orang Tua")
                            .font(AppTypography.captionRegular)
                    }
                    .foregroundStyle(AppColor.textSecondary)
                    .padding(.vertical, 6)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.md)
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

    // MARK: - Connected Dashboard Content

    private var connectedDashboardContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            // Parent Selector Dropdown Menu
            HStack {
                Spacer()

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

                Spacer()
            }

            // "Today's Summary" Blue Tinted Card with direct access to Caregiver AI Insights
            NavigationLink {
                LLMInsightView()
            } label: {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    HStack {
                        Text("Today's Summary")
                            .font(AppTypography.subheadlineRegular)
                            .foregroundStyle(AppColor.textSecondary)

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 13, weight: .semibold))
                            Text("AI Insight")
                                .font(.system(size: 12, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(AppColor.actionBlue)
                    }

                    Text(syncViewModel.healthRecord?.summaryTitle ?? "Belum ada data hari ini")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppColor.textPrimary)
                        .padding(.top, 1)

                    Text(syncViewModel.healthRecord?.summaryBody ?? "Data detak jantung, tidur, dan langkah belum tercatat di Apple Health hari ini.")
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
            }
            .buttonStyle(.plain)

            // Section "Today's Data"
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Today's Data")
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
}

#Preview {
    HomeView()
        .environment(SyncViewModel())
}
