import SwiftUI

struct ArtworkView: View {
    let style: ArtworkStyle
    var cornerRadius: CGFloat = 24

    var body: some View {
        // GeometryReader заставляет декоративные элементы брать размер у
        // контейнера. Раньше круг 180×180 задавал обложке собственный ideal size:
        // в mini-player SwiftUI выделял ей 48×48 для layout, но она продолжала
        // рисоваться на 180 pt и перекрывала список.
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)

            ZStack {
                LinearGradient(
                    colors: style.colors.map(\.swiftUIColor),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(.white.opacity(0.12))
                    .frame(width: side * 0.72, height: side * 0.72)
                    .blur(radius: side * 0.008)
                    .offset(x: side * 0.27, y: -side * 0.29)

                Image(systemName: style.symbol)
                    .font(.system(size: side * 0.23, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: style.colors.first?.swiftUIColor.opacity(0.3) ?? .clear, radius: 24, y: 12)
        .accessibilityHidden(true)
    }
}

private extension ArtworkColor {
    var swiftUIColor: Color {
        switch self {
        case .violet: .purple
        case .indigo: .indigo
        case .blue: .blue
        case .cyan: .cyan
        case .mint: .mint
        case .orange: .orange
        case .pink: .pink
        case .red: .red
        }
    }
}

extension TimeInterval {
    var playbackTime: String {
        guard isFinite else { return "0:00" }
        let totalSeconds = max(0, Int(self))
        return "\(totalSeconds / 60):\(String(format: "%02d", totalSeconds % 60))"
    }
}
