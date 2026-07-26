import Combine
import Foundation

/// Supplies the passage of playback time without tying the controller to a
/// concrete timer. Tests use a manually controlled clock; the application uses
/// `SystemPlaybackClock`.
@MainActor
protocol PlaybackClock {
    /// Emits whenever simulated playback should advance.
    var ticks: AnyPublisher<Void, Never> { get }
}

@MainActor
/// Timer-backed clock used by the simulated engine outside deterministic tests.
struct SystemPlaybackClock: PlaybackClock {
    /// Interval between progress updates.
    let interval: TimeInterval

    /// Creates a clock with the supplied update cadence.
    init(interval: TimeInterval = 0.25) {
        self.interval = interval
    }

    /// Tick stream delivered on the main run loop.
    var ticks: AnyPublisher<Void, Never> {
        Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .map { _ in () }
            .eraseToAnyPublisher()
    }
}
