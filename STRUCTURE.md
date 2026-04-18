# Sabi — Structure Outline

*CRISPE Phase 4. Shape of the system before we write code. ~2 pages, like a C header file.*
*Drafted April 17, 2026.*

---

## What this doc is

A high-level map of Sabi's modules, the data flow through one ping cycle, the Swift protocols that hold them together, and the open questions the structure surfaces. It's the thing the slice plan gets ordered against.

**What this doc is not:** code, a tutorial, a tactical plan. No Swift syntax. No pseudocode beyond protocol shapes.

---

## Module map

Seven components. Each does one thing.

1. **`MenuBarApp`** — SwiftUI entry point. Owns the `MenuBarExtra` scene, the icon (with/without dot), and the popover window. Pure shell. No business logic.

2. **`IntentStore`** — persists the user's *current* declared intent: the seed string (what they typed) and the refined, user-confirmed version (what Sabi searches for). One active intent at a time in v1. Backed by SQLite or plist.

3. **`AugmentFlow`** — given a seed string, calls `LLMProvider` to produce a refined intent, then shows it to the user for confirm-or-edit. Writes the confirmed intent to `IntentStore`. This is the "user in driver's seat" gate from decision #1.

4. **`RetrievalEngine`** — given the current intent + a domain allowlist, calls `SearchProvider` (Brave). Returns N candidate links (title, URL, snippet, domain). Doesn't rank.

5. **`RankingEngine`** — given candidates + current intent + recent feedback history, calls `LLMProvider` to pick one winner. Returns `{candidate, internalReason}`. Reason is stored for debugging, never shown to user (decision #6).

6. **`PingQueue`** — holds the queue of pings to show. Respects the user-capped daily max from `Settings`. Decides when to flag the menu bar icon with a dot. Delivers one ping at a time to the popover.

7. **`FeedbackLoop`** — records thumbs-up / thumbs-down per ping. Summarizes recent feedback into a short "what this user liked / disliked" string that `RankingEngine` includes in its next prompt. No fine-tuning, no embeddings — just a rolling summary in the prompt context.

Plus one transversal: **`Settings`** — daily ping cap (slider), intent entry/edit entry point, first-run onboarding. Writes to `IntentStore` and its own preferences store.

---

## Data flow — one full ping cycle

```
           ┌─ first run or intent edit ─┐
           ▼                            │
   [user types seed]                    │
           │                            │
           ▼                            │
   AugmentFlow ──calls──► LLMProvider   │
           │                            │
           ▼                            │
   [user confirms refined intent]       │
           │                            │
           ▼                            │
   IntentStore.set(intent) ─────────────┘

           ┌─ trigger fires (scheduled or manual) ─┐
           ▼
   RetrievalEngine ──calls──► SearchProvider (Brave)
           │
           ▼ [N candidates]
   RankingEngine ──calls──► LLMProvider (with intent + feedback summary)
           │
           ▼ [one winner]
   PingQueue.enqueue(ping)
           │
           ▼
   MenuBarApp.showDot()
           │
           ▼
   [user clicks icon]
           │
           ▼
   Popover shows {title, URL, thumbs-up / thumbs-down}
           │
           ▼
   [user clicks link → opens in browser]
           │
           ▼
   [user clicks 👍 or 👎]
           │
           ▼
   FeedbackLoop.record(ping, thumbs)
           │
           ▼
   (next cycle includes this in the prompt)
```

---

## Key interfaces (Swift protocol sketches)

These are the abstraction boundaries. Each one has one production implementation and potentially one test/mock implementation. The `LLMProvider` interface is what lets us swap Haiku for a local model without a rewrite (insurance from the Budget section of the Design Doc).

```swift
protocol LLMProvider {
    func augmentIntent(seed: String) async throws -> RefinedIntent
    func rankCandidates(_ candidates: [Candidate],
                       intent: RefinedIntent,
                       feedbackSummary: String?) async throws -> RankedPing
}

protocol SearchProvider {
    func search(query: String,
               allowedDomains: [String]?) async throws -> [Candidate]
}

protocol IntentStore {
    func current() -> RefinedIntent?
    func set(_ intent: RefinedIntent)
}

protocol PingStore {
    func enqueue(_ ping: Ping)
    func unreadCount() -> Int
    func next() -> Ping?
    func markRead(_ ping: Ping)
    func recordFeedback(_ ping: Ping, thumbs: Thumbs)
    func recentFeedback(limit: Int) -> [FeedbackRecord]
}
```

Five core types:

- `RefinedIntent` — the seed + the refined string + timestamp
- `Candidate` — title, URL, snippet, domain
- `RankedPing` — the winning candidate + internal reason
- `Ping` — a queued/shown candidate with state (pending, shown, read)
- `FeedbackRecord` — ping + thumbs + timestamp

---

## Dependency graph

Natural slice ordering falls out of this. Arrows read "depends on."

```
  MenuBarApp ──► (nothing — pure shell)
  IntentStore ──► (nothing — pure storage)
  Settings ──► IntentStore

  AugmentFlow ──► LLMProvider, IntentStore, MenuBarApp (UI)
  RetrievalEngine ──► SearchProvider, IntentStore
  RankingEngine ──► LLMProvider, RetrievalEngine
  PingQueue ──► RankingEngine, PingStore
  FeedbackLoop ──► PingQueue, PingStore
```

Everything eventually funnels into `MenuBarApp` for display.

---

## Proposed resolutions to "Still open" questions

Structure forces us to commit on a few things the Design Doc left open. Proposing these for ratification:

- **What triggers a ping?** → v1: scheduled (every 4 hours, configurable) + a manual "Sabi now" menu item. Respects the daily cap. Simpler than a quality gate; quality gate is v2 once we have feedback data.
- **Augment step UX** → modal sheet inside the popover with the refined intent as editable text. Two buttons: "Looks good" and "Start over." No categories, no multi-step wizard. Maybe 2 screens total for the flow.
- **First-run onboarding** → install → icon appears → click icon → empty popover with "What are you learning right now?" text field → type → augment flow → confirm → Sabi starts. Three visible states. No splash screen, no account creation.

---

## Observations from drawing the boxes

- **`LLMProvider` is called twice per cycle** (augment, then rank). Build a thin cache layer so the same intent doesn't re-augment on every session.
- **`PingQueue` needs a scheduler.** Swift has `Timer` and `BGAppRefreshTask`; menu bar apps are tricky for background work because macOS can suspend them. Expect this to be a real slice-1/2 problem.
- **`FeedbackLoop` summary is a prompt detail, not a database.** Keep it as a rolling string we regenerate from the last ~20 records, not something we version.
- **Error states:** Brave returns nothing, LLM returns garbage, user is offline, daily cap hit, intent is empty. Each needs a deliberate empty state in the popover, not a stack trace.
- **Domain allowlist:** for v1, ship a hardcoded default list (arXiv, Anthropic Blog, OpenAI Blog, HumanLayer, Hacker News, a handful of curated sources). User-editable in v2.

---

## What's next

- Ratify the three "Still open" resolutions above (or push back).
- Write the slice plan — ordered vertical slices based on this dependency graph.
- Start executing, one slice at a time, reading every diff.

---

## Change log

- **2026-04-17 (evening):** First draft. Module map, data flow, protocol sketches, dependency graph, proposed resolutions for trigger / augment UX / onboarding.
