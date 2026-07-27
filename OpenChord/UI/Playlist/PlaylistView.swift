import SwiftUI

/// Server-backed playlist detail with playback and membership management.
struct PlaylistView: View {
    @Environment(PlaybackController.self) private var player
    @EnvironmentObject private var catalog: CatalogStore
    @EnvironmentObject private var downloads: TrackDownloadStore
    @Environment(\.dismiss) private var dismiss

    let playlistID: UUID
    @State private var mutationError: String?
    @State private var isRenaming = false
    @State private var editedName = ""
    @State private var isConfirmingDelete = false

    var body: some View {
        Group {
            if let playlist {
                content(playlist)
            } else {
                ContentUnavailableView(
                    "Playlist Unavailable",
                    systemImage: "music.note.list",
                    description: Text("It may have been deleted on another device.")
                )
            }
        }
        .background(Color.black)
        .navigationTitle(playlist?.name ?? "Playlist")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Rename", systemImage: "pencil") {
                        editedName = playlist?.name ?? ""
                        isRenaming = true
                    }
                    Button("Delete Playlist", systemImage: "trash", role: .destructive) {
                        isConfirmingDelete = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .disabled(playlist == nil)
            }
        }
        .alert("Rename Playlist", isPresented: $isRenaming) {
            TextField("Playlist name", text: $editedName)
            Button("Cancel", role: .cancel) {}
            Button("Save") { renamePlaylist() }
                .disabled(editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .confirmationDialog(
            "Delete Playlist?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Playlist", role: .destructive) { deletePlaylist() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Tracks and albums will remain in your library.")
        }
        .alert(
            "Could Not Update Playlist",
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

    private func content(_ playlist: Playlist) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                ArtworkView(style: playlist.artwork)
                    .frame(maxWidth: 280)
                    .padding(.top, 12)

                VStack(spacing: 5) {
                    Text(playlist.name)
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                    Text(playlist.durationText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button {
                    guard let first = playlist.tracks.first else { return }
                    player.play(
                        track: downloads.playable(first),
                        in: downloads.playable(playlist.tracks)
                    )
                } label: {
                    Label("Play", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
                .disabled(playlist.tracks.isEmpty)

                if playlist.tracks.isEmpty {
                    ContentUnavailableView(
                        "Playlist Empty",
                        systemImage: "text.badge.plus",
                        description: Text("Open an album and use a track’s menu to add it here.")
                    )
                    .padding(.top, 24)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(playlist.tracks.enumerated()), id: \.element.id) { index, track in
                            trackRow(track, number: index + 1, playlist: playlist)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
    }

    private func trackRow(_ track: Track, number: Int, playlist: Playlist) -> some View {
        HStack(spacing: 14) {
            Button {
                player.play(
                    track: downloads.playable(track),
                    in: downloads.playable(playlist.tracks)
                )
            } label: {
                HStack(spacing: 14) {
                    Text("\(number)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(track.title)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(track.artistName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()
                    Text(track.duration.playbackTime)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button("Remove \(track.title)", systemImage: "minus.circle") {
                Task {
                    do {
                        try await catalog.remove(track, from: playlist)
                    } catch {
                        mutationError = error.localizedDescription
                    }
                }
            }
            .labelStyle(.iconOnly)
            .frame(width: 36, height: 36)
        }
        .padding(.vertical, 9)
    }

    private var playlist: Playlist? {
        catalog.playlists.first { $0.id == playlistID }
    }

    private func renamePlaylist() {
        guard let playlist else { return }
        let name = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                try await catalog.renamePlaylist(playlist, to: name)
            } catch {
                mutationError = error.localizedDescription
            }
        }
    }

    private func deletePlaylist() {
        guard let playlist else { return }
        Task {
            do {
                try await catalog.deletePlaylist(playlist)
                dismiss()
            } catch {
                mutationError = error.localizedDescription
            }
        }
    }
}
