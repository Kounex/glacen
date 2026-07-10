// Glacen/App/RootView.swift
import SwiftUI

struct RootView: View {
    @State private var authService = RedditAuthService()

    var body: some View {
        Group {
            if authService.isAuthenticated {
                TabView {
                    HomeView(client: LiveRedditClient(
                        session: .shared,
                        userAgent: RedditUserAgent.current,
                        accessToken: { try await authService.currentAccessToken() }
                    ))
                    .tabItem { Label("Home", systemImage: "house") }

                    FilteredView()
                        .tabItem { Label("Filtered", systemImage: "line.3.horizontal.decrease.circle") }

                    SettingsView(authService: authService)
                        .tabItem { Label("Settings", systemImage: "gearshape") }
                }
            } else {
                LoginView(authService: authService)
            }
        }
    }
}
