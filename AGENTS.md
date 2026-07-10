# Glacen — Agent Baseline

Glacen is an unofficial, calm-first Reddit client for iOS whose core purpose is filtering negativity, bait, and low-effort "slop" out of a user's feed using an LLM the user controls, with a manual review loop that improves accuracy over time.

## Current status (as of 2026-07-10) — BLOCKED on Reddit API access

Milestone 1 (foundation, OAuth, read-only home feed — see `docs/superpowers/plans/2026-07-10-foundation-oauth-home-feed.md`) is **code-complete**: all 13 implementation tasks done, spec-reviewed and code-reviewed with fixes applied and re-verified, 31 tests passing, through commit `c94276e`. Source pushed to `https://github.com/Kounex/glacen` (public).

**What's blocking further progress:** Task 14 (manual end-to-end OAuth verification) needs a real Reddit API client ID, but Reddit closed self-service OAuth app creation in November 2025 (the "Responsible Builder Policy") — new API access now requires submitting a request form and waiting for manual approval, which can take days to weeks or be rejected. An application was submitted on 2026-07-10 via Reddit's developer request form (category: "developer... app that does not work in the Devvit ecosystem"), citing `https://github.com/Kounex/glacen` as the source link — full submitted answers recorded in [`docs/2026-07-10-reddit-api-access-request.md`](docs/2026-07-10-reddit-api-access-request.md). **This blocks the entire project, not just Task 14** — without Reddit API access, the app has no data source at all, so nothing downstream is worth building until access is granted.

**When resuming:** check whether Reddit has responded (approved, rejected, or asked follow-up questions) before doing anything else. If approved: export the real `REDDIT_CLIENT_ID`, complete Task 14's manual checklist in the plan doc (the plan also calls out an extra check worth adding — force-quit/relaunch with a valid stored token should skip login, and backgrounding/rotating during an active feed load should NOT reset the feed, per a reviewer's flagged-but-unverified SwiftUI state-identity claim). If rejected: the appeal/reapplication approach needs to be decided with the user before writing more code.

**Roadmap after Task 14 unblocks** (each gets its own plan written when work starts on it, not before):
- M2: Post detail/comments view, vote, save
- M3: SwiftData models + `ClassificationProvider` protocol + cloud/on-device providers + `ExampleStore`
- M4: Wire classification into Home, strictness setting, Review/Hidden tier UI, Filtered tab
- M5: Review loop corrections, Settings screens (backend picker, instructions editor, dataset browser)
- M6: CloudKit sync, error-handling banners, onboarding polish

**Full design spec:** [`docs/superpowers/specs/2026-07-10-glacen-design.md`](docs/superpowers/specs/2026-07-10-glacen-design.md) — read this before making architectural or product decisions. It is the source of truth for scope, data flow, data model, design system, and what is explicitly out of scope for v1. This file is a working summary; the spec is authoritative where they diverge.

## What v1 is

iOS only (iOS 26+). Read + vote + save on the user's subscribed-subreddit feed. Post-level filtering only (not comments). One global instruction set and example dataset (no per-subreddit rules). Classification via a user-supplied cloud API key (Anthropic/OpenAI) or Apple's on-device Foundation Models framework. No subscriptions, no hosted LLM, no payment infrastructure.

## What v1 is explicitly not

macOS, comment filtering, per-subreddit rules, subscriptions/billing, posting/commenting/DMs, r/all or search beyond the user's own subscriptions, dataset export/import, analytics dashboards, widgets, notifications. Do not add these without an explicit ask — see spec §9.

## Core architectural rules

- **Reddit access** is always per-user OAuth (the user's own Reddit account), never a pooled app-level key.
- **Classification** returns a raw 0.0–1.0 confidence score. Tier (Safe/Review/Hidden) is *computed client-side* from that score and the user's strictness setting — never stored as a persisted tier, so adjusting strictness never requires a data migration.
- **Secrets** (Reddit OAuth tokens, LLM API keys) live in the Keychain, device-local, and are excluded from CloudKit sync. Only the dataset (examples, filter records, instructions, settings) syncs.
- **Fail-open, not fail-closed:** if classification fails or is unavailable, never block browsing. Failed classifications land in Review (honest uncertainty), not Safe or Hidden.
- **Both Review-tier display styles** (blurred card, collapsed row) are implemented and live-swappable via Settings — this was an explicit decision to keep for comparison, not a placeholder for a future removal.
- Liquid Glass means Apple's actual iOS 26 `glassEffect()`/`GlassEffectContainer` APIs — not hand-rolled `.ultraThinMaterial` blur. This is a deliberate departure from the sibling Antiphon project's approach.

## Process expectations

- Implementation proceeds carefully and incrementally, with a review/verification checkpoint at each step — not a single large unaudited pass. This was explicit direction from the project owner and applies to every implementation phase.
- Business logic (tier bucketing, example curation, staleness checks) must be unit-testable via Swift Testing against protocol-based fakes for `RedditClient` and `ClassificationProvider` — never live network/LLM calls in tests.
- Swift 6 strict concurrency, `@MainActor`-isolated UI layer.
- Project is generated via XcodeGen (`project.yml`); do not commit a `.xcodeproj`.

## Sibling project

`../antiphon` is a separate, unrelated project (Spotify↔Apple Music sync) by the same author. Its `DESIGN.md` and `docs/ARCHITECTURE.md` are useful precedent for tooling conventions (XcodeGen, Swift 6 concurrency) but its hand-rolled glassmorphic design system is explicitly *not* the visual direction for Glacen — see spec §6.
