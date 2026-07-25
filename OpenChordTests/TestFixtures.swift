import Combine
import Foundation
@testable import OpenChord

@MainActor
final class ManualPlaybackClock: PlaybackClock {
    private let subject = PassthroughSubject<Void, Never>()

    var ticks: AnyPublisher<Void, Never> {
        subject.eraseToAnyPublisher()
    }

    func advance(by tickCount: Int = 1) {
        for _ in 0..<tickCount {
            subject.send()
        }
    }
}

func makeTrack(
    title: String = "Test Track",
    duration: TimeInterval = 10,
    lyrics: [LyricLine] = []
) -> Track {
    Track(
        id: UUID(),
        title: title,
        artistName: "Test Artist",
        albumTitle: "Test Album",
        duration: duration,
        artwork: ArtworkStyle(symbol: "music.note", colors: [.blue, .indigo]),
        lyrics: lyrics
    )
}
