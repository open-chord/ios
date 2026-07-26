import SwiftUI

/// Square remote artwork with an animated, deterministic generated fallback.
struct ArtworkView: View {
    /// Remote source and fallback palette.
    let style: ArtworkStyle
    /// Continuous clipping radius adjusted for each presentation size.
    var cornerRadius: CGFloat = 24

    /// Artwork image, loading state, or generated fallback.
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)

            ZStack {
                fallback(side: side)

                if let remoteURL = style.remoteURL {
                    AsyncImage(url: remoteURL, transaction: Transaction(animation: .easeOut(duration: 0.25))) { phase in
                        switch phase {
                        case let .success(image):
                            image
                                .resizable()
                                .scaledToFill()
                                .transition(.opacity)
                        case .empty:
                            ProgressView()
                                .tint(.white.opacity(0.8))
                        case .failure:
                            EmptyView()
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: style.colors.first?.swiftUIColor.opacity(0.3) ?? .clear, radius: 24, y: 12)
        .accessibilityHidden(true)
    }

    private func fallback(side: CGFloat) -> some View {
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
    /// Formats playback seconds as a stable minute:second label.
    var playbackTime: String {
        guard isFinite else { return "0:00" }
        let totalSeconds = max(0, Int(self))
        return "\(totalSeconds / 60):\(String(format: "%02d", totalSeconds % 60))"
    }
}
