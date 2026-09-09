import SwiftUI

enum TimeRangeOption: String, CaseIterable, Identifiable {
    case hour = "J"
    case day = "H"
    case week = "M"
    case month = "B"
    case year = "T"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hour: return "Jam"
        case .day: return "Hari"
        case .week: return "Minggu"
        case .month: return "Bulan"
        case .year: return "Tahun"
        }
    }
}

/// Capsule segmented control matching the J | H | M | B | T design in Arterious metric detail pages.
struct TimeRangePicker: View {

    @Binding var selectedRange: TimeRangeOption

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TimeRangeOption.allCases) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedRange = option
                    }
                } label: {
                    Text(option.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(selectedRange == option ? AppColor.textPrimary : AppColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background {
                            if selectedRange == option {
                                Capsule()
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color(.systemGray5))
        .clipShape(Capsule())
    }
}

#Preview {
    @Previewable @State var range: TimeRangeOption = .week
    VStack {
        TimeRangePicker(selectedRange: $range)
            .padding()
    }
    .background(AppColor.backgroundPrimary)
}
