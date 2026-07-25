import AVFoundation
import Combine
import Foundation

/// `PlaybackEngine` backed by Apple's system media pipeline.
///
/// This implementation intentionally owns all AVFoundation details so the
/// controller and SwiftUI views continue to depend only on playback semantics.
@MainActor
final class AVPlayerPlaybackEngine: PlaybackEngine {
    private let player: AVPlayer
    private let bundle: Bundle
    private let stateSubject = CurrentValueSubject<PlaybackEngineState, Never>(.init())
    private let eventSubject = PassthroughSubject<PlaybackEngineEvent, Never>()
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    var state: AnyPublisher<PlaybackEngineState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    var events: AnyPublisher<PlaybackEngineEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    init(player: AVPlayer = AVPlayer(), bundle: Bundle = .main) {
        self.player = player
        self.bundle = bundle
        installTimeObserver()
    }

    isolated deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }

    func load(_ track: Track, autoplay: Bool) {
        guard let url = track.audioSource.url(in: bundle) else {
            player.replaceCurrentItem(with: nil)
            stateSubject.send(.init())
            return
        }

        let item = AVPlayerItem(url: url)
        observeEnd(of: item)
        player.replaceCurrentItem(with: item)
        stateSubject.send(
            PlaybackEngineState(
                elapsed: 0,
                duration: max(0, track.duration),
                isPlaying: autoplay
            )
        )

        if autoplay {
            player.play()
        }
    }

    func play() {
        guard player.currentItem != nil else { return }
        player.play()
        updateState { $0.isPlaying = true }
    }

    func pause() {
        player.pause()
        updateState { $0.isPlaying = false }
    }

    func seek(to time: TimeInterval) {
        let clampedTime = min(max(0, time), stateSubject.value.duration)
        player.seek(
            to: CMTime(seconds: clampedTime, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
        updateState { $0.elapsed = clampedTime }
    }

    private func installTimeObserver() {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let elapsed = time.seconds
                guard elapsed.isFinite else { return }
                self.updateState {
                    $0.elapsed = min(max(0, elapsed), $0.duration)
                    $0.isPlaying = self.player.rate != 0
                }
            }
        }
    }

    private func observeEnd(of item: AVPlayerItem) {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.updateState {
                    $0.elapsed = $0.duration
                    $0.isPlaying = false
                }
                self.eventSubject.send(.finished)
            }
        }
    }

    private func updateState(_ update: (inout PlaybackEngineState) -> Void) {
        var nextState = stateSubject.value
        update(&nextState)
        stateSubject.send(nextState)
    }
}
