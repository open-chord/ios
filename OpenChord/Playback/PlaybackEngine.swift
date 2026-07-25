import Combine
import Foundation

struct PlaybackEngineState: Equatable {
    var elapsed: TimeInterval = 0
    var duration: TimeInterval = 0
    var isPlaying = false
}

enum PlaybackEngineEvent: Equatable {
    case finished
}

/// The media boundary used by `PlaybackController`.
///
/// Implementations own media-specific state and side effects. The controller
/// remains responsible for queue policy and presentation state.
@MainActor
protocol PlaybackEngine: AnyObject {
    var state: AnyPublisher<PlaybackEngineState, Never> { get }
    var events: AnyPublisher<PlaybackEngineEvent, Never> { get }

    func load(_ track: Track, autoplay: Bool)
    func play()
    func pause()
    func seek(to time: TimeInterval)
}

/// Temporary engine used until the AVPlayer implementation lands.
///
/// Keeping the prototype behaviour behind the production contract lets the UI
/// and queue logic migrate now without pretending that real audio exists yet.
@MainActor
final class SimulatedPlaybackEngine: PlaybackEngine {
    private let stateSubject = CurrentValueSubject<PlaybackEngineState, Never>(.init())
    private let eventSubject = PassthroughSubject<PlaybackEngineEvent, Never>()
    private var clockSubscription: AnyCancellable?

    var state: AnyPublisher<PlaybackEngineState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    var events: AnyPublisher<PlaybackEngineEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    init(clock: any PlaybackClock = SystemPlaybackClock()) {
        clockSubscription = clock.ticks
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    func load(_ track: Track, autoplay: Bool) {
        let duration = max(0, track.duration)
        stateSubject.send(
            PlaybackEngineState(
                elapsed: 0,
                duration: duration,
                isPlaying: autoplay && duration > 0
            )
        )
    }

    func play() {
        guard stateSubject.value.duration > 0 else { return }
        updateState { $0.isPlaying = true }
    }

    func pause() {
        updateState { $0.isPlaying = false }
    }

    func seek(to time: TimeInterval) {
        updateState { state in
            state.elapsed = min(max(0, time), state.duration)
        }
    }

    private func tick() {
        let currentState = stateSubject.value
        guard currentState.isPlaying, currentState.duration > 0 else { return }

        let nextElapsed = min(currentState.elapsed + 0.25, currentState.duration)
        if nextElapsed >= currentState.duration {
            stateSubject.send(
                PlaybackEngineState(
                    elapsed: currentState.duration,
                    duration: currentState.duration,
                    isPlaying: false
                )
            )
            eventSubject.send(.finished)
        } else {
            updateState { $0.elapsed = nextElapsed }
        }
    }

    private func updateState(_ update: (inout PlaybackEngineState) -> Void) {
        var nextState = stateSubject.value
        update(&nextState)
        stateSubject.send(nextState)
    }
}
