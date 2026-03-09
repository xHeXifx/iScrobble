import Foundation
import Security
import AppKit

final class StorageManager {
    static let shared = StorageManager()

    private let appGroupID = "group.com.hexif.iScrobble"
    private let nowPlayingFileName = "now_playing.json"

    private var groupContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    private enum DefaultsKey {
        static let scrobblingEnabled = "scrobblingEnabled"
        static let launchAtLogin = "launchAtLogin"
    }

    var scrobblingEnabled: Bool {
        get { UserDefaults.standard.object(forKey: DefaultsKey.scrobblingEnabled) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: DefaultsKey.scrobblingEnabled) }
    }

    var launchAtLogin: Bool {
        get { UserDefaults.standard.bool(forKey: DefaultsKey.launchAtLogin) }
        set { UserDefaults.standard.set(newValue, forKey: DefaultsKey.launchAtLogin) }
    }

    private enum KeychainKey {
        static let sessionKey = "lastfm_session_key"
        static let username = "lastfm_username"
        static let apiKey = "lastfm_api_key"
        static let apiSecret = "lastfm_api_secret"
    }

    private let keychainService = "com.hexif.iScrobble"

    func saveToKeychain(value: String, key: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    func loadFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    var sessionKey: String? {
        get { loadFromKeychain(key: KeychainKey.sessionKey) }
        set {
            if let value = newValue {
                saveToKeychain(value: value, key: KeychainKey.sessionKey)
            } else {
                deleteFromKeychain(key: KeychainKey.sessionKey)
            }
        }
    }

    var username: String? {
        get { loadFromKeychain(key: KeychainKey.username) }
        set {
            if let value = newValue {
                saveToKeychain(value: value, key: KeychainKey.username)
            } else {
                deleteFromKeychain(key: KeychainKey.username)
            }
        }
    }

    var apiKey: String? {
        get { loadFromKeychain(key: KeychainKey.apiKey) }
        set {
            if let value = newValue {
                saveToKeychain(value: value, key: KeychainKey.apiKey)
            } else {
                deleteFromKeychain(key: KeychainKey.apiKey)
            }
        }
    }

    var apiSecret: String? {
        get { loadFromKeychain(key: KeychainKey.apiSecret) }
        set {
            if let value = newValue {
                saveToKeychain(value: value, key: KeychainKey.apiSecret)
            } else {
                deleteFromKeychain(key: KeychainKey.apiSecret)
            }
        }
    }

    var hasValidAPICredentials: Bool {
        guard let key = apiKey, let secret = apiSecret else { return false }
        return !key.isEmpty && !secret.isEmpty
    }

    var isAuthenticated: Bool {
        sessionKey != nil
    }

    func writeNowPlayingState(_ state: NowPlayingState) {
        guard let containerURL = groupContainerURL else { return }
        let fileURL = containerURL.appendingPathComponent(nowPlayingFileName)
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func readNowPlayingState() -> NowPlayingState? {
        guard let containerURL = groupContainerURL else { return nil }
        let fileURL = containerURL.appendingPathComponent(nowPlayingFileName)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(NowPlayingState.self, from: data)
    }

    func writeWidgetData(_ widgetData: WidgetData) {
        guard let data = try? JSONEncoder().encode(widgetData) else { return }
        if let defaults = UserDefaults(suiteName: appGroupID) {
            defaults.set(data, forKey: "widgetData")
            print("[StorageManager] Widget data written to UserDefaults suite: \(appGroupID)")
        } else {
            print("[StorageManager] ERROR: Could not access UserDefaults suite '\(appGroupID)' — App Groups not provisioned correctly")
        }
    }

    func readWidgetData() -> WidgetData? {
        guard
            let defaults = UserDefaults(suiteName: appGroupID),
            let data = defaults.data(forKey: "widgetData"),
            let decoded = try? JSONDecoder().decode(WidgetData.self, from: data)
        else { return nil }
        return decoded
    }

    private var appSupportURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("iScrobble", isDirectory: true)
    }

    func saveAlbumArt(_ image: NSImage, trackID: String) -> String? {
        guard let containerURL = groupContainerURL else {
            print("[StorageManager] ERROR: Could not access App Group container")
            return nil
        }
        
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            print("[StorageManager] ERROR: Failed to convert album art to PNG")
            return nil
        }
        
        let fileName = "albumart-\(trackID.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? trackID).png"
        let fileURL = containerURL.appendingPathComponent(fileName)
        
        do {
            try pngData.write(to: fileURL, options: .atomic)
            print("[StorageManager] Saved album art to: \(fileURL.path)")
            return fileName
        } catch {
            print("[StorageManager] ERROR: Failed to save album art: \(error)")
            return nil
        }
    }
    
    func loadAlbumArt(fileName: String) -> NSImage? {
        guard let containerURL = groupContainerURL else { return nil }
        let fileURL = containerURL.appendingPathComponent(fileName)
        return NSImage(contentsOf: fileURL)
    }

    func appSupportFileURL(named fileName: String) -> URL? {
        guard let dir = appSupportURL else { return nil }
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent(fileName)
    }
}
