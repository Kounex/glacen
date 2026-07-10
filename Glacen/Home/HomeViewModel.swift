// Glacen/Home/HomeViewModel.swift
import Foundation

@MainActor
@Observable
final class HomeViewModel {
    private(set) var posts: [RedditPost] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private var after: String?
    private var hasMore = true

    private let client: RedditClient

    init(client: RedditClient) {
        self.client = client
    }

    func loadInitialPage() async {
        guard posts.isEmpty else { return }
        await loadNextPage()
    }

    func loadNextPage() async {
        guard !isLoading, hasMore else { return }
        isLoading = true
        errorMessage = nil
        do {
            let page = try await client.fetchHomeFeed(after: after)
            posts.append(contentsOf: page.posts)
            after = page.after
            hasMore = page.after != nil
        } catch {
            errorMessage = "Couldn't load your feed. Pull to try again."
        }
        isLoading = false
    }

    func refresh() async {
        posts = []
        after = nil
        hasMore = true
        await loadNextPage()
    }
}
