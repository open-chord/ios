import Foundation

struct Artist: Identifiable, Hashable {
    let id: UUID
    let name: String
}

struct Album: Identifiable, Hashable {
    let id: UUID
    let title: String
    let artist: Artist
    let year: Int
    let artwork: ArtworkStyle
    let tracks: [Track]

    var durationText: String {
        let seconds = tracks.reduce(0) { $0 + $1.duration }
        // TimeInterval является Double. Явное преобразование здесь важно:
        // пользователь ожидает "19 min", а не внутреннюю точность вычислений.
        let wholeMinutes = Int(seconds) / 60
        return "\(tracks.count) tracks · \(wholeMinutes) min"
    }
}

struct Track: Identifiable, Hashable {
    let id: UUID
    let title: String
    let artistName: String
    let albumTitle: String
    let duration: TimeInterval
    let audioSource: AudioSource
    let artwork: ArtworkStyle
    let lyrics: [LyricLine]
}

enum AudioSource: Hashable {
    case bundled(resource: String, fileExtension: String)
    case remote(URL)

    func url(in bundle: Bundle = .main) -> URL? {
        switch self {
        case let .bundled(resource, fileExtension):
            bundle.url(forResource: resource, withExtension: fileExtension)
        case let .remote(url):
            url
        }
    }
}

struct LyricLine: Identifiable, Hashable {
    let id: UUID
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
}

/// Пока обложки рисуются градиентами, поэтому проект запускается без ассетов.
/// В реальном клиенте это значение заменится URL обложки и состоянием загрузки.
struct ArtworkStyle: Hashable {
    let symbol: String
    let colors: [ArtworkColor]
}

enum ArtworkColor: String, Hashable {
    case violet, indigo, blue, cyan, mint, orange, pink, red

    var colorName: String { rawValue }
}
