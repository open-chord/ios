import Combine
import Foundation

@MainActor
final class TrackDownloadStore: ObservableObject {
    enum State: Equatable {
        case idle
        case downloading
        case downloaded
        case failed
    }

    @Published private(set) var states: [UUID: State] = [:]
    @Published var errorMessage: String?

    private let session: URLSession
    private let downloadsDirectory: URL

    init(
        session: URLSession = .shared,
        fileManager: FileManager = .default,
        downloadsDirectory: URL? = nil
    ) {
        self.session = session
        let baseDirectory =
            downloadsDirectory
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "OpenChord/Downloads", directoryHint: .isDirectory)
        self.downloadsDirectory = baseDirectory
        try? fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
    }

    func state(for track: Track) -> State {
        if localURL(for: track) != nil {
            return .downloaded
        }
        return states[track.id] ?? .idle
    }

    func download(_ track: Track) async {
        guard state(for: track) != .downloading, localURL(for: track) == nil else { return }
        guard case let .remote(remoteURL) = track.audioSource else { return }

        states[track.id] = .downloading
        do {
            let (temporaryURL, response) = try await session.download(from: remoteURL)
            guard
                let httpResponse = response as? HTTPURLResponse,
                (200..<300).contains(httpResponse.statusCode)
            else {
                throw DownloadError.invalidResponse
            }

            let destination = destinationURL(for: track, response: httpResponse)
            if FileManager.default.fileExists(atPath: destination.path()) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: temporaryURL, to: destination)
            states[track.id] = .downloaded
        } catch {
            states[track.id] = .failed
            errorMessage = "Couldn’t download “\(track.title)”. \(error.localizedDescription)"
        }
    }

    func download(_ tracks: [Track]) async {
        for track in tracks where state(for: track) != .downloaded {
            await download(track)
        }
    }

    func playable(_ track: Track) -> Track {
        guard let localURL = localURL(for: track) else { return track }
        return track.using(audioSource: .remote(localURL))
    }

    func playable(_ tracks: [Track]) -> [Track] {
        tracks.map(playable)
    }

    private func localURL(for track: Track) -> URL? {
        let prefix = track.id.uuidString.lowercased() + "."
        return try? FileManager.default
            .contentsOfDirectory(at: downloadsDirectory, includingPropertiesForKeys: nil)
            .first { $0.lastPathComponent.lowercased().hasPrefix(prefix) }
    }

    private func destinationURL(for track: Track, response: HTTPURLResponse) -> URL {
        let responseExtension = response.url?.pathExtension
        let sourceExtension = track.audioSource.url()?.pathExtension
        let fileExtension =
            [responseExtension, sourceExtension, fileExtension(for: response.mimeType)]
            .compactMap { $0 }
            .first { !$0.isEmpty } ?? "m4a"
        return downloadsDirectory.appending(path: "\(track.id.uuidString.lowercased()).\(fileExtension)")
    }

    private func fileExtension(for mimeType: String?) -> String? {
        switch mimeType?.lowercased() {
        case "audio/mpeg": "mp3"
        case "audio/mp4", "audio/x-m4a": "m4a"
        case "audio/aac": "aac"
        case "audio/ogg": "ogg"
        case "audio/opus": "opus"
        case "audio/flac": "flac"
        case "audio/wav", "audio/x-wav": "wav"
        default: nil
        }
    }
}

private enum DownloadError: LocalizedError {
    case invalidResponse

    var errorDescription: String? {
        "The server returned an invalid response."
    }
}
