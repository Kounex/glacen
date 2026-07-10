// Glacen/App/LoginView.swift
import SwiftUI
import AuthenticationServices

struct LoginView: View {
    let authService: RedditAuthService
    @State private var errorMessage: String?
    @State private var isSigningIn = false

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
                if isSigningIn {
                    ProgressView()
                } else {
                    Button("Continue with Reddit") {
                        isSigningIn = true
                        Task {
                            defer { isSigningIn = false }
                            do {
                                try await authService.signIn()
                            } catch is ASWebAuthenticationSessionError {
                                // User cancelled the sheet — not an error, don't show anything alarming.
                                errorMessage = nil
                            } catch RedditAuthError.authorizationDenied {
                                errorMessage = "Access wasn't granted. You can try again anytime."
                            } catch {
                                errorMessage = "Sign in failed. Please try again."
                            }
                        }
                    }
                    .buttonStyle(.glassProminent)
                }
                if let errorMessage {
                    Text(errorMessage).font(.caption).foregroundStyle(.red)
                }
            }
            .padding()
        }
    }
}
