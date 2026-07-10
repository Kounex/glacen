import Foundation

protocol RedditClient: Sendable {
    func fetchHomeFeed(after: String?) async throws -> RedditPage
}

enum RedditClientError: Error, Equatable {
    case requestFailed
}

struct LiveRedditClient: RedditClient {
    let session: URLSession
    let userAgent: String
    let accessToken: @Sendable () async throws -> String

    func fetchHomeFeed(after: String?) async throws -> RedditPage {
        var components = URLComponents(string: "https://oauth.reddit.com/best")!
        var items = [URLQueryItem(name: "limit", value: "25")]
        if let after {
            items.append(URLQueryItem(name: "after", value: after))
        }
        components.queryItems = items

        var request = URLRequest(url: components.url!)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw RedditClientError.requestFailed
        }
        return try RedditPageDecoder.decode(data)
    }
}
