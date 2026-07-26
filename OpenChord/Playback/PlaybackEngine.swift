import Combine
import Foundation

/// Snapshot published by a playback engine.
struct PlaybackEngineState: Equatable {
    /// Current position in seconds.
    var elapsed: TimeInterval = 0
    /// Loaded item duration in seconds.
    var duration: TimeInterval = 0
    /// Whether audio is expected to be advancing.
    var isPlaying = false
}

/// Discrete playback lifecycle events that cannot be represented by state alone.
enum PlaybackEngineEvent: Equatable {
    /// The current item reached its natural end.
    case finished
}

/// The media boundary used by `PlaybackController`.
///
/// Implementations own media-specific state and side effects. The controller
/// remains responsible for queue policy and presentation state.
@MainActor
protocol PlaybackEngine: AnyObject {
    /// Current engine state stream.
    var state: AnyPublisher<PlaybackEngineState, Never> { get }
    /// Discrete engine event stream.
    var events: AnyPublisher<PlaybackEngineEvent, Never> { get }

    /// Resolves and loads a track, optionally starting immediately.
    func load(_ track: Track, autoplay: Bool)
    /// Resumes the loaded item.
    func play()
    /// Pauses the loaded item.
    func pause()
    /// Seeks to a position in seconds.
    func seek(to time: TimeInterval)
}

/// Deterministic clock-driven engine used by previews and domain tests.
@MainActor
final class SimulatedPlaybackEngine: PlaybackEngine {
    private let stateSubject = CurrentValueSubject<PlaybackEngineState, Never>(.init())
    private let eventSubject = PassthroughSubject<PlaybackEngineEvent, Never>()
    private var clockSubscription: AnyCancellable?

    /// Read-only state publisher.
    var state: AnyPublisher<PlaybackEngineState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    /// Read-only lifecycle event publisher.
    var events: AnyPublisher<PlaybackEngineEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    /// Creates an engine with an injectable clock.
    init(clock: any PlaybackClock = SystemPlaybackClock()) {
        clockSubscription = clock.ticks
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    /// Loads track metadata without resolving real media.
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

    /// Starts simulated progress when a track is loaded.
    func play() {
        guard stateSubject.value.duration > 0 else { return }
        updateState { $0.isPlaying = true }
    }

    /// Stops simulated progress.
    func pause() {
        updateState { $0.isPlaying = false }
    }

    /// Clamps simulated seeking to the loaded duration.
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
