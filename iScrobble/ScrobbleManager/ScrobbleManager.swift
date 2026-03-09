import Foundation
import WidgetKit

@Observable
final class ScrobbleManager {

    private(set) var lastScrobbledTrack: Track?
    private(set) var scrobbleError: String?

    private let lastFMClient: LastFMClient
    private let storageManager: StorageManager
    private let statsManager: StatsManager

    private var currentTrack: Track?
    private var trackStartDate: Date?
    private var scrobbleTask: Task<Void, Never>?
    private var hasScrobbledCurrent = false
    private var lastScrobbledDate: Date?

    init(lastFMClient: LastFMClient, storageManager: StorageManager, statsManager: StatsManager) {
        self.lastFMClient = lastFMClient
        self.storageManager = storageManager
        self.statsManager = statsManager
    }

    func trackStarted(_ track: Track) {
        guard storageManager.scrobblingEnabled else { return }

        currentTrack = track
        trackStartDate = Date()

        let inReplayWindow: Bool
        if let lastDate = lastScrobbledDate,
           lastScrobbledTrack == track,
           Date().timeIntervalSince(lastDate) < max(track.duration, 30) {
            inReplayWindow = true
        } else {
            inReplayWindow = false
        }

        if inReplayWindow {
            print("[ScrobbleManager] Same track restarted within replay window — sending Now Playing but skipping reschedule")
        } else {
            hasScrobbledCurrent = false
            scrobbleError = nil
            scheduleScrobble(for: track)
        }

        sendNowPlaying(track)
        writeSharedState(track: track, isPlaying: true)
    }

    func trackStopped() {
        scrobbleTask?.cancel()
        scrobbleTask = nil
        writeSharedState(track: nil, isPlaying: false)
        currentTrack = nil
        trackStartDate = nil
    }

    func playbackStateChanged(isPlaying: Bool) {
        if let track = currentTrack {
            writeSharedState(track: track, isPlaying: isPlaying)
        }
    }

    private func sendNowPlaying(_ track: Track) {
        guard let sessionKey = storageManager.sessionKey else { return }
        Task {
            do {
                try await lastFMClient.updateNowPlaying(track: track, sessionKey: sessionKey)
            } catch {
                print("[ScrobbleManager] updateNowPlaying failed: \(error.localizedDescription)")
            }
        }
    }

    private func scheduleScrobble(for track: Track) {
        scrobbleTask?.cancel()

        let halfDuration = track.duration / 2
        let threshold = min(max(halfDuration, 30), 4 * 60)

        let startDate = Date()
        scrobbleTask = Task {
            try? await Task.sleep(for: .seconds(threshold))
            guard !Task.isCancelled else { return }
            await self.scrobbleIfEligible(track: track, startDate: startDate)
        }
    }

    private func scrobbleIfEligible(track: Track, startDate: Date) async {
        guard
            !hasScrobbledCurrent,
            currentTrack == track,
            storageManager.scrobblingEnabled,
            let sessionKey = storageManager.sessionKey
        else { return }

        hasScrobbledCurrent = true

        do {
            try await lastFMClient.scrobble(track: track, timestamp: startDate, sessionKey: sessionKey)
            lastScrobbledTrack = track
            lastScrobbledDate = Date()
            statsManager.recordScrobble(track: track)
            scrobbleError = nil
            writeSharedState(track: currentTrack, isPlaying: true)
            print("[ScrobbleManager] Scrobbled: \(track.artist) - \(track.title)")
        } catch {
            hasScrobbledCurrent = false
            scrobbleError = error.localizedDescription
            print("[ScrobbleManager] Scrobble failed: \(error.localizedDescription)")
        }
    }

    private func writeSharedState(track: Track?, isPlaying: Bool) {
        let state = NowPlayingState(
            artist: track?.artist ?? "",
            track: track?.title ?? "",
            album: track?.album ?? "",
            timestamp: Date().timeIntervalSince1970,
            isPlaying: isPlaying,
            artworkData: nil
        )
        storageManager.writeNowPlayingState(state)

        let widgetData = WidgetData(
            trackTitle: track?.title ?? "",
            trackArtist: track?.artist ?? "",
            trackAlbum: track?.album ?? "",
            isPlaying: isPlaying,
            lastUpdated: Date().timeIntervalSince1970,
            todayScrobbles: statsManager.todayScrobbles,
            totalScrobbles: statsManager.totalScrobbles,
            lastScrobbledTitle: lastScrobbledTrack?.title ?? "",
            lastScrobbledArtist: lastScrobbledTrack?.artist ?? ""
        )
        storageManager.writeWidgetData(widgetData)
        print("[ScrobbleManager] Requesting widget timeline reload")
        WidgetCenter.shared.reloadTimelines(ofKind: "iScrobbleWidget")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
