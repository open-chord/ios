import SwiftUI

/// Root navigation shell coordinating the library, global sheets, and persistent mini-player.
struct RootView: View {
    @Environment(PlaybackController.self) private var player
    @EnvironmentObject private var catalog: CatalogStore
    @State private var isShowingServerSettings = false

    var body: some View {
        @Bindable var player = player

        NavigationStack {
            LibraryView {
                isShowingServerSettings = true
            }
            .toolbar { serverToolbar }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let track = player.currentTrack {
                MiniPlayer(track: track)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
            }
        }
        .sheet(isPresented: $player.isPlayerPresented) {
            PlayerView()
        }
        .sheet(isPresented: $isShowingServerSettings) {
            ServerSettingsView()
        }
        .tint(.white)
        .task {
            await catalog.loadIfNeeded()
        }
    }

    @ToolbarContentBuilder
    private var serverToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                isShowingServerSettings = true
            } label: {
                ServerStatusIcon(state: catalog.connectionState)
            }
            .accessibilityIdentifier("serverSettings")
            .accessibilityLabel(serverAccessibilityLabel)
        }
    }

    private var serverAccessibilityLabel: String {
        switch catalog.connectionState {
        case .unknown: "Server settings"
        case .connecting: "Connecting to server"
        case .connected: "Server connected"
        case .unavailable: "Server unavailable"
        }
    }
}

/// Server glyph with a compact, semantic connection-state badge.
private struct ServerStatusIcon: View {
    let state: CatalogStore.ConnectionState

    var body: some View {
        Image(systemName: "server.rack")
            .frame(width: 30, height: 30)
            .overlay(alignment: .bottomTrailing) {
                statusBadge
                    .offset(x: 4, y: 4)
            }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch state {
        case .unknown:
            EmptyView()
        case .connecting:
            ProgressView()
                .controlSize(.mini)
                .padding(2)
                .background(.black, in: Circle())
        case .connected:
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.white, .green)
                .background(.black, in: Circle())
        case .unavailable:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.white, .red)
                .background(.black, in: Circle())
        }
    }
}

/// Persistent playback summary displayed above the tab bar.
private struct MiniPlayer: View {
    @Environment(PlaybackController.self) private var player
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
        .miniPlayerGlass()
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

private extension View {
    /// Uses native Liquid Glass where available while preserving the established
    /// material treatment on the app's iOS 17 deployment target.
    @ViewBuilder
    func miniPlayerGlass() -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(
                .clear.interactive(),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        } else {
            background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
    }
}
