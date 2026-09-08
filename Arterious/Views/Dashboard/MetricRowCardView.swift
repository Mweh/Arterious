import SwiftUI

struct MetricRowCardView: View {
    let iconName: String
    let iconColor: Color
    let iconBgColor: Color
    let title: String
    let value: String
    var unit: String? = nil
    let statusText: String
    let dateText: String
    let barHeights: [CGFloat]
    let barColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Icon Circle
            ZStack {
                Circle()
                    .fill(iconBgColor)
                    .frame(width: 48, height: 48)
                Image(systemName: iconName)
                    .font(.system(size: 22))
                    .foregroundStyle(iconColor)
            }
            .padding(.top, 2)

            // Middle: Title, Value, Status
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.primary)

                    if let unit {
                        Text(unit)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Text(statusText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            // Right: Date, Chevron, and Mini Bar Chart
            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 4) {
                    Text(dateText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }

                // Mini Bar Chart / Sparkline
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(Array(barHeights.enumerated()), id: \.offset) { index, heightRatio in
                        Capsule()
                            .fill(barColor.opacity(index == barHeights.count - 1 ? 0.9 : 0.45 + Double(index) * 0.1))
                            .frame(width: 4, height: max(6, heightRatio * 22))
                    }
                }
                .frame(height: 24, alignment: .bottom)
            }
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.black.opacity(0.03), lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 14) {
        MetricRowCardView(
            iconName: "heart.fill",
            iconColor: Color(hue: 0.98, saturation: 0.75, brightness: 0.95),
            iconBgColor: Color(hue: 0.98, saturation: 0.12, brightness: 0.98),
            title: "Detak Jantung",
            value: "72",
            unit: "BPM",
            statusText: "Dalam rentang normal",
            dateText: "9 Sep",
            barHeights: [0.4, 0.6, 0.5, 0.8, 0.7, 0.9],
            barColor: Color.red
        )

        MetricRowCardView(
            iconName: "bed.double.fill",
            iconColor: Color(hue: 0.68, saturation: 0.6, brightness: 0.85),
            iconBgColor: Color(hue: 0.68, saturation: 0.12, brightness: 0.98),
            title: "Tidur",
            value: "7j 40m",
            unit: nil,
            statusText: "Kualitas tidur baik",
            dateText: "9 Sep",
            barHeights: [0.5, 0.7, 0.6, 0.85, 0.9],
            barColor: Color.indigo
        )

        MetricRowCardView(
            iconName: "figure.walk",
            iconColor: Color(hue: 0.42, saturation: 0.7, brightness: 0.75),
            iconBgColor: Color(hue: 0.42, saturation: 0.15, brightness: 0.98),
            title: "Aktivitas",
            value: "4.280",
            unit: nil,
            statusText: "Lebih baik dari biasanya",
            dateText: "9 Sep",
            barHeights: [0.3, 0.5, 0.7, 0.85, 0.95],
            barColor: Color.green
        )
    }
    .padding()
    .background(Color(white: 0.96))
}
