import SwiftUI

/// Shared Liquid Glass treatments with material fallbacks for older iOS releases.
extension View {
    @ViewBuilder
    func openChordGlass(cornerRadius: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        }
    }

    @ViewBuilder
    func openChordGlassButton() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    func openChordProminentGlassButton() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glassProminent)
                .tint(.white)
                .foregroundStyle(.black)
        } else {
            buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
        }
    }
}
