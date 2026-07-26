import Foundation

/// An artist identity shared by one or more albums.
struct Artist: Identifiable, Hashable {
    /// Stable server identifier.
    let id: UUID
    /// Name displayed throughout the client.
    let name: String
}

/// An album aggregate with ordered tracks and one visual identity.
struct Album: Identifiable, Hashable {
    /// Stable server identifier.
    let id: UUID
    /// Album display title.
    let title: String
    /// Album artist.
    let artist: Artist
    /// Release year.
    let year: Int
    /// Remote artwork and generated fallback presentation.
    let artwork: ArtworkStyle
    /// Tracks in server-defined disc and track order.
    let tracks: [Track]

    /// Localized-ready compact summary of track count and total duration.
    var durationText: String {
        let seconds = tracks.reduce(0) { $0 + $1.duration }
        // The UI presents whole listening minutes rather than floating-point precision.
        let wholeMinutes = Int(seconds) / 60
        return "\(tracks.count) tracks · \(wholeMinutes) min"
    }
}

/// A playable catalog item with artwork and optional synchronized lyrics.
struct Track: Identifiable, Hashable {
    /// Stable server identifier used for downloads and playback reporting.
    let id: UUID
    /// Track display title.
    let title: String
    /// Denormalized artist name for lightweight player presentation.
    let artistName: String
    /// Denormalized album title for lightweight player presentation.
    let albumTitle: String
    /// Playback duration in seconds.
    let duration: TimeInterval
    /// Bundled, remote, or downloaded media location.
    let audioSource: AudioSource
    /// Album artwork shared with player surfaces.
    let artwork: ArtworkStyle
    /// Timestamp-ordered synchronized lyrics.
    let lyrics: [LyricLine]

    /// Returns an immutable copy that resolves playback through a different media source.
    func using(audioSource: AudioSource) -> Track {
        Track(
            id: id,
            title: title,
            artistName: artistName,
            albumTitle: albumTitle,
            duration: duration,
            audioSource: audioSource,
            artwork: artwork,
            lyrics: lyrics
        )
    }
}

/// Location from which a playback engine can resolve audio data.
enum AudioSource: Hashable {
    /// Resource shipped inside the application bundle.
    case bundled(resource: String, fileExtension: String)
    /// HTTP stream or downloaded local file URL.
    case remote(URL)

    /// Resolves the source to a concrete URL in the supplied bundle.
    func url(in bundle: Bundle = .main) -> URL? {
        switch self {
        case let .bundled(resource, fileExtension):
            bundle.url(forResource: resource, withExtension: fileExtension)
        case let .remote(url):
            url
        }
    }
}

/// One lyric segment active between two playback timestamps.
struct LyricLine: Identifiable, Hashable {
    /// Stable server identifier.
    let id: UUID
    /// Text displayed while this segment is active.
    let text: String
    /// Inclusive start time in seconds.
    let startTime: TimeInterval
    /// Exclusive end time in seconds.
    let endTime: TimeInterval
}

/// Artwork source plus deterministic fallback styling for unavailable images.
struct ArtworkStyle: Hashable {
    /// SF Symbol rendered by the fallback artwork.
    let symbol: String
    /// Gradient palette rendered by the fallback artwork.
    let colors: [ArtworkColor]
    /// Optional server artwork URL.
    let remoteURL: URL?

    /// Creates an artwork presentation with an optional remote image.
    init(symbol: String, colors: [ArtworkColor], remoteURL: URL? = nil) {
        self.symbol = symbol
        self.colors = colors
        self.remoteURL = remoteURL
    }
}

/// Semantic colors available to deterministic artwork fallbacks.
enum ArtworkColor: String, Hashable {
    case violet, indigo, blue, cyan, mint, orange, pink, red

    /// Stable name useful for serialization or diagnostics.
    var colorName: String { rawValue }
}
