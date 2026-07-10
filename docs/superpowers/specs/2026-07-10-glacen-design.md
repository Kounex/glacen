# Glacen — Design Spec

Date: 2026-07-10
Status: Approved for implementation planning

## 1. Product Overview

Glacen is an unofficial, calm-first Reddit client for iOS (macOS to follow later) whose core differentiator is filtering negativity, bait, and low-effort "slop" out of a user's feed using an LLM the user controls, paired with a manual review loop that makes the filter more accurate the more it's used.

**v1 scope:**
- iOS only, targeting iOS 26+ (macOS is a later phase, not v1)
- Read + vote + save. No post/comment creation, no direct messages.
- Filtering applies to **posts only** — comment threads are unfiltered in v1.
- One **global** set of filtering instructions and one shared example dataset — no per-subreddit overrides in v1.
- Classification runs on a user-supplied cloud API key (Anthropic and/or OpenAI) **or** Apple's on-device Foundation Models framework — both available from day one.
- No subscription tier, no hosted/managed LLM, no payment infrastructure of any kind in v1.

**Name:** "Glacen" — a coined word (not a dictionary word) blending "glass" and "glacial calm," chosen after Reddit's own name and Reddit's trademark had to be avoided for an unofficial third-party client, and after checking that no existing app or product uses this name. It ties thematically to both the calm-filtering value proposition and the Liquid Glass visual language. Bundle ID: `com.kounex.glacen` (matching the `com.kounex` prefix convention used by the sibling Antiphon project).

## 2. High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Glacen (iOS app)                     │
│                                                                │
│  SwiftUI Views  ──►  Observable view models  ──►  Services   │
│                                                                │
│   Services:                                                   │
│   • RedditClient          — OAuth (per-user), feed/vote/save │
│   • ClassificationService — routes posts to a LLM backend    │
│       ├─ CloudLLMProvider (Anthropic / OpenAI, BYO key)      │
│       └─ OnDeviceProvider (Apple Foundation Models)          │
│   • ExampleStore          — curates few-shot examples        │
│   • FilterStore (SwiftData) — tiers, confidence, decisions   │
└─────────────────────────────────────────────────────────────┘
              │                                  │
              ▼                                  ▼
     Reddit OAuth API                  SwiftData + CloudKit
     (user's own account)          (private DB, synced across devices)
```

- **Reddit access:** each user authenticates with their own Reddit account via OAuth (like the official app). This attributes API usage per-user under Reddit's free personal-use tier, rather than pooling usage through one app-level key — the approach that made pre-2023 third-party clients like Apollo economically unviable at scale.
- **Classification backends** both implement the same internal `ClassificationProvider` protocol, so they are interchangeable per user preference and equally testable via fakes.
- **Data sync:** the growing dataset (examples, filter records, instructions, settings) syncs across the user's devices via SwiftData + CloudKit. Secrets (Reddit OAuth tokens, LLM API keys) are deliberately excluded from sync and live device-local in the iOS Keychain — a conscious security default, not an oversight.

## 3. Filtering Pipeline (Data Flow)

1. **Fetch** — the Home tab pages through the user's subscribed-subreddit feed via `RedditClient`, ~25 posts per page.
2. **Classify (batched, cached)** — posts not already scored are batched into a single `ClassificationService.classify(posts:)` call per page (not one call per post). The prompt combines the global instructions, a curated slice of few-shot examples from `ExampleStore`, and the batch of posts. Both providers return a **raw confidence score (0.0–1.0)** per post — a likelihood of negativity/bait/slop — not a tier directly.
3. **Bucket client-side** — the user's adjustable strictness setting maps that raw score to Safe / Review / Hidden locally. Moving the strictness slider re-buckets already-scored posts instantly with no new LLM calls; only edited instructions or a materially different example set invalidate a cached score.
4. **Cache & staleness** — scores are stored keyed by post ID plus the `InstructionSet` version they were scored under. Editing the instructions increments that version; previously scored posts are treated as stale and re-classified lazily, the next time they'd be displayed — not via an eager mass re-classify.
5. **Review loop** — on any post, regardless of current tier (Safe, Review, or from the Filtered tab), the user can correct the decision: "this is fine" or "this should be filtered." This immediately overrides that post's effective tier and writes/updates a labeled `Example`.
6. **Example curation** — the few-shot block injected into each classification prompt is capped (roughly 20–30 examples, recency-weighted) so prompt size stays bounded as the dataset grows into the hundreds.

## 4. Confidence Tiers & Presentation

Three tiers, computed client-side from the raw confidence score and the user's strictness setting:

- **Safe** — shown normally, no visual treatment, no badge. The calm default.
- **Review** — borderline confidence. Shown in the feed with a visual treatment the user can switch between two interchangeable, both-implemented styles (a live settings toggle, not a one-time design decision):
  - *Blurred card* (default) — the full card renders with the title blurred and an amber confidence badge ("Review · 61%"); tapping reveals it with a spring blur→clear transition.
  - *Collapsed row* (alternate) — condensed to a single line ("1 post held for review · 61%") that expands to the full card on tap via a `GlassEffectContainer` morph.
- **Hidden** — high-confidence negative. Excluded from the Home feed entirely; reachable only via the separate **Filtered** tab, rendered fully desaturated/muted there since it's for deliberate audit, not casual browsing.

Strictness is a user-adjustable control (e.g., a discrete Lenient → Balanced → Strict scale), directly fulfilling the "fine-tunable in the app" requirement from the original brief.

## 5. Data Model (SwiftData + CloudKit)

- **`FilterRecord`** — postID, subreddit, title snapshot, `confidenceScore`, `instructionSetVersion`, `userCorrected`, `userLabel`. Tier is computed, never stored, so changing strictness never requires a migration or backfill.
- **`Example`** — post snippet, label (safe/negative), source (review-loop correction vs. manual flag), createdAt. Browsable, searchable, editable (relabel), and deletable in Settings.
- **`InstructionSet`** — the editable global filtering instructions text, version-incremented on every edit.
- CloudKit constraints apply throughout: all relationships optional, no unique constraints, all properties have defaults.
- Reddit OAuth tokens and LLM API keys are **not** SwiftData entities — they live in the Keychain, device-local, unsynced.

## 6. Navigation & Design System

**Navigation:** a 3-tab structure — **Home** (feed), **Filtered** (the Hidden/Review audit list — this is where the review loop primarily lives), **Settings** (account, backend/key management, strictness, display-style toggle, instructions editor, dataset browser). Each tab owns its own `NavigationStack`. No dedicated Saved tab in v1 — saved posts are reachable from Home/Settings.

**Visual language:**
- True near-black background (not dark gray), maximizing contrast for Liquid Glass surfaces to refract against.
- Real Liquid Glass APIs throughout — `.glassEffect(.regular, in:)` on feed cards, `GlassEffectContainer` for morphing transitions, `.buttonStyle(.glassProminent)` for primary actions, native Liquid Glass `TabView`/`NavigationStack` chrome. This is a deliberate departure from the hand-rolled `.ultraThinMaterial` approach used in the sibling Antiphon project — Glacen uses Apple's actual iOS 26 Liquid Glass system, not a custom approximation.
- One calm accent color (cool ice-blue/teal, echoing the "glass/glacial" identity) for interactive elements — never Reddit's orange, to avoid any visual association with alarm or urgency.
- Amber is reserved exclusively for the Review-tier badge. Hidden-tier entries are desaturated/muted, not colored — they should compete for attention as little as possible.
- System SF Pro typography with full Dynamic Type support — no custom/rounded font family. The goal is to feel like a natural extension of iOS 26 itself, not a distinct brand skin.
- Motion: spring transitions for blur→clear reveals; glass morphing for the collapsed-row expansion.

**Onboarding:** Reddit OAuth → choose a classification backend (on-device toggle, or paste a cloud API key) → land on Home. No calibration quiz — the dataset builds naturally through the review loop during real use. A sensible default `InstructionSet` (covering common bait/rage patterns) ships with the app so day one isn't unfiltered.

## 7. Error Handling & Edge Cases

- **No working classifier** (no API key set, on-device unavailable or disabled) — never blocks browsing. A dismissible banner explains the situation; posts display unfiltered.
- **Classification call fails** (timeout, rate limit, invalid key) — affected posts land in **Review**, never silently Safe and never silently Hidden. Uncertainty is represented honestly.
- **Reddit token expiry** — silent OAuth refresh; a re-login prompt appears only if refresh itself fails, and never touches local dataset/settings.
- **Cold start** (zero examples yet) — filtering runs zero-shot against the default instruction template until the dataset accumulates.
- **Removed/deleted Reddit posts** — filtered out as ordinary client hygiene, unrelated to the negativity classifier.

## 8. Testing Strategy

Business logic — score-to-tier bucketing, example curation/sampling, staleness checks — is pure and unit-tested with **Swift Testing**. `RedditClient` and `ClassificationProvider` are protocols so tests run against fakes, never live network or LLM calls. Liquid Glass rendering and interaction feel are validated manually on-device; visual glass effects are not meaningfully snapshot-testable.

Per explicit direction from the project owner: implementation proceeds carefully and incrementally, with a review/verification checkpoint at each step rather than a single unaudited pass, to keep the codebase maintainable and correct as it grows.

## 9. Explicitly Out of Scope for v1

macOS app · comment-thread filtering · per-subreddit instruction overrides · subscription/hosted-LLM billing · posting/commenting/direct messages · r/all, r/popular, or subreddit search/discovery beyond the user's own subscriptions · dataset export/import · a stats/analytics dashboard · widgets, share extension, or push notifications.

## 10. Tooling & Project Conventions

- **Project generation:** XcodeGen with a `project.yml` spec (no committed `.xcodeproj`), matching the Antiphon sibling project's convention for clean git history.
- **Concurrency:** Swift 6 strict concurrency, `@MainActor`-isolated UI layer, matching Antiphon's precedent.
- **Repository:** Glacen is its own independent git repository (nested alongside, not merged with, the Antiphon repo).
