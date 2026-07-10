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

    @Test func codeVerifierLengthMeetsRFC7636Minimum() {
        let verifier = PKCE.generateCodeVerifier()
        #expect((43...128).contains(verifier.count))
    }

    @Test func codeVerifierIsUniqueAcrossCalls() {
        #expect(PKCE.generateCodeVerifier() != PKCE.generateCodeVerifier())
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
