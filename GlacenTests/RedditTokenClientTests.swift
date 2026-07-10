import Testing
@testable import Glacen
import Foundation

private extension URLRequest {
    /// `URLSession` moves a POST body set via `httpBody` into `httpBodyStream`
    /// before handing the request to a registered `URLProtocol`, so `httpBody`
    /// reads as `nil` inside a stub handler. Read from whichever is populated.
    var capturedHTTPBody: Data? {
        if let httpBody { return httpBody }
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 4096
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let bytesRead = stream.read(&buffer, maxLength: bufferSize)
            if bytesRead <= 0 { break }
            data.append(buffer, count: bytesRead)
        }
        return data
    }
}

@Suite(.serialized)
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

    @Test func exchangeSendsCorrectAuthHeaderAndBody() async throws {
        nonisolated(unsafe) var capturedRequest: URLRequest?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("{\"access_token\":\"AT\",\"expires_in\":3600}".utf8))
        }
        let client = RedditTokenClient(
            config: RedditOAuthConfig(clientID: "abc", redirectURI: "glacen://oauth-callback", scopes: ["identity"]),
            session: StubURLProtocol.makeStubbedSession(),
            userAgent: "test-agent"
        )
        _ = try await client.exchange(code: "code123", codeVerifier: "verifier123")
        #expect(capturedRequest?.url?.absoluteString == "https://www.reddit.com/api/v1/access_token")
        #expect(capturedRequest?.httpMethod == "POST")
        #expect(capturedRequest?.value(forHTTPHeaderField: "Authorization") == "Basic \(Data("abc:".utf8).base64EncodedString())")
        #expect(capturedRequest?.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
        let bodyString = String(data: capturedRequest?.capturedHTTPBody ?? Data(), encoding: .utf8) ?? ""
        #expect(bodyString.contains("grant_type=authorization_code"))
        #expect(bodyString.contains("code=code123"))
        #expect(bodyString.contains("code_verifier=verifier123"))
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
        await #expect(throws: RedditTokenClientError.server(status: 401, body: "{\"error\":\"invalid_grant\"}")) {
            try await client.exchange(code: "bad", codeVerifier: "verifier123")
        }
    }

    @Test func refreshDecodesTokenResponse() async throws {
        let responseJSON = "{\"access_token\":\"AT789\",\"expires_in\":3600}"
        nonisolated(unsafe) var capturedBody: String?
        StubURLProtocol.handler = { request in
            capturedBody = String(data: request.capturedHTTPBody ?? Data(), encoding: .utf8)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(responseJSON.utf8))
        }
        let client = RedditTokenClient(
            config: RedditOAuthConfig(clientID: "abc", redirectURI: "glacen://oauth-callback", scopes: ["identity"]),
            session: StubURLProtocol.makeStubbedSession(),
            userAgent: "test-agent"
        )
        let token = try await client.refresh(refreshToken: "RT999")
        #expect(token.accessToken == "AT789")
        #expect(capturedBody?.contains("grant_type=refresh_token") == true)
        #expect(capturedBody?.contains("refresh_token=RT999") == true)
    }
}
