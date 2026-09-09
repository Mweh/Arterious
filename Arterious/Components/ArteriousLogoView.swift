import SwiftUI

/// Displays the Arterious brand logo using the official AppIcon asset from the Xcode Assets catalog.
struct ArteriousLogoView: View {

    var size: CGFloat = 64
    var cornerRadius: CGFloat? = nil

    var body: some View {
        let radius = cornerRadius ?? (size * 0.22)

        Group {
            if let uiImage = UIImage(named: "AppLogo") ?? UIImage(named: "AppIcon") ?? Bundle.main.appIcon {
                Image(uiImage: uiImage)
                    .resizable()
            } else {
                Image("AppLogo")
                    .resizable()
            }
        }
        .aspectRatio(contentMode: .fit)
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Bundle AppIcon Helper

private extension Bundle {
    var appIcon: UIImage? {
        if let icons = infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last {
            return UIImage(named: lastIcon)
        }
        return nil
    }
}

#Preview {
    VStack(spacing: 24) {
        ArteriousLogoView(size: 96)
        Text("Arterious")
            .font(.system(size: 28, weight: .bold))
    }
    .padding()
}
