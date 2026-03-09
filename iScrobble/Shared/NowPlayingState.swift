import Foundation

struct NowPlayingState: Codable {
    var artist: String
    var track: String
    var album: String
    var timestamp: TimeInterval
    var isPlaying: Bool
    var artworkData: Data?

    static let empty = NowPlayingState(
        artist: "",
        track: "",
        album: "",
        timestamp: 0,
        isPlaying: false,
        artworkData: nil
    )
}
