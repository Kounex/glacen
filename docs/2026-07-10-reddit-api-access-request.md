# Reddit API Access Request (Submitted 2026-07-10)

Record of the Data Access Request submitted to Reddit under the Responsible Builder Policy (https://support.reddithelp.com/hc/en-us/articles/42728983564564-Responsible-Builder-Policy), since self-service OAuth app creation was closed in November 2025. Kept here for reference in case Reddit follows up with questions, or in case of a rejection/appeal.

See AGENTS.md for how this blocks the project, and docs/superpowers/plans/2026-07-10-foundation-oauth-home-feed.md Task 14 for what happens once access is granted.

The answers below are plain text, ready to copy-paste directly into the form fields.

## Submitted answers

What do you need assistance with?

Data Access Request

Your email address

contact@kounex.com

Which role best describes your reason for requesting API access?

I'm a developer

What is your inquiry?

I'm a developer and want to build a Reddit App that does not work in the Devvit ecosystem.

Reddit account name

Kounex

What benefit/purpose will the bot/app have for Redditors?

Glacen is a personal-use, non-commercial third-party Reddit client for iOS. Its purpose is to let a Redditor read their own home feed (the subreddits they're already subscribed to) with an optional content-filtering layer that flags low-effort, inflammatory, or "engagement-bait" posts so the reader can choose to skip them. For example: a sensationalized, all-caps outrage-bait title in a hobby subreddit, or a low-effort meme repost with no discussion value, would be flagged with a "Review" label and a confidence score; the user can still open it, or leave it collapsed. Nothing is hidden without the user being able to see and override it; every classification can be manually corrected, and corrections are stored locally to improve future filtering for that person. The app only ever displays content the authenticated Redditor could already see in their own feed; it changes presentation and ordering, not access. No other users' data is read, and no automated posting, commenting, or voting occurs; every action (voting, saving) is a manual tap by the person using the app on their own account.

Provide a detailed description of what the Bot/App will be doing on the Reddit platform.

Glacen performs the following actions, all under the authenticated end user's own OAuth token, never a shared app-level or bot account.

1) Authentication: standard OAuth2 PKCE "installed app" flow via reddit.com/api/v1/authorize.compact, requesting scopes identity, read, mysubreddits, vote, save. The user logs in and consents inside Reddit's own web view. Glacen never sees or stores the user's Reddit password.

2) Reading the feed: on app launch, and later on user-initiated pull-to-refresh or scroll, Glacen calls GET oauth.reddit.com/best with limit=25 and an after cursor for pagination, the same endpoint and parameters the official Reddit app uses for a personalized home feed. No background polling; requests only happen while the app is actively in use.

3) Displaying posts: for each post returned, Glacen shows title, subreddit, author, score, and comment count in its own native interface. Example: a post titled "New display tech could double OLED lifespan" from r/technology by u/someuser is rendered as a card showing its score and comment count.

4) Optional content filtering (client-side only, not a Reddit API interaction): separately from the API calls above, the title/body of an already-fetched, already-visible post may be passed to an LLM the user has chosen and authenticated (either Apple's fully on-device model with no network call at all, or a cloud LLM API using the user's own key), purely to flag it for that user's own display, for example "possibly low-effort/inflammatory, 61% confidence." This never changes what's accessible on Reddit; the user can always open any post regardless of the flag. It only changes how already-accessible content is visually presented to that one user.

5) Voting and saving: a user tapping upvote, downvote, or save in the app triggers a single POST oauth.reddit.com/api/vote or /api/save call, exactly as tapping the equivalent button in Reddit's own app would. Always one manual, human-initiated tap; no batching, scripting, or automated voting/saving.

6) What Glacen does not do: no new post submissions, no comment posting or editing, no private messages, no following or moderation actions, no autonomous or scheduled activity of any kind, no scraping or storage of other users' data, and no dedicated bot/service account. Every action runs under the individual end user's own identity, triggered only by their own explicit tap in the app.

What is missing from Devvit that prevents building on that platform?

Devvit apps run inside Reddit's own client as subreddit-scoped extensions, custom post types, or moderation automation; they don't support building an independent native iOS app with its own interface that a Redditor installs and uses outside Reddit's own app. Glacen needs: (1) a native SwiftUI interface with its own navigation and design, separate from Reddit's UI; (2) on-device processing via Apple's Foundation Models framework for private, offline content classification, unavailable in Devvit's JavaScript/TypeScript sandbox; (3) local on-device storage (SwiftData) of each user's personal filtering preferences, synced via their own iCloud account; and (4) a personal, per-user OAuth session so each Redditor reads their own subscribed feed in their own separate app instance, rather than one subreddit-installed app serving every visitor identically. None of this fits Devvit's in-platform execution model.

Provide a link to source code or platform that will access the API.

https://github.com/Kounex/glacen

What subreddits do you intend to use the bot/app in?

None specifically. Glacen isn't a subreddit-specific bot or moderation tool. Each authenticated user reads their own home feed made up of whichever subreddits they personally subscribe to; there's no fixed target list and no bot account operating within any particular subreddit.

If applicable, what username will you be operating this Bot/App under? (optional)

N/A. Not a bot account; each end user authenticates with their own personal Reddit account, and the app has no dedicated bot/service account.

Attachments (optional)

None submitted.

## Status

Submitted 2026-07-10. Awaiting response.
