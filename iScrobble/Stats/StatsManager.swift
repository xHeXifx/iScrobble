import Foundation

struct DailyStats: Codable {
    let date: String
    var scrobbleCount: Int
}

struct ScrobbledTrack: Codable {
    let title: String
    let artist: String
    let album: String
    let timestamp: Date
}

struct ListeningStats: Codable {
    var totalScrobbles: Int = 0
    var dailyStats: [DailyStats] = []
    var recentTracks: [ScrobbledTrack] = []

    var todayScrobbles: Int {
        let today = Self.todayString
        return dailyStats.first(where: { $0.date == today })?.scrobbleCount ?? 0
    }

    private static var todayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    mutating func updateTotalScrobbles(_ total: Int) {
        totalScrobbles = total
    }

    mutating func record(track: Track) {
        let today = Self.todayString
        if let index = dailyStats.firstIndex(where: { $0.date == today }) {
            dailyStats[index].scrobbleCount += 1
        } else {
            dailyStats.append(DailyStats(date: today, scrobbleCount: 1))
            if dailyStats.count > 30 {
                dailyStats.removeFirst(dailyStats.count - 30)
            }
        }

        let scrobbled = ScrobbledTrack(
            title: track.title,
            artist: track.artist,
            album: track.album,
            timestamp: Date()
        )
        recentTracks.insert(scrobbled, at: 0)
        if recentTracks.count > 50 {
            recentTracks.removeLast()
        }
    }
}

@Observable
final class StatsManager {

    private(set) var stats = ListeningStats()

    private let storageManager: StorageManager
    private var fileURL: URL? { storageManager.appSupportFileURL(named: "stats.json") }

    init(storageManager: StorageManager) {
        self.storageManager = storageManager
        load()
    }

    var totalScrobbles: Int { stats.totalScrobbles }
    var todayScrobbles: Int { stats.todayScrobbles }
    var recentTracks: [ScrobbledTrack] { stats.recentTracks }

    func recordScrobble(track: Track) {
        stats.record(track: track)
        save()
    }

    func updateTotalFromLastFM(_ total: Int) {
        print("[StatsManager] Updating total scrobbles from Last.fm: \(total)")
        stats.updateTotalScrobbles(total)
        save()
    }

    private func load() {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return }
        if let loaded = try? JSONDecoder().decode(ListeningStats.self, from: data) {
            stats = loaded
        }
    }

    private func save() {
        guard let url = fileURL, let data = try? JSONEncoder().encode(stats) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
