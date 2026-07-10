import Foundation

struct RedditOAuthConfig: Sendable {
    let clientID: String
    let redirectURI: String
    let scopes: [String]

    // `?? ""` fallback is expected/fine for Tasks 1-8 (build-only CI, no manual OAuth flow yet);
    // this only needs a real client ID starting at Task 9's manual verification step.
    static let live = RedditOAuthConfig(
        clientID: Bundle.main.object(forInfoDictionaryKey: "RedditClientID") as? String ?? "",
        redirectURI: "glacen://oauth-callback",
        scopes: ["identity", "read", "mysubreddits", "vote", "save"]
    )
}
