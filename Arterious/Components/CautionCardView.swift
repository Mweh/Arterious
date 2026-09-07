import SwiftUI

struct CautionCardView: View {
    let insight: CautionInsight
    var onCheckInTapped: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.headline)
                    .foregroundStyle(.orange)
                
                Text(insight.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            
            Text(insight.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
            
            HStack {
                Button(action: {
                    onCheckInTapped?()
                }) {
                    Label(insight.suggestedAction, systemImage: "phone.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                }
                
                Spacer()
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    CautionCardView(
        insight: CautionInsight(
            title: "Time for a Warm Check-In",
            message: "Mom's resting heart rate is slightly elevated (+8 BPM) and her step count dropped over the last 3 days. A friendly call might brighten her day.",
            suggestedAction: "Call Mom",
            dateDetected: Date()
        )
    )
    .padding()
}
