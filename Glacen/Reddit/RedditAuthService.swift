// Glacen/Reddit/RedditAuthService.swift
import Foundation
import AuthenticationServices
import UIKit

@MainActor
@Observable
final class RedditAuthService: NSObject {
    private(set) var isAuthenticated: Bool
    private(set) var username: String?

    private let config: RedditOAuthConfig
    private let tokenClient: RedditTokenClient
    private let keychain: KeychainStore
    private var currentWebAuthSession: ASWebAuthenticationSession?
    private var isSigningIn = false

    private static let accessTokenKey = "access_token"
    private static let refreshTokenKey = "refresh_token"

    init(config: RedditOAuthConfig = .live, keychain: KeychainStore = KeychainStore(service: "com.kounex.glacen.reddit")) {
        self.config = config
        self.tokenClient = RedditTokenClient(config: config, session: .shared, userAgent: RedditUserAgent.current)
        self.keychain = keychain
        let storedToken = try? keychain.data(forKey: Self.accessTokenKey)
        self.isAuthenticated = storedToken != nil
        super.init()
    }

    func signIn() async throws {
        guard !isSigningIn else { return }
        isSigningIn = true
        defer { isSigningIn = false }

        let verifier = PKCE.generateCodeVerifier()
        let challenge = PKCE.codeChallenge(for: verifier)
        let state = UUID().uuidString
        let authURL = RedditAuthorizationURLBuilder.makeURL(config: config, state: state, codeChallenge: challenge)

        let callbackURL = try await presentWebAuthSession(url: authURL)
        let code = try RedditAuthorizationURLBuilder.extractCode(from: callbackURL, expectedState: state)
        let token = try await tokenClient.exchange(code: code, codeVerifier: verifier)
        try persist(token)
        isAuthenticated = true
    }

    func signOut() throws {
        let refreshTokenError = Result { try keychain.removeValue(forKey: Self.refreshTokenKey) }
        let accessTokenError = Result { try keychain.removeValue(forKey: Self.accessTokenKey) }
        isAuthenticated = false
        username = nil
        try refreshTokenError.get()
        try accessTokenError.get()
    }

    func currentAccessToken() async throws -> String {
        guard let data = try keychain.data(forKey: Self.accessTokenKey),
              let token = String(data: data, encoding: .utf8) else {
            throw RedditAuthError.invalidCallback
        }
        return token
    }

    private func persist(_ token: RedditTokenResponse) throws {
        try keychain.set(Data(token.accessToken.utf8), forKey: Self.accessTokenKey)
        if let refreshToken = token.refreshToken {
            try keychain.set(Data(refreshToken.utf8), forKey: Self.refreshTokenKey)
        }
    }

    private func presentWebAuthSession(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "glacen") { [weak self] callbackURL, error in
                self?.currentWebAuthSession = nil
                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: error ?? RedditAuthError.invalidCallback)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            currentWebAuthSession = session
            session.start()
        }
    }
}

extension RedditAuthService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }
    }
}
