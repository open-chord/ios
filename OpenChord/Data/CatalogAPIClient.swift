import Foundation

protocol CatalogLoading: Sendable {
    func fetchAlbums(from serverURL: URL) async throws -> [Album]
}

struct CatalogAPIClient: CatalogLoading {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchAlbums(from serverURL: URL) async throws -> [Album] {
        let endpoint = serverURL.appending(path: "graphql")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 12
        request.httpBody = try JSONEncoder().encode(
            GraphQLRequest(
                query: """
                    query OpenChordCatalog {
                      albums {
                        id
                        title
                        year
                        artworkUrl
                        artist { id name }
                        tracks {
                          id
                          title
                          durationMs
                          artistName
                          albumTitle
                          streamUrl
                          lyrics { id text startMs endMs }
                        }
                      }
                    }
                    """
            )
        )

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CatalogAPIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw CatalogAPIError.httpStatus(httpResponse.statusCode)
        }

        let envelope = try JSONDecoder().decode(GraphQLEnvelope<CatalogPayload>.self, from: data)
        if let message = envelope.errors?.first?.message {
            throw CatalogAPIError.graphQL(message)
        }
        guard let payload = envelope.data else {
            throw CatalogAPIError.invalidResponse
        }
        return payload.albums.map { $0.album(relativeTo: serverURL) }
    }
}

enum CatalogAPIError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)
    case graphQL(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "The server returned an invalid response."
        case let .httpStatus(status):
            "The server returned HTTP \(status)."
        case let .graphQL(message):
            message
        }
    }
}

private struct GraphQLRequest: Encodable {
    let query: String
}

private struct GraphQLEnvelope<Payload: Decodable>: Decodable {
    let data: Payload?
    let errors: [GraphQLError]?
}

private struct GraphQLError: Decodable {
    let message: String
}

private struct CatalogPayload: Decodable {
    let albums: [AlbumDTO]
}

private struct ArtistDTO: Decodable {
    let id: UUID
    let name: String
}

private struct AlbumDTO: Decodable {
    let id: UUID
    let title: String
    let year: Int
    let artworkUrl: String?
    let artist: ArtistDTO
    let tracks: [TrackDTO]

    func album(relativeTo serverURL: URL) -> Album {
        let style = ArtworkStyle.forAlbum(id)
        return Album(
            id: id,
            title: title,
            artist: Artist(id: artist.id, name: artist.name),
            year: year,
            artwork: style,
            tracks: tracks.map { $0.track(relativeTo: serverURL, artwork: style) }
        )
    }
}

private struct TrackDTO: Decodable {
    let id: UUID
    let title: String
    let durationMs: Int64
    let artistName: String
    let albumTitle: String
    let streamUrl: String
    let lyrics: [LyricLineDTO]

    func track(relativeTo serverURL: URL, artwork: ArtworkStyle) -> Track {
        let mediaURL =
            URL(string: streamUrl).map { serverURL.replacingPath(with: $0) }
            ?? serverURL.appending(path: "media/tracks/\(id.uuidString)")
        return Track(
            id: id,
            title: title,
            artistName: artistName,
            albumTitle: albumTitle,
            duration: TimeInterval(durationMs) / 1_000,
            audioSource: .remote(mediaURL),
            artwork: artwork,
            lyrics: lyrics.map(\.lyricLine)
        )
    }
}

private struct LyricLineDTO: Decodable {
    let id: UUID
    let text: String
    let startMs: Int64
    let endMs: Int64

    var lyricLine: LyricLine {
        LyricLine(
            id: id,
            text: text,
            startTime: TimeInterval(startMs) / 1_000,
            endTime: TimeInterval(endMs) / 1_000
        )
    }
}

private extension URL {
    func replacingPath(with remoteURL: URL) -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return remoteURL
        }
        components.path = remoteURL.path
        components.query = remoteURL.query
        return components.url ?? remoteURL
    }
}

private extension ArtworkStyle {
    static func forAlbum(_ id: UUID) -> ArtworkStyle {
        let variants: [ArtworkStyle] = [
            ArtworkStyle(symbol: "sparkles", colors: [.violet, .pink, .orange]),
            ArtworkStyle(symbol: "moon.stars.fill", colors: [.indigo, .blue, .cyan]),
            ArtworkStyle(symbol: "waveform", colors: [.red, .pink, .violet]),
            ArtworkStyle(symbol: "music.note", colors: [.blue, .cyan, .mint]),
        ]
        let index = id.uuidString.utf8.reduce(0) { $0 + Int($1) } % variants.count
        return variants[index]
    }
}
