import Combine
import Foundation

@MainActor
final class PlaybackController: ObservableObject {
    @Published private(set) var currentTrack: Track?
    @Published private(set) var queue: [Track] = []
    @Published private(set) var isPlaying = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published var isPlayerPresented = false

    private var timer: AnyCancellable?

    init() {
        // Таймер моделирует аудиодвижок. Он нужен не ради красивой анимации:
        // весь lyrics UI уже подписан на реальную шкалу времени и позже сможет
        // получать currentTime от AVPlayer без переделки экранов.
        timer = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    func play(track: Track, in tracks: [Track]) {
        if currentTrack?.id != track.id {
            currentTrack = track
            queue = tracks
            elapsed = 0
        }
        isPlaying = true
    }

    func togglePlayback() {
        guard currentTrack != nil else { return }
        isPlaying.toggle()
    }

    func seek(to time: TimeInterval) {
        guard let currentTrack else { return }
        elapsed = min(max(0, time), currentTrack.duration)
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

    private func tick() {
        guard isPlaying, let track = currentTrack else { return }
        if elapsed + 0.25 >= track.duration {
            playNext()
        } else {
            elapsed += 0.25
        }
    }

    private func moveQueue(by offset: Int) {
        guard
            let currentTrack,
            let currentIndex = queue.firstIndex(where: { $0.id == currentTrack.id }),
            !queue.isEmpty
        else { return }

        let newIndex = (currentIndex + offset + queue.count) % queue.count
        self.currentTrack = queue[newIndex]
        elapsed = 0
        isPlaying = true
    }
}
