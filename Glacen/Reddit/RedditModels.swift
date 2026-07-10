// Glacen/Reddit/RedditModels.swift
import Foundation

struct RedditPost: Identifiable, Equatable, Sendable {
    let id: String
    let fullname: String
    let title: String
    let subreddit: String
    let author: String
    let score: Int
    let commentCount: Int
    let selftext: String
    let permalink: String
    let createdAt: Date
}

struct RedditPage: Equatable, Sendable {
    let posts: [RedditPost]
    let after: String?
}

private struct ListingResponse: Decodable {
    let data: ListingData
}

private struct ListingData: Decodable {
    let after: String?
    let children: [ListingChild]
}

private struct ListingChild: Decodable {
    let kind: String
    let data: PostData
}

private struct PostData: Decodable {
    let id: String
    let name: String
    let title: String
    let subreddit: String
    let author: String
    let score: Int
    let numComments: Int
    let selftext: String
    let permalink: String
    let createdUtc: Double

    enum CodingKeys: String, CodingKey {
        case id, name, title, subreddit, author, score
        case numComments = "num_comments"
        case selftext, permalink
        case createdUtc = "created_utc"
    }
}

enum RedditPageDecoder {
    static func decode(_ data: Data) throws -> RedditPage {
        let response = try JSONDecoder().decode(ListingResponse.self, from: data)
        let posts = response.data.children
            .filter { $0.kind == "t3" }
            .map { child in
                RedditPost(
                    id: child.data.id,
                    fullname: child.data.name,
                    title: child.data.title,
                    subreddit: child.data.subreddit,
                    author: child.data.author,
                    score: child.data.score,
                    commentCount: child.data.numComments,
                    selftext: child.data.selftext,
                    permalink: child.data.permalink,
                    createdAt: Date(timeIntervalSince1970: child.data.createdUtc)
                )
            }
        return RedditPage(posts: posts, after: response.data.after)
    }
}
