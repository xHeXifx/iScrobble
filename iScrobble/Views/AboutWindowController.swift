import AppKit
import SwiftUI

final class AboutWindowController: NSObject, NSWindowDelegate {
    static let shared = AboutWindowController()
    private var window: NSWindow?

    func show() {
        if let existing = window {
            existing.orderFrontRegardless()
            return
        }

        let hosting = NSHostingController(rootView: AboutWindowContent())
        hosting.view.setFrameSize(hosting.view.fittingSize)

        let win = NSPanel(
            contentRect: NSRect(origin: .zero, size: hosting.view.frame.size),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.isMovableByWindowBackground = true
        win.contentViewController = hosting
        win.center()
        win.delegate = self
        window = win
        win.orderFrontRegardless()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}

struct AboutWindowContent: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.1"
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)
                .padding(.top, 28)

            Text("iScrobble")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Version \(version)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Text("Created by")
                    .foregroundStyle(.secondary)
                Link("HeXif", destination: URL(string: "https://hexif.vercel.app")!)
            }
            .font(.subheadline)
        }
        .padding(.bottom, 28)
        .padding(.horizontal, 32)
        .frame(width: 280)
    }
}
