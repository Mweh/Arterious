import SwiftUI
import Contacts

/// The "Access" tab screen for managing shared contacts and invitations.
struct AccessView: View {

    @State private var showingAddAccess = false
    @State private var sharedContacts: [ContactItem] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    // Main Access Card
                    mainAccessCard

                    // Active Shared Members
                    if !sharedContacts.isEmpty {
                        sharedMembersSection
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xxl)
            }
            .background(AppColor.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Access")
            .sheet(isPresented: $showingAddAccess) {
                AddAccessSheet { newContact in
                    if !sharedContacts.contains(where: { $0.id == newContact.id }) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            sharedContacts.append(newContact)
                        }
                    }
                }
                .presentationDetents([.fraction(0.85), .large])
                .presentationDragIndicator(.visible)
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

            Button(action: handleSendInvitation) {
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

    private var sharedMembersSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Active Access")
                .font(AppTypography.headline)
                .foregroundStyle(AppColor.textPrimary)

            ForEach(sharedContacts) { contact in
                HStack(spacing: AppSpacing.md) {
                    ZStack {
                        Circle()
                            .fill(AppColor.Gray.gray100)
                            .frame(width: 44, height: 44)

                        Text(contact.initial)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(contact.name)
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
                .background(AppColor.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.r24))
            }
        }
        .padding(.top, AppSpacing.sm)
    }

    // MARK: - Contacts Permission Handler

    private func handleSendInvitation() {
        let store = CNContactStore()
        let status = CNContactStore.authorizationStatus(for: .contacts)

        if status == .notDetermined {
            store.requestAccess(for: .contacts) { _, _ in
                DispatchQueue.main.async {
                    self.showingAddAccess = true
                }
            }
        } else {
            showingAddAccess = true
        }
    }
}

#Preview {
    AccessView()
}
