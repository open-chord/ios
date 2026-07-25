import Foundation
import Testing
@testable import OpenChord

@Suite("Album presentation")
struct AlbumTests {
    @Test("Duration uses whole minutes instead of exposing floating-point precision")
    func durationTextUsesWholeMinutes() {
        let artist = Artist(id: UUID(), name: "Test Artist")
        let album = Album(
            id: UUID(),
            title: "Test Album",
            artist: artist,
            year: 2026,
            artwork: ArtworkStyle(symbol: "music.note", colors: [.blue]),
            tracks: [
                makeTrack(duration: 196),
                makeTrack(duration: 213),
            ]
        )

        #expect(album.durationText == "2 tracks · 6 min")
    }

    @Test("An empty album has a stable presentation")
    func emptyAlbumDurationText() {
        let album = Album(
            id: UUID(),
            title: "Empty Album",
            artist: Artist(id: UUID(), name: "Test Artist"),
            year: 2026,
            artwork: ArtworkStyle(symbol: "music.note", colors: [.blue]),
            tracks: []
        )

        #expect(album.durationText == "0 tracks · 0 min")
    }
}
