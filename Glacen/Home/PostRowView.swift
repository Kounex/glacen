// Glacen/Home/PostRowView.swift
import SwiftUI

struct PostRowView: View {
    let post: RedditPost

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("r/\(post.subreddit) · \(post.author)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(post.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("\(post.score) upvotes · \(post.commentCount) comments")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    ZStack {
        Color.glacenBackground.ignoresSafeArea()
        PostRowView(post: RedditPost(id: "1", fullname: "t3_1", title: "Example post title", subreddit: "technology", author: "someuser", score: 1234, commentCount: 56, selftext: "", permalink: "", createdAt: .now))
            .padding()
    }
}
