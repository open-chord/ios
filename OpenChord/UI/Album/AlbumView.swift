import SwiftUI

/// Album detail screen with ordered tracks and offline-download actions.
struct AlbumView: View {
    @Environment(PlaybackController.self) private var player
    @EnvironmentObject private var downloads: TrackDownloadStore
    let album: Album

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                ArtworkView(style: album.artwork, cornerRadius: 22)
                    .frame(width: 218, height: 218)
                    .padding(.top, 8)

                VStack(spacing: 4) {
                    Text(album.title)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text(album.artist.name)
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Text("\(album.year) · \(album.durationText)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 12) {
                    Button {
                        playAlbum()
                    } label: {
                        Label("Play", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                    }
                    .openChordProminentGlassButton()
                    .disabled(album.tracks.isEmpty)

                    Button {
                        Task { await downloads.download(album.tracks) }
                    } label: {
                        Label(downloadAlbumTitle, systemImage: downloadAlbumSymbol)
                            .font(.subheadline.weight(.semibold))
                            .labelStyle(.iconOnly)
                            .frame(width: 48, height: 48)
                    }
                    .openChordGlassButton()
                    .disabled(album.tracks.isEmpty || isDownloadingAlbum)
                    .accessibilityLabel(downloadAlbumTitle)
                }
                .padding(.top, 2)

                LazyVStack(spacing: 0) {
                    ForEach(Array(album.tracks.enumerated()), id: \.element.id) { index, track in
                        TrackRow(number: index + 1, track: track) {
                            player.play(
                                track: downloads.playable(track),
                                in: downloads.playable(album.tracks)
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 40)
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "Download failed",
            isPresented: Binding(
                get: { downloads.errorMessage != nil },
                set: { if !$0 { downloads.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(downloads.errorMessage ?? "")
        }
    }

    private func playAlbum() {
        guard let first = album.tracks.first else { return }
        player.play(
            track: downloads.playable(first),
            in: downloads.playable(album.tracks)
        )
    }

    private var isDownloadingAlbum: Bool {
        album.tracks.contains { downloads.state(for: $0) == .downloading }
    }

    private var isAlbumDownloaded: Bool {
        !album.tracks.isEmpty && album.tracks.allSatisfy { downloads.state(for: $0) == .downloaded }
    }

    private var downloadAlbumTitle: String {
        isAlbumDownloaded ? "Downloaded" : isDownloadingAlbum ? "Downloading…" : "Download Album"
    }

    private var downloadAlbumSymbol: String {
        isAlbumDownloaded ? "checkmark.circle.fill" : "arrow.down.circle"
    }
}

/// A track action row that reflects playback and download state.
private struct TrackRow: View {
    @EnvironmentObject private var catalog: CatalogStore
    @EnvironmentObject private var downloads: TrackDownloadStore
    @State private var mutationError: String?
    let number: Int
    let track: Track
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: action) {
                HStack(spacing: 14) {
                    Text("\(number)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(track.title).foregroundStyle(.primary)
                        Text(track.artistName).font(.caption).foregroundStyle(.secondary)
                    }

                    Spacer()
                    Text(track.duration.playbackTime)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            downloadButton

            Menu {
                if catalog.playlists.isEmpty {
                    Text("Create a playlist in Library first")
                } else {
                    ForEach(catalog.playlists) { playlist in
                        Button(playlist.name, systemImage: "music.note.list") {
                            addToPlaylist(playlist)
                        }
                        .disabled(playlist.tracks.contains { $0.id == track.id })
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("More actions for \(track.title)")
        }
        .padding(.vertical, 7)
        .alert(
            "Could Not Add Track",
            isPresented: Binding(
                get: { mutationError != nil },
                set: { if !$0 { mutationError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(mutationError ?? "")
        }
    }

    private func addToPlaylist(_ playlist: Playlist) {
        Task {
            do {
                try await catalog.add(track, to: playlist)
            } catch {
                mutationError = error.localizedDescription
            }
        }
    }

    @ViewBuilder
    private var downloadButton: some View {
        switch downloads.state(for: track) {
        case .downloading:
            ProgressView()
                .controlSize(.small)
                .frame(width: 36, height: 36)
                .accessibilityLabel("Downloading \(track.title)")
        case .downloaded:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .frame(width: 36, height: 36)
                .accessibilityLabel("\(track.title) downloaded")
        case .idle, .failed:
            Button("Download \(track.title)", systemImage: "arrow.down.circle") {
                Task { await downloads.download(track) }
            }
            .labelStyle(.iconOnly)
            .frame(width: 36, height: 36)
        }
    }
}
