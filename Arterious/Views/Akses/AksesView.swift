import SwiftUI

struct AksesView: View {
    @Bindable var syncViewModel: SyncViewModel
    @State private var isSharing: Bool = false
    @State private var showDetailSheet: Bool = false
    @State private var isEditing: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hue: 0.6, saturation: 0.02, brightness: 0.97)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // White card containing list of parents
                        VStack(spacing: 0) {
                            if syncViewModel.syncState.status == .accepted {
                                // Paired Parent 1
                                parentRow(name: syncViewModel.parentName) {
                                    showDetailSheet = true
                                }

                                Divider()
                                    .padding(.leading, 56)

                                // Example Parent 2 (Secondary profile or addable)
                                parentRow(name: "Nama Ortu 2") {
                                    showDetailSheet = true
                                }
                            } else {
                                // Not Paired State in Akses
                                VStack(spacing: 16) {
                                    HStack(spacing: 14) {
                                        Image(systemName: "person.crop.circle.badge.plus")
                                            .font(.system(size: 28))
                                            .foregroundStyle(.blue)

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("Belum ada akses terhubung")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(.primary)

                                            Text("Tap tombol + di atas atau di bawah untuk mengundang orang tua.")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                    }

                                    Button {
                                        triggerShare()
                                    } label: {
                                        HStack(spacing: 6) {
                                            if isSharing || syncViewModel.isLoading {
                                                ProgressView().tint(.white)
                                            } else {
                                                Image(systemName: "plus")
                                                    .font(.system(size: 13, weight: .bold))
                                            }
                                            Text("Undang Orang Tua")
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 11)
                                        .background(Color.blue)
                                        .foregroundStyle(.white)
                                        .clipShape(Capsule())
                                    }
                                    .disabled(isSharing || syncViewModel.isLoading)
                                }
                                .padding(20)
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
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Akses")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    // Circular '+' Button
                    Button {
                        triggerShare()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 38, height: 38)
                                .shadow(color: Color.black.opacity(0.06), radius: 6, y: 2)

                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.primary)
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
            .sheet(isPresented: $showDetailSheet) {
                parentDetailSheet
            }
        }
    }

    // MARK: - Parent Row Component (Screenshot 1)

    private func parentRow(name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 26))
                    .foregroundStyle(.primary)

                Text(name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)

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

    private var parentDetailSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.blue.gradient)

                    Text(syncViewModel.parentName)
                        .font(.title2.bold())

                    HStack(spacing: 6) {
                        Circle().fill(Color.green).frame(width: 8, height: 8)
                        Text("Terhubung via iCloud")
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
                        Text("Peran")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(syncViewModel.syncState.role == .child ? "Anak (Pemantau)" : "Orang Tua")
                            .font(.subheadline.bold())
                    }
                    .padding()
                    .background(Color(white: 0.96))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)

                Spacer()

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

    private func triggerShare() {
        Task {
            isSharing = true
            if let url = await syncViewModel.requestShareLink() {
                ShareSheetHelper.share(url: url)
            }
            isSharing = false
        }
    }
}

#Preview {
    AksesView(syncViewModel: SyncViewModel())
}
