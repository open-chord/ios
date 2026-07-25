import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var catalog: CatalogStore
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 18)]

    var body: some View {
        Group {
            if catalog.isLoading && catalog.albums.isEmpty {
                ProgressView("Loading your library…")
            } else if let error = catalog.errorMessage, catalog.albums.isEmpty {
                ContentUnavailableView {
                    Label("Server Unavailable", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(error)
                } actions: {
                    Button("Try Again") {
                        Task { await catalog.reload() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if catalog.albums.isEmpty {
                ContentUnavailableView(
                    "No Music Yet",
                    systemImage: "music.note.list",
                    description: Text("The connected server has no albums.")
                )
            } else {
                catalogContent
            }
        }
        .background(Color.black)
        .navigationTitle("OpenChord")
        .navigationDestination(for: Album.self) { AlbumView(album: $0) }
    }

    private var catalogContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if let featured = catalog.albums.first {
                    hero(featured)
                }

                Text("Your library")
                    .font(.title2.bold())
                LazyVGrid(columns: columns, alignment: .leading, spacing: 24) {
                    ForEach(catalog.albums) { album in
                        NavigationLink(value: album) {
                            AlbumCard(album: album)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .refreshable { await catalog.reload() }
    }

    private func hero(_ album: Album) -> some View {
        ZStack(alignment: .bottomLeading) {
            ArtworkView(style: album.artwork, cornerRadius: 30)

            LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text("FEATURED ALBUM").font(.caption.bold()).tracking(1.5)
                Text(album.title).font(.largeTitle.bold())
                Text(album.artist.name).foregroundStyle(.secondary)
            }
            .padding(24)
        }
    }
}

private struct AlbumCard: View {
    let album: Album

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ArtworkView(style: album.artwork, cornerRadius: 18)
            Text(album.title).font(.headline).lineLimit(1)
            Text(album.artist.name).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
        }
    }
}
