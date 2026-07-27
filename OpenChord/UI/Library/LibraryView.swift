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
    }

    private var header: some View {
        Text("Library")
            .font(.largeTitle.bold())
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 16)
    }

    private var libraryContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                controls

                if visibleAlbums.isEmpty {
                    ContentUnavailableView(
                        "No Downloaded Albums",
                        systemImage: "arrow.down.circle",
                        description: Text("Download an album to make it available offline.")
                    )
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
        let filtered = catalog.albums.filter { album in
            filter == .all || isDownloaded(album)
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

/// Compact album grid card with an unobtrusive offline-availability badge.
struct AlbumCard: View {
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
