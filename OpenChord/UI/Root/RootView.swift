import SwiftUI

/// Root navigation shell coordinating the library, global sheets, and persistent mini-player.
struct RootView: View {
    private enum AppTab: Hashable {
        case library
        case settings
        case search
    }

    @Environment(PlaybackController.self) private var player
    @EnvironmentObject private var catalog: CatalogStore
    @State private var selectedTab: AppTab = .library

    @ViewBuilder
    var body: some View {
        @Bindable var player = player

        if #available(iOS 26.0, *) {
            if let track = player.currentTrack {
                modernTabShell
                    .tabBarMinimizeBehavior(.onScrollDown)
                    .tabViewBottomAccessory {
                        AdaptiveMiniPlayer(track: track)
                    }
            } else {
                modernTabShell
                    .tabBarMinimizeBehavior(.onScrollDown)
            }
        } else if #available(iOS 18.0, *) {
            modernTabShell
                .safeAreaInset(edge: .bottom, spacing: 8) {
                    if let track = player.currentTrack {
                        LegacyMiniPlayer(track: track)
                            .padding(.horizontal, 10)
                    }
                }
        } else {
            legacyTabShell
                .safeAreaInset(edge: .bottom, spacing: 8) {
                    if let track = player.currentTrack {
                        LegacyMiniPlayer(track: track)
                            .padding(.horizontal, 10)
                    }
                }
        }
    }

    @available(iOS 18.0, *)
    private var modernTabShell: some View {
        @Bindable var player = player

        return TabView(selection: $selectedTab) {
            Tab("Library", systemImage: "square.stack.fill", value: AppTab.library) {
                NavigationStack {
                    LibraryView {
                        selectedTab = .settings
                    }
                }
            }

            Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                NavigationStack {
                    SettingsView()
                }
            }

            Tab(value: AppTab.search, role: .search) {
                NavigationStack {
                    SearchView()
                }
            }
        }
        .sheet(isPresented: $player.isPlayerPresented) {
            PlayerView()
        }
        .tint(.white)
        .task {
            await catalog.loadIfNeeded()
        }
    }

    private var legacyTabShell: some View {
        @Bindable var player = player

        return TabView(selection: $selectedTab) {
            NavigationStack {
                LibraryView {
                    selectedTab = .settings
                }
            }
            .tabItem { Label("Library", systemImage: "square.stack.fill") }
            .tag(AppTab.library)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            .tag(AppTab.settings)

            NavigationStack {
                SearchView()
            }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }
            .tag(AppTab.search)
        }
        .sheet(isPresented: $player.isPlayerPresented) {
            PlayerView()
        }
        .tint(.white)
        .task {
            await catalog.loadIfNeeded()
        }
    }
}

/// Playback summary that follows the system accessory's expanded or inline placement.
@available(iOS 26.0, *)
private struct AdaptiveMiniPlayer: View {
    @Environment(\.tabViewBottomAccessoryPlacement) private var accessoryPlacement
    let track: Track

    var body: some View {
        MiniPlayerContent(
            track: track,
            isCompact: accessoryPlacement == .inline,
            usesFallbackMaterial: false
        )
    }
}

/// Material-backed playback summary for systems without tab accessories.
private struct LegacyMiniPlayer: View {
    let track: Track

    var body: some View {
        MiniPlayerContent(track: track, isCompact: false, usesFallbackMaterial: true)
    }
}

/// Shared mini-player content independent of its system container.
private struct MiniPlayerContent: View {
    @Environment(PlaybackController.self) private var player
    let track: Track
    let isCompact: Bool
    let usesFallbackMaterial: Bool

    var body: some View {
        HStack(spacing: isCompact ? 8 : 12) {
            ArtworkView(
                style: track.artwork,
                cornerRadius: isCompact ? 6 : 10,
                showsShadow: false
            )
            .frame(
                width: isCompact ? 30 : 52,
                height: isCompact ? 30 : 52
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if !isCompact {
                    Text(track.artistName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                player.togglePlayback()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .frame(width: 40, height: 40)
            }

            if !isCompact {
                Button {
                    player.playNext()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                        .frame(width: 40, height: 40)
                }
                .accessibilityLabel("Next track")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, isCompact ? 3 : 6)
        .fallbackMiniPlayerGlass(isEnabled: usesFallbackMaterial)
        .contentShape(Rectangle())
        .onTapGesture { player.isPlayerPresented = true }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the full player")
    }
}

private extension View {
    /// Adds a material container only on systems without TabView accessories.
    @ViewBuilder
    func fallbackMiniPlayerGlass(isEnabled: Bool) -> some View {
        if !isEnabled {
            self
        } else {
            background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
    }
}
