import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var catalog: CatalogStore

    var body: some View {
        Group {
            if catalog.albums.isEmpty {
                ContentUnavailableView(
                    "Library Empty",
                    systemImage: "square.stack",
                    description: Text(catalog.errorMessage ?? "The connected server has no albums.")
                )
            } else {
                List(catalog.albums) { album in
                    NavigationLink(value: album) {
                        HStack(spacing: 14) {
                            ArtworkView(style: album.artwork, cornerRadius: 12)
                                .frame(width: 64, height: 64)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(album.title).font(.headline)
                                Text("Album · \(album.artist.name)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
                .refreshable { await catalog.reload() }
            }
        }
        .navigationTitle("Library")
        .navigationDestination(for: Album.self) { AlbumView(album: $0) }
    }
}
