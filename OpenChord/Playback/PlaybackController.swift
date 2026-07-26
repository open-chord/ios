import Combine
import Foundation
import Observation

@MainActor
/// Coordinates the playback queue and exposes presentation-ready player state.
///
/// The controller owns queue semantics while the injected ``PlaybackEngine``
/// owns media playback. Keeping those responsibilities separate makes queue
/// behavior deterministic in tests. Observation tracks each property
/// independently so playback ticks do not invalidate unrelated catalog views.
@Observable
final class PlaybackController {
    private(set) var currentTrack: Track?
    private(set) var queue: [Track] = []
    private(set) var isPlaying = false
    private(set) var elapsed: TimeInterval = 0
    var isPlayerPresented = false

    @ObservationIgnored
    private let engine: any PlaybackEngine
    @ObservationIgnored
    private var subscriptions = Set<AnyCancellable>()

    init(engine: any PlaybackEngine = AVPlayerPlaybackEngine()) {
        self.engine = engine

        engine.state
            .sink { [weak self] state in
                self?.elapsed = state.elapsed
                self?.isPlaying = state.isPlaying
            }
            .store(in: &subscriptions)

        engine.events
            .sink { [weak self] event in
                if event == .finished {
                    self?.playNext()
                }
            }
            .store(in: &subscriptions)
    }

    /// Selects a track and establishes the queue used by next and previous.
    ///
    /// Selecting the current track resumes playback without reloading it.
    ///
    /// - Parameters:
    ///   - track: The track to play.
    ///   - tracks: The queue containing `track`.
    func play(track: Track, in tracks: [Track]) {
        if currentTrack?.id != track.id {
            currentTrack = track
            queue = tracks
            engine.load(track, autoplay: true)
        } else {
            engine.play()
        }
    }

    func togglePlayback() {
        guard currentTrack != nil else { return }
        if isPlaying {
            engine.pause()
        } else {
            engine.play()
        }
    }

    func seek(to time: TimeInterval) {
        guard currentTrack != nil else { return }
        engine.seek(to: time)
    }

    func playNext() {
        moveQueue(by: 1)
    }

    func playPrevious() {
        // Match system music-player semantics: after meaningful progress,
        // previous restarts the current item instead of changing the queue.
        if elapsed > 4 {
            seek(to: 0)
        } else {
            moveQueue(by: -1)
        }
    }

    var progress: Double {
        guard let duration = currentTrack?.duration, duration > 0 else { return 0 }
        return elapsed / duration
    }

    private func moveQueue(by offset: Int) {
        guard
            let currentTrack,
            let currentIndex = queue.firstIndex(where: { $0.id == currentTrack.id }),
            !queue.isEmpty
        else { return }

        let newIndex = (currentIndex + offset + queue.count) % queue.count
        let nextTrack = queue[newIndex]
        self.currentTrack = nextTrack
        engine.load(nextTrack, autoplay: true)
    }
}
