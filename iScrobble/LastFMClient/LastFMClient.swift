import Foundation
import CryptoKit
import AppKit

final class LastFMClient {
    private let storageManager: StorageManager

    private var apiKey: String {
        storageManager.apiKey ?? ""
    }

    private var apiSecret: String {
        storageManager.apiSecret ?? ""
    }

    private let baseURL = URL(string: "https://ws.audioscrobbler.com/2.0/")!

    init(storageManager: StorageManager = .shared) {
        self.storageManager = storageManager
    }



    enum LastFMError: LocalizedError {
        case networkError(Error)
        case invalidResponse
        case apiError(code: Int, message: String)
        case notAuthenticated

        var errorDescription: String? {
            switch self {
            case .networkError(let e): return e.localizedDescription
            case .invalidResponse: return "Invalid response from Last.fm"
            case .apiError(_, let message): return message
            case .notAuthenticated: return "Not authenticated with Last.fm"
            }
        }
    }

    func getMobileSession(username: String, password: String) async throws -> (sessionKey: String, name: String) {
        var params: [String: String] = [
            "method": "auth.getMobileSession",
            "username": username,
            "password": password,
            "api_key": apiKey,
            "format": "json"
        ]
        params["api_sig"] = apiSig(for: params)

        let data = try await post(params: params)
        let response = try JSONDecoder().decode(MobileSessionResponse.self, from: data)

        if let error = response.error {
            throw LastFMError.apiError(code: error, message: response.message ?? "Unknown error")
        }
        guard let session = response.session else {
            throw LastFMError.invalidResponse
        }
        return (sessionKey: session.key, name: session.name)
    }


    func updateNowPlaying(track: Track, sessionKey: String) async throws {
        var params: [String: String] = [
            "method": "track.updateNowPlaying",
            "artist": track.artist,
            "track": track.title,
            "album": track.album,
            "duration": String(Int(track.duration)),
            "api_key": apiKey,
            "sk": sessionKey,
            "format": "json"
        ]
        params["api_sig"] = apiSig(for: params)
        _ = try await post(params: params)
    }


    func scrobble(track: Track, timestamp: Date, sessionKey: String) async throws {
        let unixTimestamp = String(Int(timestamp.timeIntervalSince1970))
        var params: [String: String] = [
            "method": "track.scrobble",
            "artist[0]": track.artist,
            "track[0]": track.title,
            "album[0]": track.album,
            "timestamp[0]": unixTimestamp,
            "duration[0]": String(Int(track.duration)),
            "api_key": apiKey,
            "sk": sessionKey,
            "format": "json"
        ]
        params["api_sig"] = apiSig(for: params)
        _ = try await post(params: params)
    }

    func getUserInfo(username: String) async throws -> Int {
        print("[LastFMClient] Fetching user info for: \(username)")
        var urlComponents = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = [
            URLQueryItem(name: "method", value: "user.getInfo"),
            URLQueryItem(name: "user", value: username),
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "format", value: "json")
        ]

        guard let url = urlComponents.url else {
            print("[LastFMClient] Failed to construct URL for user info")
            throw LastFMError.invalidResponse
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("[LastFMClient] Response is not HTTPURLResponse for user info")
            throw LastFMError.invalidResponse
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            let responseString = String(data: data, encoding: .utf8) ?? "<unable to decode>"
            print("[LastFMClient] HTTP error for user info: status \(httpResponse.statusCode), body: \(responseString)")
            throw LastFMError.invalidResponse
        }

        if let errorResponse = try? JSONDecoder().decode(ErrorOnlyResponse.self, from: data),
           let code = errorResponse.error {
            print("[LastFMClient] API error fetching user info: \(errorResponse.message ?? "Unknown")")
            throw LastFMError.apiError(code: code, message: errorResponse.message ?? "Unknown error")
        }

        let userInfoResponse = try JSONDecoder().decode(UserInfoResponse.self, from: data)
        let playcount = Int(userInfoResponse.user.playcount) ?? 0
        print("[LastFMClient] User info received - Total scrobbles: \(playcount)")
        return playcount
    }

    func fetchAlbumArt(artist: String, track: String) async throws -> NSImage? {
        print("[LastFMClient] Fetching artwork for: \(artist) - \(track)")
        
        var urlComponents = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = [
            URLQueryItem(name: "method", value: "track.getInfo"),
            URLQueryItem(name: "artist", value: artist),
            URLQueryItem(name: "track", value: track),
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "format", value: "json")
        ]
        
        guard let url = urlComponents.url else {
            print("[LastFMClient] Failed to construct URL for track info")
            throw LastFMError.invalidResponse
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("[LastFMClient] Response is not HTTPURLResponse for track info")
            throw LastFMError.invalidResponse
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            let responseString = String(data: data, encoding: .utf8) ?? "<unable to decode>"
            print("[LastFMClient] HTTP error for track info: status \(httpResponse.statusCode), body: \(responseString)")
            throw LastFMError.invalidResponse
        }
        
        if let errorResponse = try? JSONDecoder().decode(ErrorOnlyResponse.self, from: data),
           let code = errorResponse.error {
            print("[LastFMClient] API error fetching track info: \(errorResponse.message ?? "Unknown")")
            throw LastFMError.apiError(code: code, message: errorResponse.message ?? "Unknown error")
        }
        
        let trackInfoResponse: TrackInfoResponse
        do {
            trackInfoResponse = try JSONDecoder().decode(TrackInfoResponse.self, from: data)
        } catch {
            let responseString = String(data: data, encoding: .utf8) ?? "<unable to decode>"
            print("[LastFMClient] Failed to decode track info response: \(error)")
            print("[LastFMClient] Response body: \(responseString)")
            throw LastFMError.invalidResponse
        }
        
        if let album = trackInfoResponse.track.album {
            print("[LastFMClient] Track has album data with \(album.image.count) images")
            for img in album.image {
                print("[LastFMClient]   Image size: \(img.size), URL: \(img.text.isEmpty ? "<empty>" : img.text.prefix(50))...")
            }
        } else {
            print("[LastFMClient] Track has no album data")
        }
        
        let images = trackInfoResponse.track.album?.image ?? []
        guard let artworkURL = (
            images.first(where: { !$0.text.isEmpty && $0.size == "mega" }) ??
            images.first(where: { !$0.text.isEmpty && $0.size == "extralarge" }) ??
            images.first(where: { !$0.text.isEmpty && $0.size == "large" })
        )?.text else {
            print("[LastFMClient] No artwork URL found for track - Last.fm has no artwork for this track")
            return nil
        }
        
        print("[LastFMClient] Found artwork URL (\(images.first(where: { $0.text == artworkURL })?.size ?? "unknown") size): \(artworkURL)")
        
        guard let imageURL = URL(string: artworkURL) else {
            print("[LastFMClient] Invalid artwork URL")
            return nil
        }
        
        let (imageData, _) = try await URLSession.shared.data(from: imageURL)
        
        guard let image = NSImage(data: imageData) else {
            print("[LastFMClient] Failed to create NSImage from data")
            return nil
        }
        
        print("[LastFMClient] Successfully fetched album art (\(imageData.count) bytes)")
        return image
    }

    private func apiSig(for params: [String: String]) -> String {
        let excluded: Set<String> = ["format", "callback"]
        let sorted = params
            .filter { !excluded.contains($0.key) }
            .sorted { $0.key < $1.key }
            .map { $0.key + $0.value }
            .joined()
        let toHash = sorted + apiSecret
        let signature = md5(toHash)
        
        return signature
    }

    private func md5(_ string: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }


    private func post(params: [String: String]) async throws -> Data {
        
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        var allowedCharacters = CharacterSet.urlQueryAllowed
        allowedCharacters.remove(charactersIn: "&=+")
        
        let bodyString = params
            .map { key, value in
                let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? key
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? value
                return "\(encodedKey)=\(encodedValue)"
            }
            .joined(separator: "&")
        
        request.httpBody = bodyString.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("[LastFMClient] Response is not HTTPURLResponse for POST request")
            throw LastFMError.invalidResponse
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            let responseString = String(data: data, encoding: .utf8) ?? "<unable to decode>"
            print("[LastFMClient] HTTP error for POST: status \(httpResponse.statusCode), body: \(responseString)")
            throw LastFMError.invalidResponse
        }

        if let errorResponse = try? JSONDecoder().decode(ErrorOnlyResponse.self, from: data),
           let code = errorResponse.error {
            throw LastFMError.apiError(code: code, message: errorResponse.message ?? "Unknown error")
        }

        return data
    }
}


private struct MobileSessionResponse: Decodable {
    let session: SessionPayload?
    let error: Int?
    let message: String?

    struct SessionPayload: Decodable {
        let name: String
        let key: String
        let subscriber: Int
    }
}

private struct ErrorOnlyResponse: Decodable {
    let error: Int?
    let message: String?
}

private struct UserInfoResponse: Decodable {
    let user: UserPayload

    struct UserPayload: Decodable {
        let name: String
        let playcount: String
    }
}

private struct TrackInfoResponse: Decodable {
    let track: TrackPayload
    
    struct TrackPayload: Decodable {
        let album: AlbumPayload?
        
        struct AlbumPayload: Decodable {
            let image: [ImagePayload]
            
            struct ImagePayload: Decodable {
                let text: String
                let size: String
                
                enum CodingKeys: String, CodingKey {
                    case text = "#text"
                    case size
                }
            }
        }
    }
}
