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

/// Apple's original native segmented control component with built-in system liquid glass material.
struct TimeRangePicker: View {

    @Binding var selectedRange: TimeRangeOption

    var body: some View {
        Picker("Rentang Waktu", selection: $selectedRange) {
            ForEach(TimeRangeOption.allCases) { option in
                Text(option.rawValue)
                    .tag(option)
            }
        }
        .pickerStyle(.segmented)
    }
}

#Preview {
    @Previewable @State var range: TimeRangeOption = .week
    VStack(spacing: 20) {
        TimeRangePicker(selectedRange: $range)
            .padding()
    }
    .background(Color.white)
}
