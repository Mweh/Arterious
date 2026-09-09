import SwiftUI

/// A reusable section header with an optional trailing action label.
///
/// Usage:
/// ```swift
/// SectionHeader("Heart Rate & HRV")
/// SectionHeader("Trends", actionTitle: "See All") { }
/// ```
struct SectionHeader: View {

    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(AppTypography.headline)
                .foregroundStyle(AppColor.textPrimary)

            Spacer()

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(AppTypography.subheadline)
                        .foregroundStyle(AppColor.accent)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: AppSpacing.lg) {
        SectionHeader(title: "Heart Rate & HRV")
        SectionHeader(title: "Sleep Analysis", actionTitle: "See All") { }
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}
