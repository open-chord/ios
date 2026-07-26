import Testing
@testable import OpenChord

@Suite("Playback state", .serialized)
@MainActor
struct PlaybackControllerTests {
    @Test("Play selects a track and starts playback")
    func playSelectsTrack() {
        let engine = ManualPlaybackEngine()
        let track = makeTrack()
        let controller = PlaybackController(engine: engine, nowPlaying: NowPlayingManagerRecorder())

        controller.play(track: track, in: [track])

        #expect(engine.loadedTrack == track)
        #expect(controller.currentTrack == track)
        #expect(controller.queue == [track])
        #expect(controller.isPlaying)
        #expect(controller.elapsed == 0)
    }

    @Test("Engine state drives the public playback state")
    func engineDrivesPlaybackState() {
        let engine = ManualPlaybackEngine()
        let track = makeTrack(duration: 10)
        let nowPlaying = NowPlayingManagerRecorder()
        let controller = PlaybackController(engine: engine, nowPlaying: nowPlaying)
        controller.play(track: track, in: [track])

        engine.send(elapsed: 1, isPlaying: true)

        #expect(controller.elapsed == 1)
        #expect(controller.progress == 0.1)
    }

    @Test("Seek clamps values to the playable range")
    func seekClampsToTrackDuration() {
        let track = makeTrack(duration: 10)
        let controller = PlaybackController(
            engine: ManualPlaybackEngine(),
            nowPlaying: NowPlayingManagerRecorder()
        )
        controller.play(track: track, in: [track])

        controller.seek(to: -4)
        #expect(controller.elapsed == 0)

        controller.seek(to: 15)
        #expect(controller.elapsed == 10)
    }

    @Test("Next wraps around the queue")
    func nextTrackWrapsAroundQueue() {
        let first = makeTrack(title: "First")
        let second = makeTrack(title: "Second")
        let controller = PlaybackController(
            engine: ManualPlaybackEngine(),
            nowPlaying: NowPlayingManagerRecorder()
        )
        controller.play(track: second, in: [first, second])

        controller.playNext()

        #expect(controller.currentTrack == first)
        #expect(controller.elapsed == 0)
    }

    @Test("Previous restarts a track after four seconds")
    func previousRestartsCurrentTrack() {
        let first = makeTrack(title: "First")
        let second = makeTrack(title: "Second")
        let controller = PlaybackController(
            engine: ManualPlaybackEngine(),
            nowPlaying: NowPlayingManagerRecorder()
        )
        controller.play(track: second, in: [first, second])
        controller.seek(to: 5)

        controller.playPrevious()

        #expect(controller.currentTrack == second)
        #expect(controller.elapsed == 0)
    }

    @Test("Finished engine event advances the queue")
    func finishedEventAdvancesQueue() {
        let first = makeTrack(title: "First")
        let second = makeTrack(title: "Second")
        let engine = ManualPlaybackEngine()
        let controller = PlaybackController(engine: engine, nowPlaying: NowPlayingManagerRecorder())
        controller.play(track: first, in: [first, second])

        engine.finish()

        #expect(controller.currentTrack == second)
        #expect(engine.loadedTrack == second)
        #expect(controller.isPlaying)
    }

    @Test("Selecting a track publishes system Now Playing metadata")
    func selectingTrackPublishesNowPlayingMetadata() {
        let first = makeTrack(title: "First")
        let second = makeTrack(title: "Second")
        let nowPlaying = NowPlayingManagerRecorder()
        let controller = PlaybackController(
            engine: ManualPlaybackEngine(),
            nowPlaying: nowPlaying
        )

        controller.play(track: second, in: [first, second])

        #expect(nowPlaying.publishedTrack == second)
        #expect(nowPlaying.publishedQueueIndex == 1)
        #expect(nowPlaying.publishedQueueCount == 2)
    }

    @Test("System pause and play commands control the engine")
    func systemCommandsControlPlayback() throws {
        let engine = ManualPlaybackEngine()
        let nowPlaying = NowPlayingManagerRecorder()
        let controller = PlaybackController(engine: engine, nowPlaying: nowPlaying)
        let track = makeTrack()
        controller.play(track: track, in: [track])
        let handlers = try #require(nowPlaying.handlers)

        handlers.pause()
        #expect(!controller.isPlaying)
        #expect(nowPlaying.isPlaying == false)

        handlers.play()
        #expect(controller.isPlaying)
        #expect(nowPlaying.isPlaying == true)
    }
}
