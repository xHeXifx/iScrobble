import SwiftUI

struct AuthView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 40))
                    .foregroundStyle(.tint)
                Text("Sign in to Last.fm")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("iScrobble will scrobble your Apple Music listening history to your Last.fm account.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                TextField("Username", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textContentType(.username)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
            }

            if let error = errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button {
                    signIn()
                } label: {
                    if isLoading {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Signing in…")
                        }
                    } else {
                        Text("Sign In")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(username.isEmpty || password.isEmpty || isLoading)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(24)
        .frame(width: 360)
    }

    private func signIn() {
        guard !username.isEmpty, !password.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let result = try await appState.lastFMClient.getMobileSession(
                    username: username,
                    password: password
                )
                appState.storage.sessionKey = result.sessionKey
                appState.storage.username = result.name
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
