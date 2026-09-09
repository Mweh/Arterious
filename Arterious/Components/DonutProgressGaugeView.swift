import SwiftUI

/// Circular segmented score gauge matching the Sleep detail overview card in Arterious.
struct DonutProgressGaugeView: View {

    var score: Int = 80
    var statusTitle: String = "Tinggi"
    var durationText: String = "8j 5m"
    var durationScoreText: String = "50/50"
    var sleepTimeText: String = "7j 5m"
    var sleepScoreText: String = "28/30"
    var awakeText: String = "17 mnt"
    var awakeScoreText: String = "7/20"

    // Colors matching the Figma designs
    private let blueSegmentColor = Color(hex: "3267FF")
    private let tealSegmentColor = Color(hex: "00C7B0")
    private let coralSegmentColor = Color(hex: "FF6E52")

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            // Donut Ring + Status Headline
            HStack(spacing: AppSpacing.xl) {
                ZStack {
                    ringCanvas
                        .frame(width: 120, height: 120)

                    Text("\(score)")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(AppColor.textPrimary)
                }

                Text(statusTitle)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)

                Spacer()
            }
            .padding(.horizontal, AppSpacing.sm)

            // Breakdown Rows
            VStack(spacing: AppSpacing.md) {
                scoreFactorRow(
                    color: blueSegmentColor,
                    title: "Durasi:",
                    subtitle: durationText,
                    score: durationScoreText
                )

                scoreFactorRow(
                    color: tealSegmentColor,
                    title: "Waktu Tidur:",
                    subtitle: sleepTimeText,
                    score: sleepScoreText
                )

                scoreFactorRow(
                    color: coralSegmentColor,
                    title: "Terbangun:",
                    subtitle: awakeText,
                    score: awakeScoreText
                )
            }
            .padding(.top, AppSpacing.xs)
        }
        .padding(AppSpacing.lg)
        .background(AppColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.r24))
        .shadow(color: Color.black.opacity(0.025), radius: 8, x: 0, y: 2)
    }

    // MARK: - Ring Canvas with 3 segmented arcs

    private var ringCanvas: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = (size.width - 24) / 2
            let lineWidth: CGFloat = 16

            // Angle definitions with small gap
            // Segment 1: Blue (Right/Top-Right, ~48% circle)
            let blueStart = Angle.degrees(-70)
            let blueEnd = Angle.degrees(95)

            var bluePath = Path()
            bluePath.addArc(center: center, radius: radius, startAngle: blueStart, endAngle: blueEnd, clockwise: false)
            context.stroke(
                bluePath,
                with: .color(blueSegmentColor),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )

            // Segment 2: Coral (Bottom-Right to Bottom-Left, ~22% circle)
            let coralStart = Angle.degrees(115)
            let coralEnd = Angle.degrees(185)

            var coralPath = Path()
            coralPath.addArc(center: center, radius: radius, startAngle: coralStart, endAngle: coralEnd, clockwise: false)
            context.stroke(
                coralPath,
                with: .color(coralSegmentColor),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )

            // Segment 3: Teal (Left to Top, ~26% circle)
            let tealStart = Angle.degrees(205)
            let tealEnd = Angle.degrees(270)

            var tealPath = Path()
            tealPath.addArc(center: center, radius: radius, startAngle: tealStart, endAngle: tealEnd, clockwise: false)
            context.stroke(
                tealPath,
                with: .color(tealSegmentColor),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
        }
    }

    // MARK: - Factor Row

    private func scoreFactorRow(color: Color, title: String, subtitle: String, score: String) -> some View {
        HStack(alignment: .center, spacing: AppSpacing.md) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColor.textPrimary)

                Text(subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(AppColor.textSecondary)
            }

            Spacer()

            Text(score)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColor.textPrimary)
        }
    }
}

#Preview {
    DonutProgressGaugeView()
        .padding()
        .background(AppColor.backgroundPrimary)
}
