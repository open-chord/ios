import Testing
@testable import OpenChord

@Suite("Simulated playback engine", .serialized)
@MainActor
struct SimulatedPlaybackEngineTests {
    @Test("Clock advances loaded media")
    func clockAdvancesLoadedMedia() {
        let clock = ManualPlaybackClock()
        let engine = SimulatedPlaybackEngine(clock: clock)
        let recorder = PlaybackEngineRecorder(engine: engine)

        engine.load(makeTrack(duration: 10), autoplay: true)
        clock.advance(by: 4)

        #expect(recorder.state.elapsed == 1)
        #expect(recorder.state.isPlaying)
    }

    @Test("Reaching the duration stops playback and emits finished")
    func reachingDurationFinishesPlayback() {
        let clock = ManualPlaybackClock()
        let engine = SimulatedPlaybackEngine(clock: clock)
        let recorder = PlaybackEngineRecorder(engine: engine)

        engine.load(makeTrack(duration: 0.5), autoplay: true)
        clock.advance(by: 2)

        #expect(recorder.state.elapsed == 0.5)
        #expect(!recorder.state.isPlaying)
        #expect(recorder.events == [.finished])
    }

    @Test("Seek clamps values to the loaded duration")
    func seekClampsValues() {
        let engine = SimulatedPlaybackEngine(clock: ManualPlaybackClock())
        let recorder = PlaybackEngineRecorder(engine: engine)
        engine.load(makeTrack(duration: 10), autoplay: false)

        engine.seek(to: -1)
        #expect(recorder.state.elapsed == 0)

        engine.seek(to: 12)
        #expect(recorder.state.elapsed == 10)
    }
}
