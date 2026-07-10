import Testing
@testable import Glacen
import Foundation

struct RedditAuthorizationURLBuilderTests {
    let config = RedditOAuthConfig(clientID: "abc123", redirectURI: "glacen://oauth-callback", scopes: ["identity", "read"])

    @Test func buildsURLWithRequiredQueryItems() {
        let url = RedditAuthorizationURLBuilder.makeURL(config: config, state: "xyz", codeChallenge: "challenge123")
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        let items = Dictionary(uniqueKeysWithValues: components.queryItems!.map { ($0.name, $0.value ?? "") })
        #expect(items["client_id"] == "abc123")
        #expect(items["response_type"] == "code")
        #expect(items["state"] == "xyz")
        #expect(items["redirect_uri"] == "glacen://oauth-callback")
        #expect(items["scope"] == "identity read")
        #expect(items["code_challenge"] == "challenge123")
        #expect(items["code_challenge_method"] == "S256")
    }

    @Test func extractsCodeFromValidCallback() throws {
        let callback = URL(string: "glacen://oauth-callback?state=xyz&code=abc")!
        let code = try RedditAuthorizationURLBuilder.extractCode(from: callback, expectedState: "xyz")
        #expect(code == "abc")
    }

    @Test func throwsOnStateMismatch() {
        let callback = URL(string: "glacen://oauth-callback?state=wrong&code=abc")!
        #expect(throws: RedditAuthError.stateMismatch) {
            try RedditAuthorizationURLBuilder.extractCode(from: callback, expectedState: "xyz")
        }
    }

    @Test func throwsOnAuthorizationDenied() {
        let callback = URL(string: "glacen://oauth-callback?state=xyz&error=access_denied")!
        #expect(throws: RedditAuthError.authorizationDenied("access_denied")) {
            try RedditAuthorizationURLBuilder.extractCode(from: callback, expectedState: "xyz")
        }
    }

    @Test func errorTakesPriorityOverStateMismatch() {
        let callback = URL(string: "glacen://oauth-callback?state=wrong&error=access_denied")!
        #expect(throws: RedditAuthError.authorizationDenied("access_denied")) {
            try RedditAuthorizationURLBuilder.extractCode(from: callback, expectedState: "xyz")
        }
    }

    @Test func throwsInvalidCallbackWhenCodeMissing() {
        let callback = URL(string: "glacen://oauth-callback?state=xyz")!
        #expect(throws: RedditAuthError.invalidCallback) {
            try RedditAuthorizationURLBuilder.extractCode(from: callback, expectedState: "xyz")
        }
    }
}
