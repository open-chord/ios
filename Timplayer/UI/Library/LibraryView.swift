import SwiftUI

struct LibraryView: View {
    var body: some View {
        List(MockCatalog.albums) { album in
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
        .navigationTitle("Library")
        .navigationDestination(for: Album.self) { AlbumView(album: $0) }
    }
}
