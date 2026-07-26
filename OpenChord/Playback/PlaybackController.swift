import Combine
import Foundation
import MediaPlayer
import Observation
import UIKit

/// Commands exposed by the system's Lock Screen and Control Center surfaces.
@MainActor
struct NowPlayingCommandHandlers {
    let play: () -> Void
    let pause: () -> Void
    let next: () -> Void
    let previous: () -> Void
    let seek: (TimeInterval) -> Void
}

/// Publishes playback metadata and connects system media commands to the app.
@MainActor
protocol NowPlayingManaging: AnyObject {
    func install(_ handlers: NowPlayingCommandHandlers)
    func publish(track: Track, queueIndex: Int, queueCount: Int)
    func update(elapsed: TimeInterval, isPlaying: Bool)
}

/// MediaPlayer-backed implementation used on physical devices.
@MainActor
final class SystemNowPlayingManager: NowPlayingManaging {
    private let infoCenter: MPNowPlayingInfoCenter
    private let commandCenter: MPRemoteCommandCenter
    private let session: URLSession
    private var commandTargets: [(MPRemoteCommand, Any)] = []
    private var artworkTask: Task<Void, Never>?
    private var publishedTrackID: UUID?

    init(
        infoCenter: MPNowPlayingInfoCenter = .default(),
        commandCenter: MPRemoteCommandCenter = .shared(),
        session: URLSession = .shared
    ) {
        self.infoCenter = infoCenter
        self.commandCenter = commandCenter
        self.session = session
    }

    isolated deinit {
        artworkTask?.cancel()
        for (command, target) in commandTargets {
            command.removeTarget(target)
        }
    }

    func install(_ handlers: NowPlayingCommandHandlers) {
        commandTargets.append(
            (
                commandCenter.playCommand,
                commandCenter.playCommand.addTarget { _ in
                    Task { @MainActor in handlers.play() }
                    return .success
                }
            )
        )
        commandTargets.append(
            (
                commandCenter.pauseCommand,
                commandCenter.pauseCommand.addTarget { _ in
                    Task { @MainActor in handlers.pause() }
                    return .success
                }
            )
        )
        commandTargets.append(
            (
                commandCenter.nextTrackCommand,
                commandCenter.nextTrackCommand.addTarget { _ in
                    Task { @MainActor in handlers.next() }
                    return .success
                }
            )
        )
        commandTargets.append(
            (
                commandCenter.previousTrackCommand,
                commandCenter.previousTrackCommand.addTarget { _ in
                    Task { @MainActor in handlers.previous() }
                    return .success
                }
            )
        )
        commandTargets.append(
            (
                commandCenter.changePlaybackPositionCommand,
                commandCenter.changePlaybackPositionCommand.addTarget { event in
                    guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                        return .commandFailed
                    }
                    Task { @MainActor in handlers.seek(positionEvent.positionTime) }
                    return .success
                }
            )
        )
    }

    func publish(track: Track, queueIndex: Int, queueCount: Int) {
        publishedTrackID = track.id
        artworkTask?.cancel()
        infoCenter.nowPlayingInfo = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artistName,
            MPMediaItemPropertyAlbumTitle: track.albumTitle,
            MPMediaItemPropertyPlaybackDuration: track.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: 0,
            MPNowPlayingInfoPropertyPlaybackRate: 1,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyPlaybackQueueIndex: queueIndex,
            MPNowPlayingInfoPropertyPlaybackQueueCount: queueCount,
        ]
        loadArtwork(for: track)
    }

    func update(elapsed: TimeInterval, isPlaying: Bool) {
        guard var information = infoCenter.nowPlayingInfo else { return }
        information[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        information[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1 : 0
        infoCenter.nowPlayingInfo = information
    }

    private func loadArtwork(for track: Track) {
        guard let artworkURL = track.artwork.remoteURL else { return }
        artworkTask = Task { [weak self] in
            guard
                let self,
                let (data, response) = try? await session.data(from: artworkURL),
                !Task.isCancelled,
                let httpResponse = response as? HTTPURLResponse,
                (200..<300).contains(httpResponse.statusCode),
                let image = UIImage(data: data),
                publishedTrackID == track.id,
                var information = infoCenter.nowPlayingInfo
            else { return }

            information[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(
                boundsSize: image.size,
                requestHandler: { _ in image }
            )
            infoCenter.nowPlayingInfo = information
        }
    }
}

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
    private let nowPlaying: any NowPlayingManaging
    @ObservationIgnored
    private var subscriptions = Set<AnyCancellable>()

    init(
        engine: any PlaybackEngine = AVPlayerPlaybackEngine(),
        nowPlaying: any NowPlayingManaging = SystemNowPlayingManager()
    ) {
        self.engine = engine
        self.nowPlaying = nowPlaying

        engine.state
            .sink { [weak self] state in
                if Thread.isMainThread {
                    self?.apply(state)
                } else {
                    // Combine preserves the publisher's delivery queue. AVPlayer
                    // may publish while handling media work off-main even though
                    // the engine API is main-actor isolated, while MediaPlayer
                    // asserts that Now Playing mutations execute on main.
                    DispatchQueue.main.async { [weak self] in
                        self?.apply(state)
                    }
                }
            }
            .store(in: &subscriptions)

        engine.events
            .sink { [weak self] event in
                guard event == .finished else {
                    return
                }

                if Thread.isMainThread {
                    self?.playNext()
                } else {
                    DispatchQueue.main.async { [weak self] in
                        self?.playNext()
                    }
                }
            }
            .store(in: &subscriptions)

        nowPlaying.install(
            NowPlayingCommandHandlers(
                play: { [weak self] in self?.resume() },
                pause: { [weak self] in self?.pause() },
                next: { [weak self] in self?.playNext() },
                previous: { [weak self] in self?.playPrevious() },
                seek: { [weak self] time in self?.seek(to: time) }
            )
        )
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
            publishNowPlaying()
            engine.load(track, autoplay: true)
        } else {
            resume()
        }
    }

    func togglePlayback() {
        guard currentTrack != nil else { return }
        if isPlaying {
            pause()
        } else {
            resume()
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
        publishNowPlaying()
        engine.load(nextTrack, autoplay: true)
    }

    private func resume() {
        guard currentTrack != nil else { return }
        engine.play()
    }

    private func pause() {
        guard currentTrack != nil else { return }
        engine.pause()
    }

    private func publishNowPlaying() {
        guard
            let currentTrack,
            let queueIndex = queue.firstIndex(where: { $0.id == currentTrack.id })
        else { return }
        nowPlaying.publish(track: currentTrack, queueIndex: queueIndex, queueCount: queue.count)
    }

    private func apply(_ state: PlaybackEngineState) {
        dispatchPrecondition(condition: .onQueue(.main))
        elapsed = state.elapsed
        isPlaying = state.isPlaying
        nowPlaying.update(elapsed: state.elapsed, isPlaying: state.isPlaying)
    }
}
