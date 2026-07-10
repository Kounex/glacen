import Testing
@testable import Glacen
import Foundation

struct RedditTokenClientTests {
    @Test func exchangeDecodesTokenResponse() async throws {
        let responseJSON = """
        {"access_token":"AT123","refresh_token":"RT456","expires_in":3600,"token_type":"bearer","scope":"identity read"}
        """
        StubURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(responseJSON.utf8))
        }
        let client = RedditTokenClient(
            config: RedditOAuthConfig(clientID: "abc", redirectURI: "glacen://oauth-callback", scopes: ["identity"]),
            session: StubURLProtocol.makeStubbedSession(),
            userAgent: "ios:com.kounex.glacen:v0.1.0 (by /u/testuser)"
        )
        let token = try await client.exchange(code: "code123", codeVerifier: "verifier123")
        #expect(token.accessToken == "AT123")
        #expect(token.refreshToken == "RT456")
        #expect(token.expiresIn == 3600)
    }

    @Test func exchangeThrowsOnServerError() async {
        StubURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data("{\"error\":\"invalid_grant\"}".utf8))
        }
        let client = RedditTokenClient(
            config: RedditOAuthConfig(clientID: "abc", redirectURI: "glacen://oauth-callback", scopes: ["identity"]),
            session: StubURLProtocol.makeStubbedSession(),
            userAgent: "ios:com.kounex.glacen:v0.1.0 (by /u/testuser)"
        )
        await #expect(throws: RedditTokenClientError.self) {
            try await client.exchange(code: "bad", codeVerifier: "verifier123")
        }
    }
}
