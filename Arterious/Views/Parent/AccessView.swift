import SwiftUI
import Contacts

struct AccessView: View {

    @State private var showingAddAccess = false
    @State private var sharedContacts: [ContactItem] = []

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.backgroundPrimary
                    .ignoresSafeArea()

                if sharedContacts.isEmpty {
                    // MARK: - Profile / Empty State
                    emptyStateView
                } else {
                    // MARK: - Profile / Default
                    ScrollView {
                        connectedParentsCard
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                    }
                }
            }
            .navigationTitle("Akses")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    HStack(spacing: 10) {
                        Button {
                            showingAddAccess = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.black)
                                .frame(width: 36, height: 36)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
                        }

                        // Tombol pensil untuk switch/testing cepat antara Empty State dan Default State
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                if sharedContacts.isEmpty {
                                    sharedContacts = [
                                        ContactItem(id: "1", name: "Nama Ortu 1", phone: "+62812345678"),
                                        ContactItem(id: "2", name: "Nama Ortu 2", phone: "+62812345679")
                                    ]
                                } else {
                                    sharedContacts.removeAll()
                                }
                            }
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.black)
                                .frame(width: 36, height: 36)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
                        }
                    }
                }
            }
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

    // MARK: - Daftar Akun Terhubung (Profile / Default)

    private var connectedParentsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(sharedContacts.enumerated()), id: \.element.id) { index, contact in
                if index > 0 {
                    Divider()
                        .padding(.horizontal, 16)
                }

                HStack {
                    Text(contact.name)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color.black)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: "C7C7CC"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 2)
    }

    // MARK: - Empty State (Profile / Empty State)

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Text("Belum Ada Akun Terhubung")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color(hex: "707076"))

            Text("Ketuk tombol (+) di atas atau\nkembali ke Beranda untuk mulai\nmenghubungkan akun.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color(hex: "8E8E93"))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

#Preview {
    AccessView()
}
