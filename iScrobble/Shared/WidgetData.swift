import Foundation

struct WidgetData: Codable {
    var trackTitle: String = ""
    var trackArtist: String = ""
    var trackAlbum: String = ""
    var albumArtFileName: String? = nil
    var isPlaying: Bool = false
    var lastUpdated: TimeInterval = 0
    var todayScrobbles: Int = 0
    var totalScrobbles: Int = 0
    var lastScrobbledTitle: String = ""
    var lastScrobbledArtist: String = ""
}
