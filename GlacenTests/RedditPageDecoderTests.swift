// GlacenTests/RedditPageDecoderTests.swift
import Testing
@testable import Glacen
import Foundation

struct RedditPageDecoderTests {
    @Test func decodesPostsFromListingJSON() throws {
        let json = """
        {
          "kind": "Listing",
          "data": {
            "after": "t3_def456",
            "children": [
              {
                "kind": "t3",
                "data": {
                  "id": "abc123",
                  "name": "t3_abc123",
                  "title": "New display tech could double OLED lifespan",
                  "subreddit": "technology",
                  "author": "someuser",
                  "score": 1234,
                  "num_comments": 56,
                  "selftext": "Body text of the post",
                  "permalink": "/r/technology/comments/abc123/post_title/",
                  "created_utc": 1700000000.0
                }
              }
            ]
          }
        }
        """
        let page = try RedditPageDecoder.decode(Data(json.utf8))
        #expect(page.posts.count == 1)
        #expect(page.posts[0].id == "abc123")
        #expect(page.posts[0].fullname == "t3_abc123")
        #expect(page.posts[0].title == "New display tech could double OLED lifespan")
        #expect(page.posts[0].subreddit == "technology")
        #expect(page.posts[0].score == 1234)
        #expect(page.posts[0].commentCount == 56)
        #expect(page.after == "t3_def456")
        #expect(page.posts[0].author == "someuser")
        #expect(page.posts[0].selftext == "Body text of the post")
        #expect(page.posts[0].permalink == "/r/technology/comments/abc123/post_title/")
        #expect(page.posts[0].createdAt == Date(timeIntervalSince1970: 1700000000.0))
    }

    @Test func ignoresNonPostChildren() throws {
        let json = """
        {
          "kind": "Listing",
          "data": {
            "after": null,
            "children": [
              { "kind": "t5", "data": { "id": "x", "name": "t5_x", "title": "", "subreddit": "", "author": "", "score": 0, "num_comments": 0, "selftext": "", "permalink": "", "created_utc": 0 } }
            ]
          }
        }
        """
        let page = try RedditPageDecoder.decode(Data(json.utf8))
        #expect(page.posts.isEmpty)
        #expect(page.after == nil)
    }
}
