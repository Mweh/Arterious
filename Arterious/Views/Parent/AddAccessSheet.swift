import SwiftUI
import Contacts

/// Model representing a selectable contact item for family access.
struct ContactItem: Identifiable, Hashable, Equatable {
    let id: String
    let name: String
    let phone: String

    var initial: String {
        String(name.prefix(1)).uppercased()
    }
}

/// Sheet for adding access by picking a family contact.
struct AddAccessSheet: View {

    @Environment(\.dismiss) private var dismiss

    let onContactSelected: (ContactItem) -> Void

    @State private var searchText = ""
    @State private var selectedContact: ContactItem?
    @State private var contacts: [ContactItem] = [
        ContactItem(
            id: "1",
            name: "Alex Morgan",
            phone: "+1 (555) 234-5678"
        ),
        ContactItem(
            id: "2",
            name: "Brian Cooper",
            phone: "+1 (555) 876-5432"
        ),
        ContactItem(
            id: "3",
            name: "Clara Bennett",
            phone: "+1 (555) 345-6789"
        )
    ]

    private var filteredContacts: [ContactItem] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return contacts
        } else {
            return contacts.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.phone.contains(searchText)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    // Custom Navigation Bar
                    HStack {
                        Spacer()

                        Text("Add Access")
                            .font(AppTypography.bodySemibold)
                            .foregroundStyle(AppColor.textPrimary)

                        Spacer()

                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(AppColor.textPrimary)
                                .frame(width: 32, height: 32)
                                .background(Color(.systemGray6))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.sm)
                    .padding(.bottom, AppSpacing.md)

                    // Contacts List
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredContacts) { contact in
                                contactRow(contact)
                                    .onTapGesture {
                                        selectedContact = contact
                                    }
                            }
                        }
                        .padding(.bottom, 80) // Leave space for floating search bar
                    }
                }

                // Floating Search Bar at Bottom
                searchBar
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.md)
            }
            .background(AppColor.backgroundSecondary.ignoresSafeArea())
            .task {
                await loadDeviceContacts()
            }
            .navigationDestination(item: $selectedContact) { contact in
                ShareDataView(
                    contactName: contact.name,
                    contactPhone: contact.phone,
                    onBack: {
                        selectedContact = nil
                    },
                    onDismiss: {
                        selectedContact = nil
                        dismiss()
                    },
                    onConfirm: {
                        onContactSelected(contact)
                        selectedContact = nil
                        dismiss()
                    }
                )
                .navigationBarBackButtonHidden(true)
            }
        }
    }

    // MARK: - Contact Row

    private func contactRow(_ item: ContactItem) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.md) {
                // Circle Initial Avatar
                ZStack {
                    Circle()
                        .fill(AppColor.Gray.gray100)
                        .frame(width: 44, height: 44)

                    Text(item.initial)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(AppTypography.bodySemibold)
                        .foregroundStyle(AppColor.textPrimary)

                    Text(item.phone)
                        .font(AppTypography.subheadlineRegular)
                        .foregroundStyle(AppColor.textSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.sm + 4)
            .contentShape(Rectangle())

            Divider()
                .padding(.leading, 76)
        }
    }

    // MARK: - Bottom Floating Search Bar

    private var searchBar: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(AppColor.textSecondary)

            TextField("Enter Contact Name", text: $searchText)
                .font(AppTypography.bodyRegular)
                .foregroundStyle(AppColor.textPrimary)

            Button { } label: {
                Image(systemName: "mic")
                    .font(.system(size: 16))
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    // MARK: - Contacts Loader

    private func loadDeviceContacts() async {
        let store = CNContactStore()
        guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else {
            return
        }

        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor
        ]

        let request = CNContactFetchRequest(keysToFetch: keysToFetch)

        var loadedContacts: [ContactItem] = []

        try? store.enumerateContacts(with: request) { contact, _ in
            let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
            guard !fullName.isEmpty else { return }

            let phone = contact.phoneNumbers.first?.value.stringValue ?? ""
            loadedContacts.append(
                ContactItem(
                    id: contact.identifier,
                    name: fullName,
                    phone: phone
                )
            )
        }

        if !loadedContacts.isEmpty {
            await MainActor.run {
                self.contacts = loadedContacts
            }
        }
    }
}

#Preview {
    AddAccessSheet { _ in }
}
