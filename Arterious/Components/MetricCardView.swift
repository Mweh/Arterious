import SwiftUI

struct MetricCardView: View {
    let metric: MetricType
    let value: Double?
    let baselineValue: Double?
    
    private var formattedValue: String {
        guard let value else { return "—" }
        switch metric {
        case .heartRate, .restingHeartRate:
            return "\(Int(round(value)))"
        case .steps:
            return NumberFormatter.localizedString(from: NSNumber(value: Int(value)), number: .decimal)
        case .sleep:
            return String(format: "%.1f", value)
        }
    }
    
    private var differenceText: String? {
        guard let value, let baselineValue, baselineValue > 0 else { return nil }
        let diffPercent = ((value - baselineValue) / baselineValue) * 100.0
        let sign = diffPercent >= 0 ? "+" : ""
        return "\(sign)\(Int(round(diffPercent)))% vs 14d avg"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(metric.rawValue, systemImage: metric.iconName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(formattedValue)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                
                Text(metric.unitString)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            
            if let differenceText {
                Text(differenceText)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.secondarySystemFill))
                    .clipShape(Capsule())
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    MetricCardView(metric: .steps, value: 3450, baselineValue: 4800)
        .padding()
        .background(Color(.systemGroupedBackground))
}
