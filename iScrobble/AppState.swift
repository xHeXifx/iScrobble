import Foundation

@Observable
final class AppState {

    let storage: StorageManager
    let lastFMClient: LastFMClient
    let statsManager: StatsManager
    let scrobbleManager: ScrobbleManager
    let playbackMonitor: PlaybackMonitor

    init() {
        let storage = StorageManager.shared
        let client = LastFMClient(storageManager: storage)
        let stats = StatsManager(storageManager: storage)
        let monitor = PlaybackMonitor(lastFMClient: client)
        let scrobble = ScrobbleManager(lastFMClient: client, storageManager: storage, statsManager: stats)

        self.storage = storage
        self.lastFMClient = client
        self.statsManager = stats
        self.scrobbleManager = scrobble
        self.playbackMonitor = monitor

        monitor.onTrackStarted = { [weak scrobble] track in
            scrobble?.trackStarted(track)
        }
        monitor.onTrackStopped = { [weak scrobble] in
            scrobble?.trackStopped()
        }
        monitor.onPlaybackStateChanged = { [weak scrobble] isPlaying in
            scrobble?.playbackStateChanged(isPlaying: isPlaying)
        }
    }

    func start() async {
        await playbackMonitor.start()
    }
}
