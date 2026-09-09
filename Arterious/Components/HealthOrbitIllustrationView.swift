import SwiftUI

/// Renders the elliptical dashed health orbit graphic connecting 4 wellness nodes:
/// Family (top), Activity (right), Heart (bottom), and Sleep (left).
struct HealthOrbitIllustrationView: View {

    var body: some View {
        ZStack {
            // Dashed Elliptical Track
            Ellipse()
                .stroke(
                    Color(.systemGray4).opacity(0.8),
                    style: StrokeStyle(lineWidth: 1.2, dash: [4, 4])
                )
                .frame(width: 220, height: 95)
                .rotationEffect(.degrees(-6))

            // 1. Top Node: Family / Contacts (Light Blue)
            nodeCircle(
                iconName: "person.2.fill",
                iconColor: AppColor.Brand.primaryBlue,
                bgColor: AppColor.Brand.primaryBlue.opacity(0.12),
                size: 34,
                iconSize: 15
            )
            .offset(x: 32, y: -45)

            // 2. Right Node: Activity / Steps (Light Green)
            nodeCircle(
                iconName: "figure.walk",
                iconColor: AppColor.Accent.green,
                bgColor: AppColor.Accent.green.opacity(0.14),
                size: 32,
                iconSize: 15
            )
            .offset(x: 100, y: 0)

            // 3. Bottom Node: Heart (Glow Red)
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 38, height: 38)
                    .shadow(color: AppColor.Accent.red.opacity(0.28), radius: 10, x: 0, y: 2)

                Circle()
                    .fill(AppColor.Accent.red.opacity(0.12))
                    .frame(width: 38, height: 38)

                Image(systemName: "heart.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(AppColor.Accent.red)
            }
            .offset(x: -20, y: 38)

            // 4. Left Node: Sleep (Light Purple)
            nodeCircle(
                iconName: "bed.double.fill",
                iconColor: Color(red: 0.55, green: 0.45, blue: 0.9),
                bgColor: Color(red: 0.55, green: 0.45, blue: 0.9).opacity(0.14),
                size: 32,
                iconSize: 14
            )
            .offset(x: -95, y: -20)
        }
        .frame(height: 130)
    }

    private func nodeCircle(
        iconName: String,
        iconColor: Color,
        bgColor: Color,
        size: CGFloat,
        iconSize: CGFloat
    ) -> some View {
        ZStack {
            Circle()
                .fill(bgColor)
                .frame(width: size, height: size)

            Image(systemName: iconName)
                .font(.system(size: iconSize))
                .foregroundStyle(iconColor)
        }
    }
}

#Preview {
    HealthOrbitIllustrationView()
        .padding()
}
