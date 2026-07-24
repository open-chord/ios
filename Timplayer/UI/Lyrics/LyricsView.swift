import SwiftUI

struct LyricsView: View {
    @EnvironmentObject private var player: PlaybackController
    let track: Track

    var body: some View {
        if track.lyrics.isEmpty {
            ContentUnavailableView(
                "No Lyrics Yet",
                systemImage: "quote.bubble",
                description: Text("This track has not been synchronized.")
            )
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        ForEach(track.lyrics) { line in
                            lyricButton(line)
                                .id(line.id)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 80)
                }
                .onChange(of: activeLine?.id) { _, newID in
                    guard let newID else { return }
                    // Программная прокрутка реагирует только на смену строки,
                    // а не на каждый тик таймера. Так текст движется спокойно и
                    // не борется с пользователем, если он листает вручную.
                    withAnimation(.easeInOut(duration: 0.55)) {
                        proxy.scrollTo(newID, anchor: .center)
                    }
                }
            }
        }
    }

    private var activeLine: LyricLine? {
        track.lyrics.last(where: { $0.startTime <= player.elapsed })
    }

    private func lyricButton(_ line: LyricLine) -> some View {
        let isActive = activeLine?.id == line.id

        return Button {
            player.seek(to: line.startTime)
        } label: {
            Text(line.text)
                .font(.system(size: isActive ? 30 : 25, weight: .bold, design: .rounded))
                .foregroundStyle(isActive ? .white : .white.opacity(0.32))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.easeOut(duration: 0.25), value: isActive)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(line.text), \(line.startTime.playbackTime)")
        .accessibilityHint("Seeks playback to this lyric")
    }
}
