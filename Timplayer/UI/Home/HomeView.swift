import SwiftUI

struct HomeView: View {
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 18)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                hero

                Text("Made for late nights")
                    .font(.title2.bold())

                LazyVGrid(columns: columns, alignment: .leading, spacing: 24) {
                    ForEach(MockCatalog.albums) { album in
                        NavigationLink(value: album) {
                            AlbumCard(album: album)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .background(Color.black)
        .navigationTitle("Timplayer")
        .navigationDestination(for: Album.self) { AlbumView(album: $0) }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            ArtworkView(style: MockCatalog.albums[0].artwork, cornerRadius: 30)

            LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text("FEATURED ALBUM").font(.caption.bold()).tracking(1.5)
                Text(MockCatalog.albums[0].title).font(.largeTitle.bold())
                Text(MockCatalog.albums[0].artist.name).foregroundStyle(.secondary)
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
