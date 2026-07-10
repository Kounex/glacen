// Glacen/Home/HomeView.swift
import SwiftUI

struct HomeView: View {
    @State private var viewModel: HomeViewModel

    init(client: RedditClient) {
        _viewModel = State(initialValue: HomeViewModel(client: client))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.posts) { post in
                        PostRowView(post: post)
                            .onAppear {
                                if post.id == viewModel.posts.last?.id {
                                    Task { await viewModel.loadNextPage() }
                                }
                            }
                    }
                    if viewModel.isLoading {
                        ProgressView().padding()
                    }
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage).foregroundStyle(.secondary).padding()
                    }
                }
                .padding()
            }
            .background(Color.glacenBackground.ignoresSafeArea())
            .navigationTitle("Home")
            .refreshable { await viewModel.refresh() }
            .task { await viewModel.loadInitialPage() }
        }
    }
}
