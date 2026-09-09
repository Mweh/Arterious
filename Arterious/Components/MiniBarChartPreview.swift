import SwiftUI

/// Renders a compact mini bar chart preview matching the Figma metric cards.
struct MiniBarChartPreview: View {

    let values: [CGFloat]
    let color: Color

    init(
        values: [CGFloat] = [0.4, 0.7, 0.5, 0.9, 0.8, 0.6],
        color: Color = AppColor.Accent.red
    ) {
        self.values = values
        self.color = color
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<values.count, id: \.self) { index in
                let value = values[index]
                let isPeak = value > 0.75

                RoundedRectangle(cornerRadius: 1.5)
                    .fill(isPeak ? color : color.opacity(0.4))
                    .frame(width: 3.5, height: max(6, value * 24))
            }
        }
        .frame(height: 24)
    }
}

#Preview {
    HStack(spacing: 20) {
        MiniBarChartPreview(color: AppColor.Accent.red)
        MiniBarChartPreview(color: Color(red: 0.55, green: 0.45, blue: 0.9))
        MiniBarChartPreview(color: AppColor.Accent.green)
    }
    .padding()
}
