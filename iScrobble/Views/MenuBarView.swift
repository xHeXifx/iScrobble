import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL
    @Environment(\.openWindow) private var openWindow
    @State private var showingAuth = false
    @State private var showingSettings = false
    @State private var appeared = false

    private var monitor: PlaybackMonitor { appState.playbackMonitor }
    private var scrobbleManager: ScrobbleManager { appState.scrobbleManager }
    private var statsManager: StatsManager { appState.statsManager }
    private var storage: StorageManager { appState.storage }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            nowPlayingSection
            Divider()
            statsSection
            Divider()
            footerSection
        }
        .frame(width: 300)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.96, anchor: .top)
        .onAppear {
            withAnimation(.spring(duration: 0.22, bounce: 0.15)) {
                appeared = true
            }
            
            if !storage.hasValidAPICredentials {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "api-credentials")
            }
        }
        .onDisappear {
            appeared = false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSPopover.willCloseNotification)) { _ in
            withAnimation(.easeIn(duration: 0.12)) {
                appeared = false
            }
        }
        .sheet(isPresented: $showingAuth) {
            AuthView()
                .environment(appState)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environment(appState)
        }
    }

    private var headerSection: some View {
        HStack {
            Image(systemName: "music.note")
                .foregroundStyle(.tint)
                .font(.title2)
            Text("iScrobble")
                .font(.headline)
            Spacer()
            if !storage.isAuthenticated {
                Button("Sign In") { showingAuth = true }
                    .buttonStyle(.link)
                    .font(.caption)
                    .pointerCursor()
            } else if let username = storage.username {
                Text(username)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var nowPlayingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let track = monitor.currentTrack {
                HStack(alignment: .top, spacing: 10) {
                    if let albumArt = track.albumArt {
                        Image(nsImage: albumArt)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                    } else {
                        Image(systemName: monitor.isPlaying ? "play.circle.fill" : "pause.circle.fill")
                            .font(.title)
                            .foregroundStyle(monitor.isPlaying ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                            .symbolEffect(.variableColor, isActive: monitor.isPlaying)
                            .frame(width: 60, height: 60)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.body)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        Text(track.artist)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        if !track.album.isEmpty {
                            Text(track.album)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "music.note.list")
                        .foregroundStyle(.tertiary)
                    Text("Nothing playing")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }

            if let error = scrobbleManager.scrobbleError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var statsSection: some View {
        HStack(spacing: 16) {
            StatPill(label: "Today", value: "\(statsManager.todayScrobbles)")
            StatPill(label: "Total", value: "\(statsManager.totalScrobbles)")
            Spacer()
            if let last = scrobbleManager.lastScrobbledTrack {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Text(last.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var footerSection: some View {
        HStack {
            Button {
                showingSettings = true
            } label: {
                Label("Settings", systemImage: "gear")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .pointerCursor()

            Spacer()

            if storage.isAuthenticated, let username = storage.username {
                Button {
                    if let url = URL(string: "https://www.last.fm/user/\(username)") {
                        openURL(url)
                    }
                } label: {
                    Label("Last.fm Profile", systemImage: "arrow.up.right.square")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .pointerCursor()
            }

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .pointerCursor()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct StatPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.callout)
                .fontWeight(.semibold)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private extension View {
    func pointerCursor() -> some View {
        self.onHover { hovering in
            if hovering {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
    }
}
