import Testing
@testable import OpenChord

@Suite("Playback state", .serialized)
@MainActor
struct PlaybackControllerTests {
    @Test("Play selects a track and starts playback")
    func playSelectsTrack() {
        let clock = ManualPlaybackClock()
        let track = makeTrack()
        let controller = PlaybackController(clock: clock)

        controller.play(track: track, in: [track])

        #expect(controller.currentTrack == track)
        #expect(controller.queue == [track])
        #expect(controller.isPlaying)
        #expect(controller.elapsed == 0)
    }

    @Test("The injected clock advances playback deterministically")
    func clockAdvancesElapsedTime() {
        let clock = ManualPlaybackClock()
        let track = makeTrack(duration: 10)
        let controller = PlaybackController(clock: clock)
        controller.play(track: track, in: [track])

        clock.advance(by: 4)

        #expect(controller.elapsed == 1)
        #expect(controller.progress == 0.1)
    }

    @Test("Seek clamps values to the playable range")
    func seekClampsToTrackDuration() {
        let track = makeTrack(duration: 10)
        let controller = PlaybackController(clock: ManualPlaybackClock())
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
        let controller = PlaybackController(clock: ManualPlaybackClock())
        controller.play(track: second, in: [first, second])

        controller.playNext()

        #expect(controller.currentTrack == first)
        #expect(controller.elapsed == 0)
    }

    @Test("Previous restarts a track after four seconds")
    func previousRestartsCurrentTrack() {
        let first = makeTrack(title: "First")
        let second = makeTrack(title: "Second")
        let controller = PlaybackController(clock: ManualPlaybackClock())
        controller.play(track: second, in: [first, second])
        controller.seek(to: 5)

        controller.playPrevious()

        #expect(controller.currentTrack == second)
        #expect(controller.elapsed == 0)
    }
}
