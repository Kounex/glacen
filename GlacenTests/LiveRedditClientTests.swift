import Testing
@testable import Glacen
import Foundation

struct LiveRedditClientTests {
    @Test func fetchHomeFeedDecodesPageAndSendsAuthHeader() async throws {
        let json = """
        {"kind":"Listing","data":{"after":"t3_next","children":[
          {"kind":"t3","data":{"id":"abc","name":"t3_abc","title":"Title","subreddit":"technology","author":"a","score":10,"num_comments":2,"selftext":"","permalink":"/r/technology/comments/abc/","created_utc":1700000000.0}}
        ]}}
        """
        nonisolated(unsafe) var capturedRequest: URLRequest?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }
        let client = LiveRedditClient(
            session: StubURLProtocol.makeStubbedSession(),
            userAgent: "ios:com.kounex.glacen:v0.1 (by /u/test)",
            accessToken: { "AT123" }
        )
        let page = try await client.fetchHomeFeed(after: nil)
        #expect(page.posts.count == 1)
        #expect(page.after == "t3_next")
        #expect(capturedRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer AT123")
        #expect(capturedRequest?.url?.absoluteString.contains("oauth.reddit.com/best") == true)
    }
}
