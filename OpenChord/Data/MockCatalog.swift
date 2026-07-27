import Foundation

/// Deterministic preview catalog that exercises populated and empty lyric states.
enum MockCatalog {
    private static let aurora = Artist(id: UUID(), name: "Aurora Lines")
    private static let atlas = Artist(id: UUID(), name: "The Midnight Atlas")

    static let albums: [Album] = [
        makeAlbum(
            title: "Afterglow",
            artist: aurora,
            year: 2026,
            artwork: ArtworkStyle(symbol: "sparkles", colors: [.violet, .pink, .orange]),
            trackNames: ["Night Drive", "Neon Rain", "Slow Satellites", "Afterglow", "Home Signal"]
        ),
        makeAlbum(
            title: "Northern Rooms",
            artist: atlas,
            year: 2025,
            artwork: ArtworkStyle(symbol: "moon.stars", colors: [.indigo, .blue, .cyan]),
            trackNames: ["Open Window", "Polar Light", "Quiet Maps", "Blue Hour"]
        ),
        makeAlbum(
            title: "Soft Collision",
            artist: aurora,
            year: 2024,
            artwork: ArtworkStyle(symbol: "waveform", colors: [.red, .pink, .violet]),
            trackNames: ["Particles", "Almost There", "Gravity", "A Smaller Sky"]
        ),
    ]

    static let recentlyPlayed = Array(albums.prefix(2))

    private static func makeAlbum(
        title: String,
        artist: Artist,
        year: Int,
        artwork: ArtworkStyle,
        trackNames: [String]
    ) -> Album {
        let tracks = trackNames.enumerated().map { index, name in
            Track(
                id: UUID(),
                title: name,
                artistName: artist.name,
                albumTitle: title,
                duration: 96,
                audioSource: .bundled(resource: "OpenChordDemo", fileExtension: "m4a"),
                artwork: artwork,
                // Only the lead demo track has synchronized lyrics so previews
                // exercise both the populated and honest empty states.
                lyrics: index == 0 && title == "Afterglow" ? demoLyrics : []
            )
        }
        return Album(id: UUID(), title: title, artist: artist, year: year, artwork: artwork, tracks: tracks)
    }

    private static let demoLyrics: [LyricLine] = [
        line("Streetlights drawing silver lines", 0, 8),
        line("The city breathes behind the glass", 8, 16),
        line("We let the quiet fill the space", 16, 24),
        line("And watch the empty stations pass", 24, 33),
        line("Stay with me into the afterglow", 33, 43),
        line("Where every signal turns to gold", 43, 52),
        line("No map, no reason to go home", 52, 61),
        line("Just one more story left untold", 61, 71),
        line("The morning waits beyond the road", 71, 82),
        line("But for a while we're not alone", 82, 94),
    ]

    private static func line(_ text: String, _ start: TimeInterval, _ end: TimeInterval) -> LyricLine {
        LyricLine(id: UUID(), text: text, startTime: start, endTime: end)
    }
}
