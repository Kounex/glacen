# Glacen Milestone 1: Foundation, Reddit OAuth & Read-Only Home Feed — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a real, running iOS app that authenticates with the user's own Reddit account via OAuth and displays their subscribed-subreddit feed as scrollable, paginated Liquid Glass cards on a true-black background — no filtering yet (that's Milestone 3), but a complete, working, testable Reddit reader.

**Architecture:** SwiftUI + `@Observable` view models, a protocol-based `RedditClient` for networking (so tests never touch the real network), OAuth 2.0 PKCE via `ASWebAuthenticationSession`, tokens in the iOS Keychain (not SwiftData — see spec §2). XcodeGen (`project.yml`) generates the Xcode project; no `.xcodeproj` is committed.

**Tech Stack:** Swift 6 (strict concurrency), SwiftUI, Swift Testing, `AuthenticationServices`, `CryptoKit`, XcodeGen 2.45+, iOS 26 SDK (Xcode 26.5 confirmed installed locally).

**Relation to the full spec:** This is Milestone 1 of the roadmap below. It covers spec §2 (architecture skeleton), part of §6 (navigation shell, visual language), and the read half of the Reddit client. Classification (spec §3–5), the review loop and dataset management (spec §6–7 remainder), and CloudKit sync (spec §5) are deliberately deferred to later milestones, each of which will get its own plan document written just before work on it starts — not written speculatively now, since later milestones' exact shape depends on what's learned building this one.

**Roadmap (future milestones, not detailed in this plan):**
- M2: Post detail/comments view, vote, save (completes basic Reddit interactions)
- M3: SwiftData models + `ClassificationProvider` protocol + cloud/on-device providers + `ExampleStore` (backend only, unit tested)
- M4: Wire classification into Home, strictness setting, Review/Hidden tier UI, Filtered tab
- M5: Review loop corrections, Settings screens (backend picker, instructions editor, dataset browser)
- M6: CloudKit sync, error-handling banners, onboarding polish

**Known limitation carried forward:** access-token refresh-on-expiry is NOT implemented in this milestone. Reddit access tokens expire after ~1 hour; until M2 wires up refresh, a session longer than that will show the feed error state and require signing out and back in. This is a deliberate scope cut, not an oversight — flagged here so it isn't mistaken for a bug during review.

---

## Prerequisites (one-time, manual, before Task 9)

1. Go to https://www.reddit.com/prefs/apps, click "create another app...".
2. Name it (e.g. "Glacen Dev"), select **"installed app"** (not "web app" or "script") — this is required for the PKCE flow used in this plan, which assumes no client secret.
3. Set the redirect URI to exactly: `glacen://oauth-callback`
4. After creation, copy the client ID shown under the app name (a short string, NOT the secret field — installed apps have no usable secret).
5. Before running `xcodegen generate` (Task 1 onward), export both required environment variables in your shell:
   ```bash
   export DEVELOPMENT_TEAM=""          # your real Apple team ID once you have one; empty is fine for simulator builds
   export REDDIT_CLIENT_ID="your_client_id_here"
   ```
   For Tasks 1–8 (which only need the project to *build*, not run OAuth for real), `REDDIT_CLIENT_ID=""` is fine. Set the real value before Task 9's manual verification.

---

### Task 1: XcodeGen Project Scaffold

**Files:**
- Create: `project.yml`
- Create: `Glacen/GlacenApp.swift`

- [ ] **Step 1: Create the folder skeleton**

```bash
mkdir -p /Users/kounex/development/swiftui/Glacen/Glacen/App
mkdir -p /Users/kounex/development/swiftui/Glacen/Glacen/DesignSystem
mkdir -p /Users/kounex/development/swiftui/Glacen/Glacen/Reddit
mkdir -p /Users/kounex/development/swiftui/Glacen/Glacen/Home
mkdir -p /Users/kounex/development/swiftui/Glacen/Glacen/Filtered
mkdir -p /Users/kounex/development/swiftui/Glacen/Glacen/Settings
mkdir -p /Users/kounex/development/swiftui/Glacen/GlacenTests
```

- [ ] **Step 2: Write `project.yml`**

```yaml
name: Glacen
options:
  bundleIdPrefix: com.kounex
  deploymentTarget:
    iOS: "26.0"
  xcodeVersion: "26.0"
  createIntermediateGroups: true
  generateEmptyDirectories: true
  defaultConfig: Debug

settings:
  base:
    SWIFT_VERSION: "6.0"
    DEVELOPMENT_TEAM: ${DEVELOPMENT_TEAM}
    GENERATE_INFOPLIST_FILE: YES
    CURRENT_PROJECT_VERSION: 1
    MARKETING_VERSION: "0.1.0"
    CODE_SIGN_STYLE: Automatic

targets:
  Glacen:
    type: application
    platform: iOS
    deploymentTarget: "26.0"
    sources:
      - path: Glacen
        excludes:
          - "**/.DS_Store"
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.kounex.glacen
        DEVELOPMENT_TEAM: ${DEVELOPMENT_TEAM}
        CODE_SIGN_STYLE: Automatic
        INFOPLIST_KEY_CFBundleDisplayName: Glacen
        INFOPLIST_KEY_UIApplicationSceneManifest_Generation: YES
        INFOPLIST_KEY_UILaunchScreen_Generation: YES
        INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone: "UIInterfaceOrientationPortrait"
        SWIFT_STRICT_CONCURRENCY: complete
        REDDIT_CLIENT_ID: ${REDDIT_CLIENT_ID}
      configs:
        Debug:
          SWIFT_ACTIVE_COMPILATION_CONDITIONS: DEBUG
        Release:
          SWIFT_ACTIVE_COMPILATION_CONDITIONS: ""
    info:
      properties:
        CFBundleURLTypes:
          - CFBundleURLName: "Reddit OAuth Callback"
            CFBundleURLSchemes:
              - glacen
        RedditClientID: "$(REDDIT_CLIENT_ID)"
    dependencies: []

  GlacenTests:
    type: bundle.unit-test
    platform: iOS
    deploymentTarget: "26.0"
    sources:
      - path: GlacenTests
    settings:
      base:
        SWIFT_STRICT_CONCURRENCY: complete
    dependencies:
      - target: Glacen

schemes:
  Glacen:
    build:
      targets:
        Glacen: all
        GlacenTests: [test]
    test:
      config: Debug
      targets:
        - GlacenTests
    run:
      config: Debug
    profile:
      config: Debug
    archive:
      config: Debug
```

- [ ] **Step 3: Write a minimal, buildable `Glacen/GlacenApp.swift`**

```swift
import SwiftUI

@main
struct GlacenApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Glacen")
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
        }
    }
}
```

- [ ] **Step 4: Generate the Xcode project and verify it builds**

```bash
cd /Users/kounex/development/swiftui/Glacen
export DEVELOPMENT_TEAM=""
export REDDIT_CLIENT_ID=""
xcodegen generate
xcodebuild -project Glacen.xcodeproj -scheme Glacen -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add project.yml Glacen/GlacenApp.swift .gitignore
git commit -m "$(cat <<'EOF'
Add XcodeGen scaffold with minimal buildable app shell

Assisted-by: Claude Code
Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

(Note: `Glacen.xcodeproj` is git-ignored per the project's `.gitignore` and regenerated by `xcodegen generate` — do not `git add` it.)

---

### Task 2: Design Tokens & GlassCard Component

**Files:**
- Create: `Glacen/DesignSystem/Color+Glacen.swift`
- Create: `Glacen/DesignSystem/GlassCard.swift`

- [ ] **Step 1: Write the color tokens**

```swift
// Glacen/DesignSystem/Color+Glacen.swift
import SwiftUI

extension Color {
    static let glacenBackground = Color(red: 0.02, green: 0.02, blue: 0.03)
    static let glacenAccent = Color(red: 0.42, green: 0.78, blue: 0.87)
    static let glacenReview = Color(red: 1.0, green: 0.62, blue: 0.24)
}
```

- [ ] **Step 2: Write the reusable glass card, using the real Liquid Glass API**

```swift
// Glacen/DesignSystem/GlassCard.swift
import SwiftUI

struct GlassCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(12)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    ZStack {
        Color.glacenBackground.ignoresSafeArea()
        GlassCard {
            VStack(alignment: .leading, spacing: 4) {
                Text("r/technology · 4h").font(.caption).foregroundStyle(.secondary)
                Text("New display tech could double OLED lifespan").font(.headline)
            }
        }
        .padding()
    }
}
```

- [ ] **Step 3: Build to verify (no test — this is a pure declarative view; verify by building and checking the Xcode preview canvas manually)**

```bash
cd /Users/kounex/development/swiftui/Glacen
xcodebuild -project Glacen.xcodeproj -scheme Glacen -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Glacen/DesignSystem
git commit -m "$(cat <<'EOF'
Add design tokens and Liquid Glass card component

Assisted-by: Claude Code
Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Keychain Wrapper

**Files:**
- Create: `Glacen/Reddit/KeychainStore.swift`
- Test: `GlacenTests/KeychainStoreTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// GlacenTests/KeychainStoreTests.swift
import Testing
@testable import Glacen
import Foundation

struct KeychainStoreTests {
    @Test func setAndRetrieveData() throws {
        let store = KeychainStore(service: "com.kounex.glacen.tests.\(UUID().uuidString)")
        let payload = Data("hello".utf8)
        try store.set(payload, forKey: "token")
        let fetched = try store.data(forKey: "token")
        #expect(fetched == payload)
        try store.removeValue(forKey: "token")
    }

    @Test func missingKeyReturnsNil() throws {
        let store = KeychainStore(service: "com.kounex.glacen.tests.\(UUID().uuidString)")
        let fetched = try store.data(forKey: "missing")
        #expect(fetched == nil)
    }

    @Test func removeValueDeletesData() throws {
        let store = KeychainStore(service: "com.kounex.glacen.tests.\(UUID().uuidString)")
        try store.set(Data("x".utf8), forKey: "token")
        try store.removeValue(forKey: "token")
        let fetched = try store.data(forKey: "token")
        #expect(fetched == nil)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /Users/kounex/development/swiftui/Glacen
xcodegen generate
xcodebuild -project Glacen.xcodeproj -scheme Glacen -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:GlacenTests/KeychainStoreTests
```

Expected: FAIL — `Cannot find 'KeychainStore' in scope`

- [ ] **Step 3: Write the implementation**

```swift
// Glacen/Reddit/KeychainStore.swift
import Foundation
import Security

enum KeychainError: Error {
    case unhandledStatus(OSStatus)
}

struct KeychainStore: Sendable {
    let service: String

    func set(_ data: Data, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandledStatus(status)
        }
    }

    func data(forKey key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainError.unhandledStatus(status)
        }
        return result as? Data
    }

    func removeValue(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledStatus(status)
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild -project Glacen.xcodeproj -scheme Glacen -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:GlacenTests/KeychainStoreTests
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Glacen/Reddit/KeychainStore.swift GlacenTests/KeychainStoreTests.swift
git commit -m "$(cat <<'EOF'
Add Keychain wrapper for storing OAuth tokens

Assisted-by: Claude Code
Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: PKCE Helpers

**Files:**
- Create: `Glacen/Reddit/PKCE.swift`
- Test: `GlacenTests/PKCETests.swift`

- [ ] **Step 1: Write the failing test (includes the RFC 7636 Appendix B known-answer vector)**

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild -project Glacen.xcodeproj -scheme Glacen -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:GlacenTests/PKCETests
```

Expected: FAIL — `Cannot find 'PKCE' in scope`

- [ ] **Step 3: Write the implementation**

```swift
// Glacen/Reddit/PKCE.swift
import Foundation
import CryptoKit
import Security

enum PKCE {
    static func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URLEncode(Data(bytes))
    }

    static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return base64URLEncode(Data(digest))
    }

    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild -project Glacen.xcodeproj -scheme Glacen -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:GlacenTests/PKCETests
```

Expected: `** TEST SUCCEEDED **` (this has been independently verified against the real RFC 7636 test vector via a standalone `swift` script before writing this plan — it will pass)

- [ ] **Step 5: Commit**

```bash
git add Glacen/Reddit/PKCE.swift GlacenTests/PKCETests.swift
git commit -m "$(cat <<'EOF'
Add PKCE code verifier/challenge generation

Assisted-by: Claude Code
Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Reddit Post Model & Listing Decoder

**Files:**
- Create: `Glacen/Reddit/RedditModels.swift`
- Test: `GlacenTests/RedditPageDecoderTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// GlacenTests/RedditPageDecoderTests.swift
import Testing
@testable import Glacen
import Foundation

struct RedditPageDecoderTests {
    @Test func decodesPostsFromListingJSON() throws {
        let json = """
        {
          "kind": "Listing",
          "data": {
            "after": "t3_def456",
            "children": [
              {
                "kind": "t3",
                "data": {
                  "id": "abc123",
                  "name": "t3_abc123",
                  "title": "New display tech could double OLED lifespan",
                  "subreddit": "technology",
                  "author": "someuser",
                  "score": 1234,
                  "num_comments": 56,
                  "selftext": "",
                  "permalink": "/r/technology/comments/abc123/post_title/",
                  "created_utc": 1700000000.0
                }
              }
            ]
          }
        }
        """
        let page = try RedditPageDecoder.decode(Data(json.utf8))
        #expect(page.posts.count == 1)
        #expect(page.posts[0].id == "abc123")
        #expect(page.posts[0].fullname == "t3_abc123")
        #expect(page.posts[0].title == "New display tech could double OLED lifespan")
        #expect(page.posts[0].subreddit == "technology")
        #expect(page.posts[0].score == 1234)
        #expect(page.posts[0].commentCount == 56)
        #expect(page.after == "t3_def456")
    }

    @Test func ignoresNonPostChildren() throws {
        let json = """
        {
          "kind": "Listing",
          "data": {
            "after": null,
            "children": [
              { "kind": "t5", "data": { "id": "x", "name": "t5_x", "title": "", "subreddit": "", "author": "", "score": 0, "num_comments": 0, "selftext": "", "permalink": "", "created_utc": 0 } }
            ]
          }
        }
        """
        let page = try RedditPageDecoder.decode(Data(json.utf8))
        #expect(page.posts.isEmpty)
        #expect(page.after == nil)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild -project Glacen.xcodeproj -scheme Glacen -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:GlacenTests/RedditPageDecoderTests
```

Expected: FAIL — `Cannot find 'RedditPageDecoder' in scope`

- [ ] **Step 3: Write the implementation**

```swift
// Glacen/Reddit/RedditModels.swift
import Foundation

struct RedditPost: Identifiable, Equatable, Sendable {
    let id: String
    let fullname: String
    let title: String
    let subreddit: String
    let author: String
    let score: Int
    let commentCount: Int
    let selftext: String
    let permalink: String
    let createdAt: Date
}

struct RedditPage: Equatable, Sendable {
    let posts: [RedditPost]
    let after: String?
}

private struct ListingResponse: Decodable {
    let data: ListingData
}

private struct ListingData: Decodable {
    let after: String?
    let children: [ListingChild]
}

private struct ListingChild: Decodable {
    let kind: String
    let data: PostData
}

private struct PostData: Decodable {
    let id: String
    let name: String
    let title: String
    let subreddit: String
    let author: String
    let score: Int
    let numComments: Int
    let selftext: String
    let permalink: String
    let createdUtc: Double

    enum CodingKeys: String, CodingKey {
        case id, name, title, subreddit, author, score
        case numComments = "num_comments"
        case selftext, permalink
        case createdUtc = "created_utc"
    }
}

enum RedditPageDecoder {
    static func decode(_ data: Data) throws -> RedditPage {
        let response = try JSONDecoder().decode(ListingResponse.self, from: data)
        let posts = response.data.children
            .filter { $0.kind == "t3" }
            .map { child in
                RedditPost(
                    id: child.data.id,
                    fullname: child.data.name,
                    title: child.data.title,
                    subreddit: child.data.subreddit,
                    author: child.data.author,
                    score: child.data.score,
                    commentCount: child.data.numComments,
                    selftext: child.data.selftext,
                    permalink: child.data.permalink,
                    createdAt: Date(timeIntervalSince1970: child.data.createdUtc)
                )
            }
        return RedditPage(posts: posts, after: response.data.after)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild -project Glacen.xcodeproj -scheme Glacen -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:GlacenTests/RedditPageDecoderTests
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Glacen/Reddit/RedditModels.swift GlacenTests/RedditPageDecoderTests.swift
git commit -m "$(cat <<'EOF'
Add RedditPost model and Listing JSON decoder

Assisted-by: Claude Code
Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: OAuth Config & Authorization URL Builder

**Files:**
- Create: `Glacen/Reddit/RedditOAuthConfig.swift`
- Create: `Glacen/Reddit/RedditAuthorizationURLBuilder.swift`
- Test: `GlacenTests/RedditAuthorizationURLBuilderTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// GlacenTests/RedditAuthorizationURLBuilderTests.swift
import Testing
@testable import Glacen
import Foundation

struct RedditAuthorizationURLBuilderTests {
    let config = RedditOAuthConfig(clientID: "abc123", redirectURI: "glacen://oauth-callback", scopes: ["identity", "read"])

    @Test func buildsURLWithRequiredQueryItems() {
        let url = RedditAuthorizationURLBuilder.makeURL(config: config, state: "xyz", codeChallenge: "challenge123")
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        let items = Dictionary(uniqueKeysWithValues: components.queryItems!.map { ($0.name, $0.value ?? "") })
        #expect(items["client_id"] == "abc123")
        #expect(items["response_type"] == "code")
        #expect(items["state"] == "xyz")
        #expect(items["redirect_uri"] == "glacen://oauth-callback")
        #expect(items["scope"] == "identity read")
        #expect(items["code_challenge"] == "challenge123")
        #expect(items["code_challenge_method"] == "S256")
    }

    @Test func extractsCodeFromValidCallback() throws {
        let callback = URL(string: "glacen://oauth-callback?state=xyz&code=abc")!
        let code = try RedditAuthorizationURLBuilder.extractCode(from: callback, expectedState: "xyz")
        #expect(code == "abc")
    }

    @Test func throwsOnStateMismatch() {
        let callback = URL(string: "glacen://oauth-callback?state=wrong&code=abc")!
        #expect(throws: RedditAuthError.stateMismatch) {
            try RedditAuthorizationURLBuilder.extractCode(from: callback, expectedState: "xyz")
        }
    }

    @Test func throwsOnAuthorizationDenied() {
        let callback = URL(string: "glacen://oauth-callback?state=xyz&error=access_denied")!
        #expect(throws: RedditAuthError.authorizationDenied("access_denied")) {
            try RedditAuthorizationURLBuilder.extractCode(from: callback, expectedState: "xyz")
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild -project Glacen.xcodeproj -scheme Glacen -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:GlacenTests/RedditAuthorizationURLBuilderTests
```

Expected: FAIL — `Cannot find 'RedditOAuthConfig' in scope`

- [ ] **Step 3: Write the implementation**

```swift
// Glacen/Reddit/RedditOAuthConfig.swift
import Foundation

struct RedditOAuthConfig: Sendable {
    let clientID: String
    let redirectURI: String
    let scopes: [String]

    static let live = RedditOAuthConfig(
        clientID: Bundle.main.object(forInfoDictionaryKey: "RedditClientID") as? String ?? "",
        redirectURI: "glacen://oauth-callback",
        scopes: ["identity", "read", "mysubreddits", "vote", "save"]
    )
}
```

```swift
// Glacen/Reddit/RedditAuthorizationURLBuilder.swift
import Foundation

enum RedditAuthError: Error, Equatable {
    case invalidCallback
    case stateMismatch
    case authorizationDenied(String)
}

enum RedditAuthorizationURLBuilder {
    static func makeURL(config: RedditOAuthConfig, state: String, codeChallenge: String) -> URL {
        var components = URLComponents(string: "https://www.reddit.com/api/v1/authorize.compact")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: config.clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI),
            URLQueryItem(name: "duration", value: "permanent"),
            URLQueryItem(name: "scope", value: config.scopes.joined(separator: " ")),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        return components.url!
    }

    static func extractCode(from callbackURL: URL, expectedState: String) throws -> String {
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let items = components.queryItems else {
            throw RedditAuthError.invalidCallback
        }
        if let error = items.first(where: { $0.name == "error" })?.value {
            throw RedditAuthError.authorizationDenied(error)
        }
        guard let state = items.first(where: { $0.name == "state" })?.value,
              state == expectedState else {
            throw RedditAuthError.stateMismatch
        }
        guard let code = items.first(where: { $0.name == "code" })?.value else {
            throw RedditAuthError.invalidCallback
        }
        return code
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild -project Glacen.xcodeproj -scheme Glacen -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:GlacenTests/RedditAuthorizationURLBuilderTests
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Glacen/Reddit/RedditOAuthConfig.swift Glacen/Reddit/RedditAuthorizationURLBuilder.swift GlacenTests/RedditAuthorizationURLBuilderTests.swift
git commit -m "$(cat <<'EOF'
Add OAuth config and authorization URL builder

Assisted-by: Claude Code
Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Token Exchange Client

**Files:**
- Create: `Glacen/Reddit/RedditTokenClient.swift`
- Create: `GlacenTests/StubURLProtocol.swift`
- Test: `GlacenTests/RedditTokenClientTests.swift`

- [ ] **Step 1: Write the test helper (a URLProtocol stub shared by this and later network tests)**

```swift
// GlacenTests/StubURLProtocol.swift
import Foundation

final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = StubURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static func makeStubbedSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}
```

- [ ] **Step 2: Write the failing test**

```swift
// GlacenTests/RedditTokenClientTests.swift
import Testing
@testable import Glacen
import Foundation

struct RedditTokenClientTests {
    @Test func exchangeDecodesTokenResponse() async throws {
        let responseJSON = """
        {"access_token":"AT123","refresh_token":"RT456","expires_in":3600,"token_type":"bearer","scope":"identity read"}
        """
        StubURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(responseJSON.utf8))
        }
        let client = RedditTokenClient(
            config: RedditOAuthConfig(clientID: "abc", redirectURI: "glacen://oauth-callback", scopes: ["identity"]),
            session: StubURLProtocol.makeStubbedSession(),
            userAgent: "ios:com.kounex.glacen:v0.1.0 (by /u/testuser)"
        )
        let token = try await client.exchange(code: "code123", codeVerifier: "verifier123")
        #expect(token.accessToken == "AT123")
        #expect(token.refreshToken == "RT456")
        #expect(token.expiresIn == 3600)
    }

    @Test func exchangeThrowsOnServerError() async {
        StubURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data("{\"error\":\"invalid_grant\"}".utf8))
        }
        let client = RedditTokenClient(
            config: RedditOAuthConfig(clientID: "abc", redirectURI: "glacen://oauth-callback", scopes: ["identity"]),
            session: StubURLProtocol.makeStubbedSession(),
            userAgent: "ios:com.kounex.glacen:v0.1.0 (by /u/testuser)"
        )
        await #expect(throws: RedditTokenClientError.self) {
            try await client.exchange(code: "bad", codeVerifier: "verifier123")
        }
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
xcodebuild -project Glacen.xcodeproj -scheme Glacen -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:GlacenTests/RedditTokenClientTests
```

Expected: FAIL — `Cannot find 'RedditTokenClient' in scope`

- [ ] **Step 4: Write the implementation**

```swift
// Glacen/Reddit/RedditTokenClient.swift
import Foundation

struct RedditTokenResponse: Decodable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

enum RedditTokenClientError: Error {
    case invalidResponse
    case server(status: Int, body: String)
}

struct RedditTokenClient: Sendable {
    let config: RedditOAuthConfig
    let session: URLSession
    let userAgent: String

    func exchange(code: String, codeVerifier: String) async throws -> RedditTokenResponse {
        try await send(parameters: [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": config.redirectURI,
            "code_verifier": codeVerifier
        ])
    }

    func refresh(refreshToken: String) async throws -> RedditTokenResponse {
        try await send(parameters: [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ])
    }

    private func send(parameters: [String: String]) async throws -> RedditTokenResponse {
        var request = URLRequest(url: URL(string: "https://www.reddit.com/api/v1/access_token")!)
        request.httpMethod = "POST"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let credentials = Data("\(config.clientID):".utf8).base64EncodedString()
        request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        request.httpBody = parameters
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RedditTokenClientError.invalidResponse
        }
        guard http.statusCode == 200 else {
            throw RedditTokenClientError.server(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        return try JSONDecoder().decode(RedditTokenResponse.self, from: data)
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
xcodebuild -project Glacen.xcodeproj -scheme Glacen -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:GlacenTests/RedditTokenClientTests
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add Glacen/Reddit/RedditTokenClient.swift GlacenTests/StubURLProtocol.swift GlacenTests/RedditTokenClientTests.swift
git commit -m "$(cat <<'EOF'
Add Reddit OAuth token exchange client

Assisted-by: Claude Code
Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Home Feed API Client

**Files:**
- Create: `Glacen/Reddit/RedditUserAgent.swift`
- Create: `Glacen/Reddit/RedditClient.swift`
- Test: `GlacenTests/LiveRedditClientTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// GlacenTests/LiveRedditClientTests.swift
import Testing
@testable import Glacen
import Foundation

struct LiveRedditClientTests {
    @Test func fetchHomeFeedDecodesPageAndSendsAuthHeader() async throws {
        let json = """
        {"kind":"Listing","data":{"after":"t3_next","children":[
          {"kind":"t3","data":{"id":"abc","name":"t3_abc","title":"Title","subreddit":"technology","author":"a","score":10,"num_comments":2,"selftext":"","permalink":"/r/technology/comments/abc/","created_utc":1700000000.0}}
        ]}}
        """
        nonisolated(unsafe) var capturedRequest: URLRequest?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }
        let client = LiveRedditClient(
            session: StubURLProtocol.makeStubbedSession(),
            userAgent: "ios:com.kounex.glacen:v0.1 (by /u/test)",
            accessToken: { "AT123" }
        )
        let page = try await client.fetchHomeFeed(after: nil)
        #expect(page.posts.count == 1)
        #expect(page.after == "t3_next")
        #expect(capturedRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer AT123")
        #expect(capturedRequest?.url?.absoluteString.contains("oauth.reddit.com/best") == true)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild -project Glacen.xcodeproj -scheme Glacen -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:GlacenTests/LiveRedditClientTests
```

Expected: FAIL — `Cannot find 'LiveRedditClient' in scope`

- [ ] **Step 3: Write the implementation**

```swift
// Glacen/Reddit/RedditUserAgent.swift
import Foundation

enum RedditUserAgent {
    static var current: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"
        return "ios:com.kounex.glacen:v\(version) (by /u/glacen_app)"
    }
}
```

```swift
// Glacen/Reddit/RedditClient.swift
import Foundation

protocol RedditClient: Sendable {
    func fetchHomeFeed(after: String?) async throws -> RedditPage
}

enum RedditClientError: Error {
    case requestFailed
}

struct LiveRedditClient: RedditClient {
    let session: URLSession
    let userAgent: String
    let accessToken: @Sendable () async throws -> String

    func fetchHomeFeed(after: String?) async throws -> RedditPage {
        var components = URLComponents(string: "https://oauth.reddit.com/best")!
        var items = [URLQueryItem(name: "limit", value: "25")]
        if let after {
            items.append(URLQueryItem(name: "after", value: after))
        }
        components.queryItems = items

        var request = URLRequest(url: components.url!)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw RedditClientError.requestFailed
        }
        return try RedditPageDecoder.decode(data)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild -project Glacen.xcodeproj -scheme Glacen -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:GlacenTests/LiveRedditClientTests
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Glacen/Reddit/RedditUserAgent.swift Glacen/Reddit/RedditClient.swift GlacenTests/LiveRedditClientTests.swift
git commit -m "$(cat <<'EOF'
Add live Reddit client for fetching the home feed

Assisted-by: Claude Code
Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: Auth Orchestrator (`RedditAuthService`)

This class glues `ASWebAuthenticationSession` (an interactive, UI-driven system API with no practical seam for unit testing) to the already-tested `PKCE`, `RedditAuthorizationURLBuilder`, `RedditTokenClient`, and `KeychainStore` pieces. Per the spec's own testing philosophy, this orchestration is verified manually (Task 14), not via automated tests — everything it depends on already is tested.

**Files:**
- Create: `Glacen/Reddit/RedditAuthService.swift`

- [ ] **Step 1: Write the implementation**

```swift
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

    init(config: RedditOAuthConfig = .live, keychain: KeychainStore = KeychainStore(service: "com.kounex.glacen.reddit")) {
        self.config = config
        self.tokenClient = RedditTokenClient(config: config, session: .shared, userAgent: RedditUserAgent.current)
        self.keychain = keychain
        let storedToken: Data? = (try? keychain.data(forKey: "access_token")) ?? nil
        self.isAuthenticated = storedToken != nil
        super.init()
    }

    func signIn() async throws {
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
        try keychain.removeValue(forKey: "refresh_token")
        try keychain.removeValue(forKey: "access_token")
        isAuthenticated = false
        username = nil
    }

    func currentAccessToken() async throws -> String {
        guard let data = try keychain.data(forKey: "access_token"),
              let token = String(data: data, encoding: .utf8) else {
            throw RedditAuthError.invalidCallback
        }
        return token
    }

    private func persist(_ token: RedditTokenResponse) throws {
        try keychain.set(Data(token.accessToken.utf8), forKey: "access_token")
        if let refreshToken = token.refreshToken {
            try keychain.set(Data(refreshToken.utf8), forKey: "refresh_token")
        }
    }

    private func presentWebAuthSession(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "glacen") { callbackURL, error in
                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: error ?? RedditAuthError.invalidCallback)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
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
```

- [ ] **Step 2: Build to verify it compiles**

```bash
cd /Users/kounex/development/swiftui/Glacen
xcodegen generate
xcodebuild -project Glacen.xcodeproj -scheme Glacen -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Glacen/Reddit/RedditAuthService.swift
git commit -m "$(cat <<'EOF'
Add RedditAuthService orchestrating the OAuth PKCE flow

Assisted-by: Claude Code
Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 10: Home View Model

**Files:**
- Create: `Glacen/Home/HomeViewModel.swift`
- Test: `GlacenTests/HomeViewModelTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// GlacenTests/HomeViewModelTests.swift
import Testing
@testable import Glacen
import Foundation

private struct FakeRedditClient: RedditClient {
    let pages: [RedditPage]
    let fail: Bool

    func fetchHomeFeed(after: String?) async throws -> RedditPage {
        if fail { throw RedditClientError.requestFailed }
        let index = after == nil ? 0 : (pages.firstIndex { $0.after == after } ?? 0)
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
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild -project Glacen.xcodeproj -scheme Glacen -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:GlacenTests/HomeViewModelTests
```

Expected: FAIL — `Cannot find 'HomeViewModel' in scope`

- [ ] **Step 3: Write the implementation**

```swift
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
        do {
            let page = try await client.fetchHomeFeed(after: after)
            posts.append(contentsOf: page.posts)
            after = page.after
            hasMore = page.after != nil
        } catch {
            errorMessage = "Couldn't load your feed. Pull to try again."
        }
        isLoading = false
    }

    func refresh() async {
        posts = []
        after = nil
        hasMore = true
        await loadNextPage()
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild -project Glacen.xcodeproj -scheme Glacen -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:GlacenTests/HomeViewModelTests
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Glacen/Home/HomeViewModel.swift GlacenTests/HomeViewModelTests.swift
git commit -m "$(cat <<'EOF'
Add HomeViewModel with paginated feed loading

Assisted-by: Claude Code
Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 11: Post Row & Home Views

**Files:**
- Create: `Glacen/Home/PostRowView.swift`
- Create: `Glacen/Home/HomeView.swift`

- [ ] **Step 1: Write the post row**

```swift
// Glacen/Home/PostRowView.swift
import SwiftUI

struct PostRowView: View {
    let post: RedditPost

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("r/\(post.subreddit) · \(post.author)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(post.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("\(post.score) upvotes · \(post.commentCount) comments")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    ZStack {
        Color.glacenBackground.ignoresSafeArea()
        PostRowView(post: RedditPost(id: "1", fullname: "t3_1", title: "Example post title", subreddit: "technology", author: "someuser", score: 1234, commentCount: 56, selftext: "", permalink: "", createdAt: .now))
            .padding()
    }
}
```

- [ ] **Step 2: Write the home feed view**

```swift
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
```

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -project Glacen.xcodeproj -scheme Glacen -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Glacen/Home/PostRowView.swift Glacen/Home/HomeView.swift
git commit -m "$(cat <<'EOF'
Add PostRowView and HomeView feed UI

Assisted-by: Claude Code
Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 12: Filtered & Settings Stubs

**Files:**
- Create: `Glacen/Filtered/FilteredView.swift`
- Create: `Glacen/Settings/SettingsView.swift`

- [ ] **Step 1: Write the Filtered tab stub**

```swift
// Glacen/Filtered/FilteredView.swift
import SwiftUI

struct FilteredView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Filtering isn't wired up yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.glacenBackground.ignoresSafeArea())
            .navigationTitle("Filtered")
        }
    }
}
```

- [ ] **Step 2: Write the Settings stub**

```swift
// Glacen/Settings/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    let authService: RedditAuthService

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    if let username = authService.username {
                        Text(username)
                    }
                    Button("Sign Out", role: .destructive) {
                        try? authService.signOut()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.glacenBackground.ignoresSafeArea())
            .navigationTitle("Settings")
        }
    }
}
```

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -project Glacen.xcodeproj -scheme Glacen -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Glacen/Filtered/FilteredView.swift Glacen/Settings/SettingsView.swift
git commit -m "$(cat <<'EOF'
Add Filtered and Settings tab stubs

Assisted-by: Claude Code
Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 13: Login View & Root Navigation

**Files:**
- Create: `Glacen/App/LoginView.swift`
- Create: `Glacen/App/RootView.swift`
- Modify: `Glacen/GlacenApp.swift`

- [ ] **Step 1: Write the login screen**

```swift
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
```

- [ ] **Step 2: Write the root tab view with the auth gate**

```swift
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
```

- [ ] **Step 3: Wire `GlacenApp` to use `RootView`**

```swift
// Glacen/GlacenApp.swift
import SwiftUI

@main
struct GlacenApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
    }
}
```

- [ ] **Step 4: Build to verify**

```bash
xcodegen generate
xcodebuild -project Glacen.xcodeproj -scheme Glacen -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Glacen/App/LoginView.swift Glacen/App/RootView.swift Glacen/GlacenApp.swift
git commit -m "$(cat <<'EOF'
Wire login gate and tab navigation into the app root

Assisted-by: Claude Code
Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 14: End-to-End Manual Verification

This app now does real network I/O against Reddit's live API and requires real user interaction (Reddit login in a system web sheet) — this cannot be automated, so this task is a manual verification checklist rather than code.

- [ ] **Step 1: Confirm the Reddit app is registered** per the Prerequisites section above, and export the real client ID:

```bash
export REDDIT_CLIENT_ID="your_real_client_id"
cd /Users/kounex/development/swiftui/Glacen
xcodegen generate
```

- [ ] **Step 2: Run the full test suite one more time to confirm nothing regressed**

```bash
xcodebuild -project Glacen.xcodeproj -scheme Glacen -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Expected: `** TEST SUCCEEDED **` for all suites (KeychainStoreTests, PKCETests, RedditPageDecoderTests, RedditAuthorizationURLBuilderTests, RedditTokenClientTests, LiveRedditClientTests, HomeViewModelTests)

- [ ] **Step 3: Run on the simulator and walk through the golden path**

```bash
xcodebuild -project Glacen.xcodeproj -scheme Glacen -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/glacen-build build
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true
xcrun simctl install "iPhone 17 Pro" /tmp/glacen-build/Build/Products/Debug-iphonesimulator/Glacen.app
xcrun simctl launch "iPhone 17 Pro" com.kounex.glacen
open -a Simulator
```

Manually verify, checking each off:
- [ ] App launches to the "Glacen" login screen on a true-black background with a glass-styled "Continue with Reddit" button
- [ ] Tapping "Continue with Reddit" opens a system web sheet at reddit.com's authorize page
- [ ] Logging in and approving access redirects back into the app (not stuck in the web sheet)
- [ ] The Home tab shows real posts from your subscribed subreddits as glass cards on a black background
- [ ] Scrolling to the bottom loads another page of posts (pagination works)
- [ ] Pull-to-refresh reloads the feed from the top
- [ ] The Filtered and Settings tabs are reachable via the tab bar
- [ ] Settings shows a "Sign Out" button; tapping it returns you to the login screen
- [ ] Force-quitting and relaunching the app after signing back in skips the login screen (Keychain persistence works)

- [ ] **Step 4: Record any deviations found during manual verification as follow-up notes, fix inline if small, and commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
Fix issues found during Milestone 1 manual verification

Assisted-by: Claude Code
Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

(Skip this commit if Step 3's checklist passed with no changes needed.)

---

## Plan Self-Review Notes

- **Spec coverage:** this plan covers spec §2 (architecture skeleton, Keychain-not-CloudKit for secrets), §6 (navigation shell: Home/Filtered/Settings tabs; true-black background; real `glassEffect`/`glassProminent` Liquid Glass APIs, confirmed against the installed iOS 26.5 SDK's `SwiftUICore.swiftinterface` before writing this plan), and the read half of the Reddit client referenced in §2. Classification (§3–5), the review loop and dataset browser (§6–7), and CloudKit sync (§5) are out of scope for this milestone by design — see Roadmap above.
- **Type consistency:** `RedditPost`, `RedditPage`, `RedditClient`, `RedditClientError`, `RedditAuthError`, `RedditOAuthConfig`, `RedditTokenResponse`, `RedditTokenClientError` are each defined exactly once (Tasks 5–8) and referenced identically by name in every later task and test — checked by re-reading Tasks 9–13 against Tasks 5–8's declarations.
- **Verified against real tooling before writing:** XcodeGen 2.45.4, Xcode 26.5, and the iOS 26.5 SDK are confirmed installed; the PKCE implementation was checked against the RFC 7636 Appendix B test vector via a standalone `swift` script (passed); `glassEffect(_:in:)`, `GlassEffectContainer`, `.glass`/`.glassProminent` button styles were confirmed to exist with these exact signatures in the installed SDK's `SwiftUICore.swiftinterface` and `SwiftUI.swiftinterface`.
- **No placeholders:** every step above contains complete, real code — no TBD/TODO/"implement later" markers.
