// GlacenTests/PKCETests.swift
import Testing
@testable import Glacen

struct PKCETests {
    @Test func codeVerifierIsURLSafeAndNonEmpty() {
        let verifier = PKCE.generateCodeVerifier()
        #expect(!verifier.isEmpty)
        #expect(!verifier.contains("+"))
        #expect(!verifier.contains("/"))
        #expect(!verifier.contains("="))
    }

    @Test func codeChallengeIsDeterministicForSameVerifier() {
        let verifier = "test-verifier-value"
        #expect(PKCE.codeChallenge(for: verifier) == PKCE.codeChallenge(for: verifier))
    }

    @Test func codeChallengeMatchesRFC7636KnownVector() {
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        #expect(PKCE.codeChallenge(for: verifier) == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }
}
