import SwiftUI

/// The Home screen for the parents flow matching the Figma designs.
struct HomeView: View {

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = true
    @AppStorage("userRole") private var userRole: String = UserRole.parent.rawValue

    @State private var hasConnectedParent: Bool = false
    @State private var selectedParentName: String = "Orang Tua 1"
    @State private var showingShareSheet: Bool = false

    private let parentOptions = ["Orang Tua 1", "Orang Tua 2", "Ibu", "Ayah"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    if !hasConnectedParent {
                        // Empty state: Requesting contact to share data
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
            .background(AppColor.backgroundPrimary.ignoresSafeArea())
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
                // Native iOS Sharing sheet invitation
                ActivityShareView(
                    activityItems: [
                        "Hi! Let's stay connected and keep track of wellness on Arterious: https://arterious.app/invite"
                    ]
                )
                .presentationDetents([.medium, .large])
            }
        }
    }

    private var roleSwitcherMenu: some View {
        Menu {
            Button {
                userRole = (userRole == UserRole.parent.rawValue) ? UserRole.child.rawValue : UserRole.parent.rawValue
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

            Button {
                showingShareSheet = true
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 16, weight: .medium))

                    Text(isChild ? "Minta Kontak Membagikan Data" : "Kirim Undangan")
                        .font(AppTypography.buttonLabel)
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, 14)
                .background(AppColor.actionBlue)
                .clipShape(Capsule())
            }
            .padding(.horizontal, AppSpacing.xxl)
            .padding(.bottom, AppSpacing.xxl)
        }
        .frame(maxWidth: .infinity)
        .background(AppColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.r32))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 3)
    }

    // MARK: - Connected Dashboard Content

    private var connectedDashboardContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            // Parent Selector Dropdown Menu
            HStack {
                Spacer()

                Menu {
                    ForEach(parentOptions, id: \.self) { name in
                        Button(name) {
                            selectedParentName = name
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(selectedParentName)
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(AppColor.textPrimary)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    .padding(.vertical, 4)
                }

                Spacer()
            }

            // "Ringkasan Hari Ini" Blue Tinted Card
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Ringkasan Hari Ini")
                    .font(AppTypography.subheadlineRegular)
                    .foregroundStyle(AppColor.textSecondary)

                Text("Kondisi cukup stabil")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)
                    .padding(.top, 1)

                Text("Pola tidur baik, detak jantung dalam rentang normal, dan aktivitas sedikit lebih baik dari biasanya.")
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
                        value: "72",
                        unit: "BPM",
                        subtitle: "Dalam rentang normal",
                        dateString: "9 Sep",
                        chartValues: [0.4, 0.7, 0.5, 0.9, 0.8, 0.6]
                    )
                }
                .buttonStyle(.plain)

                // 2. Tidur / Sleep
                NavigationLink {
                    SleepDetailView()
                } label: {
                    HealthMetricSummaryCard(
                        iconName: "bed.double.fill",
                        iconColor: Color(red: 0.55, green: 0.45, blue: 0.9),
                        iconBgColor: Color(red: 0.55, green: 0.45, blue: 0.9).opacity(0.12),
                        title: "Tidur",
                        value: "7j 40m",
                        subtitle: "Kualitas tidur baik",
                        dateString: "9 Sep",
                        chartValues: [0.3, 0.7, 0.4, 0.9, 0.8, 0.5]
                    )
                }
                .buttonStyle(.plain)

                // 3. Aktivitas / Activity
                NavigationLink {
                    ActivityDetailView()
                } label: {
                    HealthMetricSummaryCard(
                        iconName: "figure.walk",
                        iconColor: AppColor.Accent.green,
                        iconBgColor: AppColor.Accent.green12,
                        title: "Aktivitas",
                        value: "4.280",
                        subtitle: "Lebih baik dari biasanya",
                        dateString: "9 Sep",
                        chartValues: [0.4, 0.6, 0.5, 0.9, 0.8, 0.3]
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Mode Switcher

    private var toggleModeButton: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                hasConnectedParent.toggle()
            }
        } label: {
            Image(systemName: hasConnectedParent ? "eye.fill" : "eye.slash.fill")
                .font(.system(size: 13))
                .foregroundStyle(AppColor.textSecondary)
                .frame(width: 30, height: 30)
                .background(Color(.systemGray6))
                .clipShape(Circle())
        }
    }
}

// MARK: - Native iOS UIActivityViewController Representable

struct ActivityShareView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

#Preview {
    HomeView()
}
