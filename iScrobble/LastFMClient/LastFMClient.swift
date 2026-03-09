import Foundation
import CryptoKit

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

    private func apiSig(for params: [String: String]) -> String {
        let excluded: Set<String> = ["format", "callback"]
        let sorted = params
            .filter { !excluded.contains($0.key) }
            .sorted { $0.key < $1.key }
            .map { $0.key + $0.value }
            .joined()
        let toHash = sorted + apiSecret
        return md5(toHash)
    }

    private func md5(_ string: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }


    private func post(params: [String: String]) async throws -> Data {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = params
            .map { key, value in
                let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
                return "\(encodedKey)=\(encodedValue)"
            }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
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
