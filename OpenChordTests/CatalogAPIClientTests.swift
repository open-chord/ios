import Foundation
import Testing
@testable import OpenChord

@Suite("Catalog API client")
struct CatalogAPIClientTests {
    @Test("Decodes the catalog and anchors media URLs to the configured LAN server")
    func decodesCatalogAndAnchorsMediaURL() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CatalogURLProtocol.self]
        let client = CatalogAPIClient(session: URLSession(configuration: configuration))
        let serverURL = try #require(URL(string: "http://192.168.1.20:8080"))

        let albums = try await client.fetchAlbums(from: serverURL)
        let album = try #require(albums.first)
        let track = try #require(album.tracks.first)

        #expect(album.title == "Afterglow")
        #expect(track.lyrics.first?.text == "Streetlights drawing silver lines")
        #expect(track.duration == 96)
        #expect(track.audioSource.url()?.absoluteString == "http://192.168.1.20:8080/media/tracks/track")
        #expect(album.artwork.remoteURL?.absoluteString == "http://192.168.1.20:8080/media/artwork/cover")
    }

    @Test(
        "Normalizes common local server addresses",
        arguments: [
            ("192.168.1.20:8080", "http://192.168.1.20:8080"),
            ("http://openchord.local:8080/", "http://openchord.local:8080"),
            ("https://music.example.com", "https://music.example.com"),
        ]
    )
    @MainActor
    func normalizesServerAddress(input: String, expected: String) {
        #expect(CatalogStore.normalizedURL(from: input)?.absoluteString == expected)
    }
}

private final class CatalogURLProtocol: URLProtocol, @unchecked Sendable {
    private static let response = """
        {
          "data": {
            "albums": [{
              "id": "20000000-0000-0000-0000-000000000001",
              "title": "Afterglow",
              "year": 2026,
              "artworkUrl": "http://localhost:8080/media/artwork/cover",
              "artist": {
                "id": "10000000-0000-0000-0000-000000000001",
                "name": "Aurora Lines"
              },
              "tracks": [{
                "id": "30000000-0000-0000-0000-000000000001",
                "title": "Night Drive",
                "durationMs": 96000,
                "artistName": "Aurora Lines",
                "albumTitle": "Afterglow",
                "streamUrl": "http://localhost:8080/media/tracks/track",
                "lyrics": [{
                  "id": "40000000-0000-0000-0000-000000000001",
                  "text": "Streetlights drawing silver lines",
                  "startMs": 0,
                  "endMs": 8000
                }]
              }]
            }]
          }
        }
        """.data(using: .utf8)!

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.path == "/graphql"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.response)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
