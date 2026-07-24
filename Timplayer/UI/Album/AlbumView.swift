import SwiftUI

struct AlbumView: View {
    @EnvironmentObject private var player: PlaybackController
    let album: Album

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ArtworkView(style: album.artwork)
                    .frame(maxWidth: 310)
                    .padding(.top, 12)

                VStack(spacing: 6) {
                    Text(album.title).font(.largeTitle.bold())
                    Text(album.artist.name).font(.title3).foregroundStyle(.secondary)
                    Text("\(album.year) · \(album.durationText)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Button {
                    guard let first = album.tracks.first else { return }
                    player.play(track: first, in: album.tracks)
                } label: {
                    Label("Play", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)

                VStack(spacing: 0) {
                    ForEach(Array(album.tracks.enumerated()), id: \.element.id) { index, track in
                        TrackRow(number: index + 1, track: track) {
                            player.play(track: track, in: album.tracks)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TrackRow: View {
    let number: Int
    let track: Track
    let action: () -> Void

    var body: some View {
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
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
