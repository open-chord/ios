import SwiftUI

@main
struct OpenChordApp: App {
    // PlaybackController живёт на уровне приложения, потому что музыка не должна
    // останавливаться при переходе между вкладками или закрытии экрана альбома.
    // Позже этот объект станет фасадом над AVPlayer, но UI менять не придётся.
    @StateObject private var player = PlaybackController()
    @StateObject private var catalog = CatalogStore()
    @StateObject private var downloads = TrackDownloadStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(player)
                .environmentObject(catalog)
                .environmentObject(downloads)
                .preferredColorScheme(.dark)
        }
    }
}
