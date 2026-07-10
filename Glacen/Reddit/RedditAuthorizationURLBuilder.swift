import Foundation

enum RedditAuthError: Error, Equatable {
    case invalidCallback
    case stateMismatch
    case authorizationDenied(String)
}

enum RedditAuthorizationURLBuilder {
    static func makeURL(config: RedditOAuthConfig, state: String, codeChallenge: String) -> URL {
        var components = URLComponents(string: "https://www.reddit.com/api/v1/authorize.compact")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: config.clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI),
            URLQueryItem(name: "duration", value: "permanent"),
            URLQueryItem(name: "scope", value: config.scopes.joined(separator: " ")),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        return components.url!
    }

    static func extractCode(from callbackURL: URL, expectedState: String) throws -> String {
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let items = components.queryItems else {
            throw RedditAuthError.invalidCallback
        }
        if let error = items.first(where: { $0.name == "error" })?.value {
            throw RedditAuthError.authorizationDenied(error)
        }
        guard let state = items.first(where: { $0.name == "state" })?.value,
              state == expectedState else {
            throw RedditAuthError.stateMismatch
        }
        guard let code = items.first(where: { $0.name == "code" })?.value else {
            throw RedditAuthError.invalidCallback
        }
        return code
    }
}
