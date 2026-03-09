import WidgetKit
import SwiftUI
import AppKit
import os

private let logger = Logger(subsystem: "com.hexif.iScrobble.widget", category: "Timeline")

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

struct iScrobbleEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

private func loadAlbumArt(fileName: String?) -> NSImage? {
    guard let fileName = fileName,
          let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.hexif.iScrobble") else {
        return nil
    }
    let fileURL = containerURL.appendingPathComponent(fileName)
    guard let data = try? Data(contentsOf: fileURL) else {
        return nil
    }
    return NSImage(data: data)
}

struct iScrobbleProvider: TimelineProvider {
    private let appGroupID = "group.com.hexif.iScrobble"

    func placeholder(in context: Context) -> iScrobbleEntry {
        logger.error("placeholder called")
        return iScrobbleEntry(date: .now, data: WidgetData(
            trackTitle: "Track Title",
            trackArtist: "Artist Name",
            trackAlbum: "Album",
            isPlaying: true,
            lastUpdated: Date().timeIntervalSince1970,
            todayScrobbles: 12,
            totalScrobbles: 1024,
            lastScrobbledTitle: "Previous Track",
            lastScrobbledArtist: "Artist"
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (iScrobbleEntry) -> Void) {
        logger.error("getSnapshot called")
        let data = load()
        completion(iScrobbleEntry(date: .now, data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<iScrobbleEntry>) -> Void) {
        logger.error("getTimeline called")
        let data = load()
        let entry = iScrobbleEntry(date: .now, data: data)
        let next = Calendar.current.date(byAdding: .minute, value: 5, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func load() -> WidgetData {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            logger.error("Could not access UserDefaults suite — App Groups not provisioned correctly")
            return WidgetData()
        }
        guard let data = defaults.data(forKey: "widgetData") else {
            logger.error("No widgetData key in UserDefaults suite (app may not have run yet)")
            return WidgetData()
        }
        guard let decoded = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            logger.error("Failed to decode WidgetData from UserDefaults")
            return WidgetData()
        }
        logger.error("Loaded — track: '\(decoded.trackTitle)' by '\(decoded.trackArtist)', isPlaying: \(decoded.isPlaying), today: \(decoded.todayScrobbles), total: \(decoded.totalScrobbles)")
        return decoded
    }
}

struct iScrobbleWidget: Widget {
    let kind = "iScrobbleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: iScrobbleProvider()) { entry in
            iScrobbleWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("iScrobble")
        .description("Current track and listening stats from Last.fm.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct iScrobbleWidgetView: View {
    let entry: iScrobbleEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:  SmallWidgetView(data: entry.data)
        default:            MediumWidgetView(data: entry.data)
        }
    }
}

private struct SmallWidgetView: View {
    let data: WidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "music.note")
                    .font(.caption2)
                    .foregroundStyle(.tint)
                Text("iScrobble")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tint)
                Spacer()
            }

            Spacer()

            if !data.trackTitle.isEmpty {
                if let albumArt = loadAlbumArt(fileName: data.albumArtFileName) {
                    Image(nsImage: albumArt)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .padding(.bottom, 4)
                } else {
                    Image(systemName: data.isPlaying ? "play.circle.fill" : "pause.circle.fill")
                        .font(.title2)
                        .foregroundStyle(data.isPlaying ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                        .padding(.bottom, 4)
                }
                Text(data.trackTitle)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                Text(data.trackArtist)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Image(systemName: "music.note.list")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 4)
                Text("Nothing playing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack {
                ScrobbleCount(value: "\(data.todayScrobbles)", label: "today")
                Spacer()
                ScrobbleCount(value: "\(data.totalScrobbles)", label: "total")
            }
        }
        .padding(14)
    }
}

private struct MediumWidgetView: View {
    let data: WidgetData

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Label("Now Playing", systemImage: "music.note")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tint)

                Spacer()

                if !data.trackTitle.isEmpty {
                    if let albumArt = loadAlbumArt(fileName: data.albumArtFileName) {
                        Image(nsImage: albumArt)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 65, height: 65)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(.bottom, 6)
                    } else {
                        Image(systemName: data.isPlaying ? "play.circle.fill" : "pause.circle.fill")
                            .font(.title)
                            .foregroundStyle(data.isPlaying ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                            .padding(.bottom, 6)
                    }
                    Text(data.trackTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    Text(data.trackArtist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if !data.trackAlbum.isEmpty {
                        Text(data.trackAlbum)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                } else {
                    Image(systemName: "music.note.list")
                        .font(.title)
                        .foregroundStyle(.tertiary)
                        .padding(.bottom, 6)
                    Text("Nothing playing")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider().padding(.horizontal, 12)

            VStack(alignment: .leading, spacing: 0) {
                Text("Stats")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                StatRow(label: "Today", value: "\(data.todayScrobbles)")
                    .padding(.bottom, 4)
                StatRow(label: "Total", value: "\(data.totalScrobbles)")

                if !data.lastScrobbledTitle.isEmpty {
                    Divider().padding(.vertical, 8)
                    Text("Last scrobbled")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(data.lastScrobbledTitle)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text(data.lastScrobbledArtist)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
    }
}

private struct ScrobbleCount: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
                .monospacedDigit()
        }
    }
}

