import Combine
import Foundation

@MainActor
/// Application-level queue and presentation facade over a replaceable playback engine.
final class PlaybackController: ObservableObject {
    /// Track currently loaded by the engine.
    @Published private(set) var currentTrack: Track?
    /// Circular playback queue containing the current track.
    @Published private(set) var queue: [Track] = []
    /// Mirrored engine playback state.
    @Published private(set) var isPlaying = false
    /// Mirrored engine position in seconds.
    @Published private(set) var elapsed: TimeInterval = 0
    /// Whether the full-screen player sheet is presented.
    @Published var isPlayerPresented = false

    private let engine: any PlaybackEngine
    private var subscriptions = Set<AnyCancellable>()

    /// Creates a controller and subscribes to its replaceable engine.
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

    /// Selects a track and queue, or resumes it when already current.
    func play(track: Track, in tracks: [Track]) {
        if currentTrack?.id != track.id {
            currentTrack = track
            queue = tracks
            engine.load(track, autoplay: true)
        } else {
            engine.play()
        }
    }

    /// Toggles play and pause for the current item.
    func togglePlayback() {
        guard currentTrack != nil else { return }
        if isPlaying {
            engine.pause()
        } else {
            engine.play()
        }
    }

    /// Seeks the current item through the engine.
    func seek(to time: TimeInterval) {
        guard currentTrack != nil else { return }
        engine.seek(to: time)
    }

    /// Advances to the next queue item with wraparound.
    func playNext() {
        moveQueue(by: 1)
    }

    /// Restarts after four seconds or otherwise selects the previous queue item.
    func playPrevious() {
        // Match familiar player behavior: restart an established track before changing queue item.
        if elapsed > 4 {
            seek(to: 0)
        } else {
            moveQueue(by: -1)
        }
    }

    /// Normalized progress suitable for UI geometry.
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
