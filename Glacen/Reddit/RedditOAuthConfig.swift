import Foundation

struct RedditOAuthConfig: Sendable {
    let clientID: String
    let redirectURI: String
    let scopes: [String]

    static let live = RedditOAuthConfig(
        clientID: Bundle.main.object(forInfoDictionaryKey: "RedditClientID") as? String ?? "",
        redirectURI: "glacen://oauth-callback",
        scopes: ["identity", "read", "mysubreddits", "vote", "save"]
    )
}
