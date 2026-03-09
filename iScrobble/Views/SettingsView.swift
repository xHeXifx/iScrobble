import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.openWindow) private var openWindow

    @State private var showingSignOut = false

    private var storage: StorageManager { appState.storage }

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .pointerCursor()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            Form {
                Section("Scrobbling") {
                    Toggle(isOn: Binding(
                        get: { storage.scrobblingEnabled },
                        set: { storage.scrobblingEnabled = $0 }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Enable scrobbling")
                            Text("Automatically scrobble tracks to Last.fm")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Account") {
                    if storage.isAuthenticated {
                        if let username = storage.username {
                            LabeledContent("Last.fm User", value: username)
                        }
                        Button("Sign Out", role: .destructive) {
                            showingSignOut = true
                        }
                    } else {
                        Text("Not signed in")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("API Credentials") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Last.fm API Key")
                            if storage.hasValidAPICredentials {
                                Text("Configured")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            } else {
                                Text("Not configured")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                        Spacer()
                        Button("Configure") {
                            NSApp.setActivationPolicy(.regular)
                            NSApp.activate(ignoringOtherApps: true)
                            openWindow(id: "api-credentials")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.tint)
                        .pointerCursor()
                    }
                }
            }
            .formStyle(.grouped)
            .frame(width: 380, height: 240)

            Divider()

            VStack(spacing: 5) {
                Text("iScrobble")
                    .font(.headline)
                Text("Version \(version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Text("Created by")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("HeXif") {
                        openURL(URL(string: "https://hexif.vercel.app")!)
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.tint)
                    .pointerCursor()
                }
            }
            .padding(.vertical, 14)

            Divider()

        }
        .frame(width: 380)
        .confirmationDialog(
            "Sign out of Last.fm?",
            isPresented: $showingSignOut,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                storage.sessionKey = nil
                storage.username = nil
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("iScrobble will stop scrobbling until you sign in again.")
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
