import Combine
import Foundation

/// Supplies the passage of playback time without tying the controller to a
/// concrete timer. Tests use a manually controlled clock; the application uses
/// `SystemPlaybackClock`.
@MainActor
protocol PlaybackClock {
    var ticks: AnyPublisher<Void, Never> { get }
}

@MainActor
/// Main-run-loop timer used by the simulated engine outside deterministic tests.
struct SystemPlaybackClock: PlaybackClock {
    let interval: TimeInterval

    init(interval: TimeInterval = 0.25) {
        self.interval = interval
    }

    var ticks: AnyPublisher<Void, Never> {
        Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .map { _ in () }
            .eraseToAnyPublisher()
    }
}
