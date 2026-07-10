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

    // Bumped by `refresh()` so an in-flight `loadNextPage()` call started before the
    // refresh can recognize itself as stale once its await resolves and discard its
    // result instead of appending it onto (or overwriting cursor state from) the
    // just-reset feed. See HomeViewModelTests.refreshDiscardsResultsFromInFlightStaleLoad.
    private var generation = 0

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
        let requestGeneration = generation
        do {
            let page = try await client.fetchHomeFeed(after: after)
            guard requestGeneration == generation else { return }
            posts.append(contentsOf: page.posts)
            after = page.after
            hasMore = page.after != nil
        } catch {
            guard requestGeneration == generation else { return }
            errorMessage = "Couldn't load your feed. Pull to try again."
        }
        isLoading = false
    }

    func refresh() async {
        generation += 1
        posts = []
        after = nil
        hasMore = true
        // Unblock our own call to loadNextPage() below even if a call started before this
        // refresh is still in flight — that stale call's generation guard (above) means its
        // eventual completion is now a no-op and won't touch isLoading itself, so this is the
        // only path that can currently clear it.
        isLoading = false
        await loadNextPage()
    }
}
