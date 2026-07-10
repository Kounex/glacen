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
        let index = after == nil ? 0 : ((pages.firstIndex { $0.after == after }).map { $0 + 1 } ?? 0)
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
}
