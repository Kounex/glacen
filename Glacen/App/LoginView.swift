// Glacen/App/LoginView.swift
import SwiftUI

struct LoginView: View {
    let authService: RedditAuthService
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.glacenBackground.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Glacen")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)
                Text("A calmer way to read Reddit.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Continue with Reddit") {
                    Task {
                        do {
                            try await authService.signIn()
                        } catch {
                            errorMessage = "Sign in failed. Please try again."
                        }
                    }
                }
                .buttonStyle(.glassProminent)
                if let errorMessage {
                    Text(errorMessage).font(.caption).foregroundStyle(.red)
                }
            }
            .padding()
        }
    }
}
