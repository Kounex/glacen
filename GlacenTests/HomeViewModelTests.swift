import Testing
@testable import Glacen
import Foundation

private struct FakeRedditClient: RedditClient {
    let pages: [RedditPage]
    let fail: Bool

    func fetchHomeFeed(after: String?) async throws -> RedditPage {
        if fail { throw RedditClientError.requestFailed }
        // `pages[i].after` is the cursor for fetching the page *after* page i (matching
        // RedditPage's real semantics), so look up the matching page and advance one index —
        // not return the matching page itself.
        let index: Int
        if let after {
            guard let matchIndex = pages.firstIndex(where: { $0.after == after }) else {
                preconditionFailure("no page matches cursor \(after)")
            }
            index = matchIndex + 1
        } else {
            index = 0
        }
        return pages[index]
    }
}

/// A `RedditClient` whose first call to `fetchHomeFeed` suspends until explicitly released,
/// letting a test deterministically force a specific interleaving: start a load, confirm it's
/// genuinely in flight, run other view model work, then resolve the stalled call last.
/// Subsequent calls (index >= 1) resolve immediately. An actor is used (rather than a struct
/// plus a lock) so the call-index bookkeeping and continuation handoff are race-free without
/// resorting to `@unchecked Sendable`.
private actor SuspendableRedditClient: RedditClient {
    private let pages: [RedditPage]
    private var callCount = 0
    private var releaseFirstCallContinuation: CheckedContinuation<Void, Never>?
    private var firstCallStartedContinuation: CheckedContinuation<Void, Never>?

    init(pages: [RedditPage]) {
        self.pages = pages
    }

    /// Suspends until the first call to `fetchHomeFeed` has reached its suspension point
    /// (or returns immediately if that has already happened).
    func waitForFirstCallToStart() async {
        if releaseFirstCallContinuation != nil { return }
        await withCheckedContinuation { firstCallStartedContinuation = $0 }
    }

    /// Lets the first (and only the first) call to `fetchHomeFeed` return its page.
    func releaseFirstCall() {
        releaseFirstCallContinuation?.resume()
        releaseFirstCallContinuation = nil
    }

    func fetchHomeFeed(after: String?) async throws -> RedditPage {
        let index = callCount
        callCount += 1
        if index == 0 {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                releaseFirstCallContinuation = continuation
                firstCallStartedContinuation?.resume()
                firstCallStartedContinuation = nil
            }
        }
        return pages[index]
    }
}

@MainActor
struct HomeViewModelTests {
    @Test func loadInitialPagePopulatesPosts() async {
        let post = RedditPost(id: "1", fullname: "t3_1", title: "Hello", subreddit: "test", author: "a", score: 1, commentCount: 0, selftext: "", permalink: "", createdAt: .now)
        let client = FakeRedditClient(pages: [RedditPage(posts: [post], after: nil)], fail: false)
        let viewModel = HomeViewModel(client: client)

        await viewModel.loadInitialPage()

        #expect(viewModel.posts == [post])
        #expect(viewModel.isLoading == false)
    }

    @Test func loadNextPageAppendsPosts() async {
        let first = RedditPost(id: "1", fullname: "t3_1", title: "First", subreddit: "test", author: "a", score: 1, commentCount: 0, selftext: "", permalink: "", createdAt: .now)
        let second = RedditPost(id: "2", fullname: "t3_2", title: "Second", subreddit: "test", author: "a", score: 1, commentCount: 0, selftext: "", permalink: "", createdAt: .now)
        let client = FakeRedditClient(pages: [
            RedditPage(posts: [first], after: "t3_1"),
            RedditPage(posts: [second], after: nil)
        ], fail: false)
        let viewModel = HomeViewModel(client: client)

        await viewModel.loadInitialPage()
        await viewModel.loadNextPage()

        #expect(viewModel.posts == [first, second])
    }

    @Test func failedLoadSetsErrorMessage() async {
        let client = FakeRedditClient(pages: [], fail: true)
        let viewModel = HomeViewModel(client: client)

        await viewModel.loadInitialPage()

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.posts.isEmpty)
    }

    @Test func refreshResetsPaginationAndReloadsFromScratch() async {
        let first = RedditPost(id: "1", fullname: "t3_1", title: "First", subreddit: "test", author: "a", score: 1, commentCount: 0, selftext: "", permalink: "", createdAt: .now)
        let second = RedditPost(id: "2", fullname: "t3_2", title: "Second", subreddit: "test", author: "a", score: 1, commentCount: 0, selftext: "", permalink: "", createdAt: .now)
        let client = FakeRedditClient(pages: [
            RedditPage(posts: [first], after: "t3_1"),
            RedditPage(posts: [second], after: nil)
        ], fail: false)
        let viewModel = HomeViewModel(client: client)

        await viewModel.loadInitialPage()
        await viewModel.loadNextPage()
        #expect(viewModel.posts == [first, second])

        await viewModel.refresh()

        // Refresh discards accumulated posts and re-fetches from the first page only,
        // proving `after`/`hasMore` were reset rather than reused from the exhausted state.
        #expect(viewModel.posts == [first])
    }

    @Test func loadNextPageIsNoOpOnceExhausted() async {
        let first = RedditPost(id: "1", fullname: "t3_1", title: "First", subreddit: "test", author: "a", score: 1, commentCount: 0, selftext: "", permalink: "", createdAt: .now)
        let client = FakeRedditClient(pages: [RedditPage(posts: [first], after: nil)], fail: false)
        let viewModel = HomeViewModel(client: client)

        await viewModel.loadInitialPage()
        // `after` is nil once the first page reports no more pages, so without the
        // `hasMore` guard this would re-fetch page zero and duplicate `first`.
        await viewModel.loadNextPage()

        #expect(viewModel.posts == [first])
    }

    @Test func refreshDiscardsResultsFromInFlightStaleLoad() async {
        let stale = RedditPost(id: "stale", fullname: "t3_stale", title: "Stale", subreddit: "test", author: "a", score: 1, commentCount: 0, selftext: "", permalink: "", createdAt: .now)
        let fresh = RedditPost(id: "fresh", fullname: "t3_fresh", title: "Fresh", subreddit: "test", author: "a", score: 1, commentCount: 0, selftext: "", permalink: "", createdAt: .now)
        let client = SuspendableRedditClient(pages: [
            RedditPage(posts: [stale], after: "stale-cursor"),
            RedditPage(posts: [fresh], after: nil)
        ])
        let viewModel = HomeViewModel(client: client)

        // Kick off the initial load on a separate task; its fetch call suspends inside the
        // client until we release it below, simulating a slow request still in flight.
        let staleLoad = Task { await viewModel.loadInitialPage() }
        await client.waitForFirstCallToStart()

        // Refresh while the stale load is still pending. This starts a second, independent
        // fetch (unblocked, resolves immediately) that should become the source of truth.
        await viewModel.refresh()

        #expect(viewModel.posts == [fresh])
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)

        // Only now let the stale fetch resolve. Without the generation guard, this would
        // append `stale` onto the just-refreshed feed and overwrite the cursor/hasMore state
        // with the stale page's — corrupting a feed that already looked freshly loaded.
        await client.releaseFirstCall()
        await staleLoad.value

        #expect(viewModel.posts == [fresh])
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }
}
