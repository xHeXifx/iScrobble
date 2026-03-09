import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        let hasCredentials = StorageManager.shared.hasValidAPICredentials
        NSApp.setActivationPolicy(hasCredentials ? .accessory : .regular)
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        if StorageManager.shared.hasValidAPICredentials {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

@main
struct iScrobbleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(appState)
                .task { await appState.start() }
        } label: {
            MenuBarIconView(isPlaying: appState.playbackMonitor.isPlaying)
        }
        .menuBarExtraStyle(.window)
        
        Window("API Setup", id: "api-credentials") {
            APICredentialWindowView()
                .environment(appState)
                .onDisappear {
                    if appState.storage.hasValidAPICredentials {
                        NSApp.setActivationPolicy(.accessory)
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}


struct MenuBarIconView: View {
    let isPlaying: Bool

    var body: some View {
        Image(systemName: isPlaying ? "music.note" : "music.note.slash")
            .symbolRenderingMode(.hierarchical)
            .help(isPlaying ? "iScrobble — Now playing" : "iScrobble — Not playing")
    }
}
