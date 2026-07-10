import Foundation

struct RedditTokenResponse: Decodable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

enum RedditTokenClientError: Error, Equatable {
    case invalidResponse
    case server(status: Int, body: String)
}

struct RedditTokenClient: Sendable {
    let config: RedditOAuthConfig
    let session: URLSession
    let userAgent: String

    func exchange(code: String, codeVerifier: String) async throws -> RedditTokenResponse {
        try await send(parameters: [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": config.redirectURI,
            "code_verifier": codeVerifier
        ])
    }

    func refresh(refreshToken: String) async throws -> RedditTokenResponse {
        try await send(parameters: [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ])
    }

    private func send(parameters: [String: String]) async throws -> RedditTokenResponse {
        var request = URLRequest(url: URL(string: "https://www.reddit.com/api/v1/access_token")!)
        request.httpMethod = "POST"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let credentials = Data("\(config.clientID):".utf8).base64EncodedString()
        request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        request.httpBody = parameters
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RedditTokenClientError.invalidResponse
        }
        guard http.statusCode == 200 else {
            throw RedditTokenClientError.server(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        return try JSONDecoder().decode(RedditTokenResponse.self, from: data)
    }
}
