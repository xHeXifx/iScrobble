import SwiftUI

struct APICredentialWindowView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openURL) private var openURL
    
    @State private var apiKey = ""
    @State private var apiSecret = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.tint)
                Text("Welcome to iScrobble")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Setup Your Last.fm API Credentials")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("To use iScrobble, you need to provide your own Last.fm API credentials.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 20)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("How to get API credentials:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Text("1.")
                            .fontWeight(.medium)
                        Text("Visit the Last.fm API registration page")
                    }
                    .font(.caption)
                    
                    HStack(alignment: .top, spacing: 8) {
                        Text("2.")
                            .fontWeight(.medium)
                        Text("Create an API account (it's free)")
                    }
                    .font(.caption)
                    
                    HStack(alignment: .top, spacing: 8) {
                        Text("3.")
                            .fontWeight(.medium)
                        Text("Copy your API Key and Shared Secret")
                    }
                    .font(.caption)
                    
                    HStack(alignment: .top, spacing: 8) {
                        Text("4.")
                            .fontWeight(.medium)
                        Text("Paste them below")
                    }
                    .font(.caption)
                }
                .foregroundStyle(.secondary)
                
                Button {
                    openURL(URL(string: "https://www.last.fm/api/account/create")!)
                } label: {
                    Label("Open Last.fm API Registration", systemImage: "arrow.up.forward.square")
                        .font(.caption)
                }
                .buttonStyle(.link)
            }
            .padding(12)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("API Key")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Enter your API Key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("API Secret (Shared Secret)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SecureField("Enter your API Secret", text: $apiSecret)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }
            }
            
            if showError {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 12) {
                Spacer()
                Button("Continue") {
                    saveCredentials()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(apiKey.isEmpty || apiSecret.isEmpty)
                .controlSize(.large)
            }
        }
        .padding(30)
        .frame(width: 520, height: 550)
        .onAppear {
            apiKey = appState.storage.apiKey ?? ""
            apiSecret = appState.storage.apiSecret ?? ""

            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    private func saveCredentials() {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSecret = apiSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedKey.isEmpty && !trimmedSecret.isEmpty else {
            showError = true
            errorMessage = "Both API Key and Secret are required"
            return
        }
        
        guard trimmedKey.count >= 20 && trimmedSecret.count >= 20 else {
            showError = true
            errorMessage = "Invalid credentials format. Please check and try again."
            return
        }
        
        appState.storage.apiKey = trimmedKey
        appState.storage.apiSecret = trimmedSecret
        
        showError = false
        
        NSApp.setActivationPolicy(.accessory)
        
        dismissWindow(id: "api-credentials")
    }
}
