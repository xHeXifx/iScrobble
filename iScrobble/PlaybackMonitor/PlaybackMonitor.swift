import Foundation

@Observable
final class PlaybackMonitor {

    private(set) var currentTrack: Track?
    private(set) var isPlaying: Bool = false
    private(set) var playbackElapsed: TimeInterval = 0

    var onTrackStarted: ((Track) -> Void)?
    var onTrackStopped: (() -> Void)?
    var onPlaybackStateChanged: ((Bool) -> Void)?

    private var observer: NSObjectProtocol?
    private var lastTrackID: String?

    func start() async {
        print("[PlaybackMonitor] Registering observer for 'com.apple.Music.playerInfo'")
        observer = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleNotification(notification)
        }
        print("[PlaybackMonitor] Observer registered — waiting for Music.app events")
    }

    func stop() {
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
            self.observer = nil
            print("[PlaybackMonitor] Observer removed")
        }
    }

    private func handleNotification(_ notification: Notification) {
        let info = notification.userInfo ?? [:]
        print("[PlaybackMonitor] Received notification — userInfo: \(info)")

        let playerState = info["Player State"] as? String ?? ""
        print("[PlaybackMonitor] Player State: \"\(playerState)\"")

        if playerState == "Stopped" {
            if currentTrack != nil {
                currentTrack = nil
                lastTrackID = nil
                print("[PlaybackMonitor] Track stopped")
                onTrackStopped?()
            }
            if isPlaying {
                isPlaying = false
                onPlaybackStateChanged?(false)
            }
            playbackElapsed = 0
            return
        }

        let newIsPlaying = playerState == "Playing"
        let title  = info["Name"] as? String ?? ""
        let artist = info["Artist"] as? String ?? ""
        let album  = info["Album"] as? String ?? ""
        let totalTimeMs = info["Total Time"] as? Double ?? 0
        let duration = totalTimeMs / 1000.0
        let elapsed  = info["Player Position"] as? Double ?? 0

        print("[PlaybackMonitor] Parsed — title: \"\(title)\" | artist: \"\(artist)\" | album: \"\(album)\" | duration: \(String(format: "%.1f", duration))s | elapsed: \(String(format: "%.1f", elapsed))s | state: \(playerState)")

        guard !title.isEmpty else {
            print("[PlaybackMonitor] Empty title — ignoring notification")
            return
        }

        let trackID = "\(artist)-\(title)"
        if trackID != lastTrackID {
            lastTrackID = trackID
            let track = Track(
                id: trackID,
                title: title,
                artist: artist,
                album: album,
                duration: duration
            )
            currentTrack = track
            print("[PlaybackMonitor] Track changed → \"\(artist) — \(title)\"")
            onTrackStarted?(track)
        }

        if newIsPlaying != isPlaying {
            isPlaying = newIsPlaying
            print("[PlaybackMonitor] Playback state → \(newIsPlaying ? "playing" : "paused/stopped")")
            onPlaybackStateChanged?(newIsPlaying)
        }

        playbackElapsed = elapsed
    }
}
