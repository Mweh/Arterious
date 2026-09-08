import SwiftUI
import CloudKit

/// View demonstrating CloudKit Parent-to-Child daily health schema and sharing flow.
struct HealthMetricView: View {

    @State private var viewModel = HealthViewModel()
    @State private var showingShareSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Role Switcher
                    rolePicker

                    // Role-Specific Action Section
                    if viewModel.isParentRole {
                        parentActionSection
                    } else {
                        childActionSection
                    }

                    // Error Banner
                    if let errorMessage = viewModel.errorMessage {
                        errorBanner(message: errorMessage)
                    }

                    // Records List
                    recordsSection
                }
                .padding(AppSpacing.lg)
            }
            .background(AppColor.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("CloudKit Health")
            .toolbar {
                if viewModel.isLoading {
                    ToolbarItem(placement: .topBarTrailing) {
                        ProgressView()
                    }
                }
            }
            .task {
                await viewModel.refreshCurrentRole()
            }
            .sheet(isPresented: $showingShareSheet) {
                if let share = viewModel.activeShare {
                    CloudSharingView(share: share, container: .default())
                }
            }
        }
    }

    // MARK: - Role Picker

    private var rolePicker: some View {
        Picker("Role", selection: $viewModel.isParentRole) {
            Text("Parent (Owner)").tag(true)
            Text("Child (Viewer)").tag(false)
        }
        .pickerStyle(.segmented)
        .onChange(of: viewModel.isParentRole) { _, _ in
            Task {
                await viewModel.refreshCurrentRole()
            }
        }
    }

    // MARK: - Parent Action Section

    private var parentActionSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Parent's Daily Health Data")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColor.textPrimary)

                Text("Data is stored in your Private Database in a custom CloudKit zone ready for sharing.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.textSecondary)

                VStack(spacing: AppSpacing.sm) {
                    AppButton(
                        title: "Save Today's Health (72 bpm, 7.3k steps, 7.2h)",
                        icon: "heart.fill",
                        isLoading: viewModel.isLoading
                    ) {
                        Task {
                            await viewModel.saveSampleDailyHealth(
                                heartRate: 72.0,
                                steps: 7342,
                                sleepDuration: 7.2
                            )
                        }
                    }

                    AppButton(
                        title: "Invite Child (Create CKShare)",
                        icon: "person.crop.circle.badge.plus",
                        style: .secondary,
                        isLoading: viewModel.isLoading
                    ) {
                        Task {
                            await viewModel.createShareForChild()
                            if viewModel.activeShare != nil {
                                showingShareSheet = true
                            }
                        }
                    }

                    AppButton(
                        title: "Fetch Private Records",
                        icon: "arrow.clockwise",
                        style: .secondary,
                        isLoading: viewModel.isLoading
                    ) {
                        Task {
                            await viewModel.fetchParentRecords()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Child Action Section

    private var childActionSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Child's Shared View")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColor.textPrimary)

                Text("Reads the parent's health summaries through CloudKit's Shared Database (read-only).")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.textSecondary)

                AppButton(
                    title: "Fetch Parent's Shared Data",
                    icon: "arrow.clockwise.icloud",
                    isLoading: viewModel.isLoading
                ) {
                    Task {
                        await viewModel.fetchChildSharedRecords()
                    }
                }
            }
        }
    }

    // MARK: - Records Section

    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(
                title: viewModel.isParentRole ? "My Daily Records" : "Parent's Shared Records"
            )

            let records = viewModel.isParentRole ? viewModel.dailyHealthRecords : viewModel.sharedHealthRecords

            if viewModel.isLoading && records.isEmpty {
                LoadingView(message: "Syncing with CloudKit…")
            } else if records.isEmpty {
                EmptyStateView(
                    icon: viewModel.isParentRole ? "heart.text.square" : "person.2.slash",
                    title: viewModel.isParentRole ? "No Records Yet" : "No Shared Records",
                    message: viewModel.isParentRole
                        ? "Tap 'Save Today's Health' to create your first DailyHealth record."
                        : "No shared records found. Ensure the parent created a share and accepted the invitation."
                )
            } else {
                LazyVStack(spacing: AppSpacing.md) {
                    ForEach(records) { record in
                        dailyHealthCard(for: record)
                    }
                }
            }
        }
    }

    // MARK: - Daily Health Card

    private func dailyHealthCard(for record: DailyHealth) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    Text(record.date, format: .dateTime.month().day().year())
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColor.textPrimary)

                    Spacer()

                    Image(systemName: viewModel.isParentRole ? "lock.fill" : "person.2.fill")
                        .font(.caption)
                        .foregroundStyle(AppColor.textSecondary)
                }

                Divider()

                HStack(spacing: AppSpacing.lg) {
                    metricColumn(
                        label: "Heart Rate",
                        value: record.formattedHeartRate,
                        icon: "heart.fill",
                        color: AppColor.accent
                    )

                    metricColumn(
                        label: "Steps",
                        value: record.formattedSteps,
                        icon: "figure.walk",
                        color: AppColor.info
                    )

                    metricColumn(
                        label: "Sleep",
                        value: record.formattedSleepDuration,
                        icon: "moon.stars.fill",
                        color: AppColor.healthy
                    )
                }
            }
        }
    }

    private func metricColumn(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(label)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.textSecondary)
            }

            Text(value)
                .font(AppTypography.body.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Error Banner

    private func errorBanner(message: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppColor.caution)

            Text(message)
                .font(AppTypography.caption)
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.leading)

            Spacer()
        }
        .padding(AppSpacing.md)
        .background(AppColor.cautionBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
    }
}

// MARK: - UICloudSharingController Representable

struct CloudSharingView: UIViewControllerRepresentable {

    let share: CKShare
    let container: CKContainer

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.availablePermissions = [.allowReadOnly]
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}
}

#Preview {
    HealthMetricView()
}
