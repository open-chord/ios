import SwiftUI

struct RootView: View {
    @EnvironmentObject private var player: PlaybackController

    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem { Label("Home", systemImage: "house.fill") }

            NavigationStack {
                LibraryView()
            }
            .tabItem { Label("Library", systemImage: "square.stack.fill") }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let track = player.currentTrack {
                MiniPlayer(track: track)
                    // Safe-area всего TabView включает нижнюю область экрана, но
                    // не вычитает из неё собственный tab bar. Поднимаем плеер на
                    // стандартную высоту бара, чтобы два стеклянных слоя не
                    // накладывались друг на друга.
                    .padding(.horizontal, 10)
                    .padding(.bottom, 50)
            }
        }
        .sheet(isPresented: $player.isPlayerPresented) {
            PlayerView()
        }
        .tint(.white)
    }
}

private struct MiniPlayer: View {
    @EnvironmentObject private var player: PlaybackController
    let track: Track

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(style: track.artwork, cornerRadius: 10)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title).font(.subheadline.weight(.semibold))
                Text(track.artistName).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                player.togglePlayback()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .frame(width: 40, height: 40)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .bottomLeading) {
            GeometryReader { proxy in
                Capsule()
                    .fill(.white.opacity(0.8))
                    .frame(width: proxy.size.width * player.progress, height: 2)
            }
            .frame(height: 2)
            .padding(.horizontal, 12)
        }
        .contentShape(Rectangle())
        .onTapGesture { player.isPlayerPresented = true }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the full player")
    }
}
