import SwiftUI
import CloudKit

/// The "Access" tab screen for managing shared contacts and invitations without phonebook access.
/// Active access only displays when a connection is actually accepted and supports native slide-to-delete.
struct AccessView: View {

    @Environment(SyncViewModel.self) private var syncViewModel
    @AppStorage("userRole") private var userRole: String = UserRole.parent.rawValue

    @State private var showingShareDataView = false
    @State private var showingDisconnectConfirmation = false
    @State private var partnerNameToDisconnect = ""

    private var isChildActuallyConnected: Bool {
        syncViewModel.syncState.status == .accepted && syncViewModel.syncState.partnerName != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    // Main Access Card
                    mainAccessCard

                    // Active Shared Members (Only shown when connection is actually accepted)
                    if syncViewModel.syncState.status == .accepted, let partner = syncViewModel.syncState.partnerName {
                        sharedMembersSection(partner: partner)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xxl)
            }
            .refreshable {
                await syncViewModel.refreshIfNeeded()
            }
            .task {
                await syncViewModel.refreshIfNeeded()
            }
            .background(AppColor.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Access")
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
            .confirmationDialog(
                "Putuskan Akses?",
                isPresented: $showingDisconnectConfirmation,
                titleVisibility: .visible
            ) {
                Button("Putuskan Koneksi", role: .destructive) {
                    Task {
                        await syncViewModel.disconnect()
                    }
                }
                Button("Batal", role: .cancel) { }
            } message: {
                Text("Data kesehatan Anda tidak akan lagi dibagikan dengan \(partnerNameToDisconnect). Anggota keluarga tidak akan dapat memantau kondisi Anda lagi.")
            }
        }
    }

    // MARK: - Main Access Card

    private var mainAccessCard: some View {
        VStack(spacing: AppSpacing.lg) {
            HealthOrbitIllustrationView()
                .padding(.top, AppSpacing.md)

            VStack(spacing: AppSpacing.xs) {
                Text("Stay close, even from afar")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Share your wellness patterns and activity so your loved ones know your condition.")
                    .font(AppTypography.subheadlineRegular)
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, AppSpacing.sm)
            }

            Button {
                showingShareDataView = true
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 16, weight: .medium))

                    Text("Send Invitation")
                        .font(AppTypography.buttonLabel)
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, AppSpacing.xl)
                .padding(.vertical, 14)
                .background(AppColor.actionBlue)
                .clipShape(Capsule())
            }
            .padding(.bottom, AppSpacing.lg)
        }
        .frame(maxWidth: .infinity)
        .background(AppColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.r32))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 3)
    }

    // MARK: - Shared Members Section

    @ViewBuilder
    private func sharedMembersSection(partner: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Active Access")
                .font(AppTypography.headline)
                .foregroundStyle(AppColor.textPrimary)

            SwipeableMemberRow(
                name: partner,
                initial: String(partner.prefix(1)).uppercased()
            ) {
                partnerNameToDisconnect = partner
                showingDisconnectConfirmation = true
            }
        }
        .padding(.top, AppSpacing.sm)
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }
}

// MARK: - Swipeable Active Member Row with Native Slide-to-Delete

struct SwipeableMemberRow: View {
    let name: String
    let initial: String
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var isSwiped: Bool = false

    var body: some View {
        ZStack(alignment: .trailing) {
            // Background: Red Delete Action Button
            Button(role: .destructive, action: onDelete) {
                VStack(spacing: 4) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 20))
                    Text("Putuskan")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Color.white)
                .frame(width: 86, height: 72)
                .background(Color.red)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.r24))
            }

            // Foreground: Member Info Card
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    Circle()
                        .fill(AppColor.Gray.gray100)
                        .frame(width: 44, height: 44)

                    Text(initial)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(AppTypography.bodySemibold)
                        .foregroundStyle(AppColor.textPrimary)

                    Text("Receiving wellness updates")
                        .font(AppTypography.captionRegular)
                        .foregroundStyle(AppColor.Accent.green)
                }

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppColor.Accent.green)
            }
            .padding(AppSpacing.md)
            .frame(height: 72)
            .background(AppColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.r24))
            .offset(x: offset)
            .gesture(
                DragGesture(minimumDistance: 15)
                    .onChanged { gesture in
                        let translation = gesture.translation.width
                        if translation < 0 {
                            offset = isSwiped ? max(translation - 86, -110) : max(translation, -110)
                        } else if isSwiped {
                            offset = min(translation - 86, 0)
                        }
                    }
                    .onEnded { gesture in
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            if gesture.translation.width < -40 {
                                offset = -86
                                isSwiped = true
                            } else {
                                offset = 0
                                isSwiped = false
                            }
                        }
                    }
            )
        }
    }
}

#Preview {
    AccessView()
        .environment(SyncViewModel())
}
