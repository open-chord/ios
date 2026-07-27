import SwiftUI

/// Searchable, filterable entry point for the user's album collection.
struct LibraryView: View {
    private enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case downloaded = "Downloaded"

        var id: Self { self }
    }

    private enum SortOrder: String, CaseIterable, Identifiable {
        case recentlyAdded = "Recently Added"
        case album = "Album"
        case artist = "Artist"

        var id: Self { self }
    }

    @EnvironmentObject private var catalog: CatalogStore
    @EnvironmentObject private var downloads: TrackDownloadStore
    @State private var filter: Filter = .all
    @State private var sortOrder: SortOrder = .recentlyAdded
    @State private var searchText = ""

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]
    let onOpenServerSettings: () -> Void

    init(onOpenServerSettings: @escaping () -> Void = {}) {
        self.onOpenServerSettings = onOpenServerSettings
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Group {
                if catalog.isLoading && catalog.albums.isEmpty {
                    ProgressView("Loading your library…")
                        .frame(maxHeight: .infinity)
                } else if let error = catalog.errorMessage, catalog.albums.isEmpty {
                    unavailableContent(error)
                        .frame(maxHeight: .infinity)
                } else if catalog.albums.isEmpty {
                    ContentUnavailableView(
                        "Library Empty",
                        systemImage: "square.stack",
                        description: Text("The connected server has no albums.")
                    )
                    .frame(maxHeight: .infinity)
                } else {
                    libraryContent
                }
            }
        }
        .background(Color.black)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: Album.self) { AlbumView(album: $0) }
        .searchable(text: $searchText, prompt: "Albums or artists")
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Library")
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)

            Spacer()

            Button {
                onOpenServerSettings()
            } label: {
                ServerStatusIcon(state: catalog.connectionState)
            }
            .accessibilityIdentifier("serverSettings")
            .accessibilityLabel(serverAccessibilityLabel)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private var serverAccessibilityLabel: String {
        switch catalog.connectionState {
        case .unknown: "Server settings"
        case .connecting: "Connecting to server"
        case .connected: "Server connected"
        case .unavailable: "Server unavailable"
        }
    }

    private var libraryContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                controls

                if visibleAlbums.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                } else {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 24) {
                        ForEach(visibleAlbums) { album in
                            NavigationLink(value: album) {
                                AlbumCard(
                                    album: album,
                                    isDownloaded: isDownloaded(album)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .refreshable { await catalog.reload() }
    }

    private var controls: some View {
        HStack {
            Picker("Library filter", selection: $filter) {
                ForEach(Filter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            Menu {
                Picker("Sort albums", selection: $sortOrder) {
                    ForEach(SortOrder.allCases) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .frame(width: 34, height: 34)
            }
            .accessibilityLabel("Sort albums")
        }
    }

    private var visibleAlbums: [Album] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = catalog.albums.filter { album in
            let matchesDownload = filter == .all || isDownloaded(album)
            let matchesSearch =
                query.isEmpty
                || album.title.localizedCaseInsensitiveContains(query)
                || album.artist.name.localizedCaseInsensitiveContains(query)
            return matchesDownload && matchesSearch
        }

        return filtered.sorted { first, second in
            switch sortOrder {
            case .recentlyAdded:
                if first.year != second.year {
                    return first.year > second.year
                }
                return first.title.localizedStandardCompare(second.title) == .orderedAscending
            case .album:
                return first.title.localizedStandardCompare(second.title) == .orderedAscending
            case .artist:
                let artistOrder = first.artist.name.localizedStandardCompare(second.artist.name)
                if artistOrder != .orderedSame {
                    return artistOrder == .orderedAscending
                }
                return first.title.localizedStandardCompare(second.title) == .orderedAscending
            }
        }
    }

    private func isDownloaded(_ album: Album) -> Bool {
        !album.tracks.isEmpty
            && album.tracks.allSatisfy { downloads.state(for: $0) == .downloaded }
    }

    private func unavailableContent(_ error: String) -> some View {
        ContentUnavailableView {
            Label("Server Unavailable", systemImage: "wifi.exclamationmark")
        } description: {
            Text(error)
        } actions: {
            Button("Server Settings", systemImage: "server.rack") {
                onOpenServerSettings()
            }
            .buttonStyle(.borderedProminent)

            Button("Try Again") {
                Task { await catalog.reload() }
            }
            .buttonStyle(.bordered)
        }
    }
}

/// Server glyph with a compact, semantic connection-state badge.
private struct ServerStatusIcon: View {
    let state: CatalogStore.ConnectionState

    var body: some View {
        Image(systemName: "server.rack")
            .frame(width: 30, height: 30)
            .overlay(alignment: .bottomTrailing) {
                statusBadge
                    .offset(x: 4, y: 4)
            }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch state {
        case .unknown:
            EmptyView()
        case .connecting:
            ProgressView()
                .controlSize(.mini)
                .padding(2)
                .background(.black, in: Circle())
        case .connected:
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.white, .green)
                .background(.black, in: Circle())
        case .unavailable:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.white, .red)
                .background(.black, in: Circle())
        }
    }
}

/// Compact album grid card with an unobtrusive offline-availability badge.
private struct AlbumCard: View {
    let album: Album
    let isDownloaded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ArtworkView(style: album.artwork, cornerRadius: 16)
                .aspectRatio(1, contentMode: .fit)
                .overlay(alignment: .bottomTrailing) {
                    if isDownloaded {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.65))
                            .padding(8)
                    }
                }

            Text(album.title)
                .font(.headline)
                .lineLimit(1)
            Text(album.artist.name)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
