import Combine
import Foundation

@MainActor
final class CatalogStore: ObservableObject {
    static let serverURLKey = "openchord.serverURL"
    static let defaultServerAddress = "http://localhost:8080"

    @Published private(set) var albums: [Album] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var serverURL: URL

    private let loader: any CatalogLoading
    private let defaults: UserDefaults
    private var hasLoaded = false

    init(
        loader: any CatalogLoading = CatalogAPIClient(),
        defaults: UserDefaults = .standard
    ) {
        self.loader = loader
        self.defaults = defaults
        let storedAddress = defaults.string(forKey: Self.serverURLKey) ?? Self.defaultServerAddress
        serverURL =
            Self.normalizedURL(from: storedAddress)
            ?? URL(string: Self.defaultServerAddress)!
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await reload()
    }

    func reload() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            albums = try await loader.fetchAlbums(from: serverURL)
            hasLoaded = true
        } catch {
            errorMessage = Self.userFacingMessage(for: error)
        }
    }

    func updateServerAddress(_ address: String) async throws {
        guard let url = Self.normalizedURL(from: address) else {
            throw ServerAddressError.invalid
        }
        serverURL = url
        defaults.set(url.absoluteString, forKey: Self.serverURLKey)
        hasLoaded = false
        albums = []
        await reload()
    }

    static func normalizedURL(from address: String) -> URL? {
        var value = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if !value.contains("://") {
            value = "http://\(value)"
        }
        guard
            var components = URLComponents(string: value),
            components.scheme == "http" || components.scheme == "https",
            components.host != nil
        else { return nil }
        components.path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard components.path.isEmpty else { return nil }
        return components.url
    }

    private static func userFacingMessage(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet:
                return
                    "Cannot reach the OpenChord server. Check its address and make sure both devices are on the same network."
            case .timedOut:
                return "The OpenChord server did not respond in time."
            default:
                break
            }
        }
        return error.localizedDescription
    }
}

enum ServerAddressError: LocalizedError {
    case invalid

    var errorDescription: String? {
        "Enter a valid HTTP or HTTPS server address without a path."
    }
}
