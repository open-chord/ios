import SwiftUI

@main
struct OpenChordApp: App {
    // PlaybackController живёт на уровне приложения, потому что музыка не должна
    // останавливаться при переходе между вкладками или закрытии экрана альбома.
    // Позже этот объект станет фасадом над AVPlayer, но UI менять не придётся.
    @StateObject private var player = PlaybackController()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(player)
                .preferredColorScheme(.dark)
        }
    }
}
