# Sabi

A macOS menu bar app that quietly watches the web for what you're learning — and pings you when something new is worth reading.

Built for the OpenAI × Handshake Codex Creator Challenge (April 17–30, 2026).

## What Sabi does

You type what you're currently learning — vague is fine, like "AI" or "black holes" or "industrial policy" — and Sabi:

1. Refines your seed into a specific learning focus (Haiku).
2. Searches a curated allowlist of ~60 high-signal sources (Brave Search API, site-restricted).
3. Ranks results against your focus (Haiku again).
4. Every few hours in the background, re-checks for brand-new past-week content and sends a single notification only if something new cracks your top 5.

No algorithmic feed, no social, no ads. Curated sources, low-frequency pings, configurable. Designed for college students in the "know-it-all circles" (arXiv, Distill, LessWrong, Stratechery, dwarkeshpatel.com, Dan Luu, etc.) who don't want another doomscroll but do want to hear when something hits their lane.

## Current state

**Feature-complete MVP.** Every vertical slice from seed-to-notification is shipped and working end-to-end:

- **Slice 1** — Menu bar app + SwiftUI popover (`MenuBarExtra`).
- **Slice 2** — Anthropic Messages API round-trip + intent persistence.
- **Slice 2b** — Haiku-powered seed augmentation with overfitting-aware prompt.
- **Slice 3** — Brave Search retrieval filtered by a curated domain allowlist.
- **Slice 4** — Haiku re-ranker + macOS `UNUserNotificationCenter` banners.
- **Slice 5** — Minimum lovable copy pass, freshness signals, path-shape article filter, dynamic char-budget batching to respect Brave's 400-char query limit.
- **Slice 6** — User-editable sources. Add, disable, remove. Persisted to UserDefaults.
- **Slice 7** — `NSBackgroundActivityScheduler` polling every ~4h with a seen-URL log so you never get pinged twice about the same thing.

## How it works

```
your seed (vague)
  │
  │  AugmentPrompt + Haiku
  ▼
specific learning focus
  │
  │  Retrieval (Brave + allowlist + freshness filter + article-shape filter)
  ▼
candidate articles
  │
  │  Ranker + Haiku
  ▼
top results, best-first
  │
  ├──> Manual Fetch: shown in the popover, marked as "seen"
  └──> Background poll every ~4h: past-week only, notify on first unseen top-5 hit
```

## Build locally

Requires macOS 14+ and Xcode 16+.

```bash
git clone https://github.com/olsen-chainwork/sabi.git
cd sabi
open Sabi/Sabi.xcodeproj
```

Paste your API keys into `Sabi/Sabi/Secrets.swift`:

- Anthropic key — console.anthropic.com → Settings → API Keys
- Brave Search key — api-dashboard.search.brave.com → API Keys (free tier is fine)

`Secrets.swift` is gitignored. Do not commit real keys.

Build and run (`⌘R`). The Sabi binoculars icon shows up in your menu bar. Click it, type what you're learning, hit Fetch.

## Tech stack

- **Swift 6 + SwiftUI** with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — everything's main-actor by default; nonisolated is opt-in for things that need it (API clients, pure data types).
- **`MenuBarExtra`** scene for the popover; **`Settings`** scene for the sources editor.
- **`@Observable`** singletons for state (intent, sources, polling prefs, seen log) persisted to UserDefaults.
- **`NSBackgroundActivityScheduler`** for polling — respects battery, thermal state, and power source.
- Anthropic Haiku 4.5 for both augmentation and ranking. Brave Search Web API for retrieval.

Runtime budget: ~$40/mo at heavy use (see [DESIGN-DOC.md](DESIGN-DOC.md)).

## Project artifacts

- [DESIGN-DOC.md](DESIGN-DOC.md) — locked decisions, constraints, tech stack, scope, success scene
- [STRUCTURE.md](STRUCTURE.md) — high-level phases
- [SLICES.md](SLICES.md) — vertical slice plan
- [BUILD-NOTES.md](BUILD-NOTES.md) — per-slice build diary
- [research.md](research.md) — CRISPE Phase 2 landscape research

## What's left

1. Landing page (live URL for contest)
2. Pitch video
3. Handshake submission

## Status

```
Commits:         11
Slices shipped:  7 / 7
Runtime:         working end-to-end on macOS 14+
```
