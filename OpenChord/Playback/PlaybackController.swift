import Combine
import Foundation

@MainActor
final class PlaybackController: ObservableObject {
    @Published private(set) var currentTrack: Track?
    @Published private(set) var queue: [Track] = []
    @Published private(set) var isPlaying = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published var isPlayerPresented = false

    private let engine: any PlaybackEngine
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
        // Поведение знакомо по обычным плеерам: после нескольких секунд кнопка
        // возвращает начало трека, а не неожиданно переключает композицию.
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
