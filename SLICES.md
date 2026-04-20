# Sabi — Slice Plan

*CRISPE Phase 5. Ordered vertical slices. Each one ships end-to-end.*
*Drafted April 17, 2026. 13 days to submission (April 30).*

---

## Ordering principle

Slices are ordered by **risk retirement**, not by dependency cleanliness. The earliest slices answer the questions most likely to kill the project:

1. Can Chandler get a Swift menu bar app running at all? (He's never written Swift.)
2. Can we make an Anthropic API call from Swift and parse the response?
3. Can we hit the Brave Search API and get usable candidates?
4. Does Haiku actually pick a good link from those candidates? (The product hypothesis.)

If any of those fail hard, we either pivot (Tauri fallback per Design Doc) or rescope. Everything else stacks on top.

Each slice is **thin + end-to-end**. No horizontal layers. No building all the plumbing first. Each slice produces something user-visible, even if ugly.

---

## Slice 1 — Menu bar hello world

**Why first:** the single biggest unknown is "can Chandler ship any Swift Mac app." Everything else depends on it. This slice is the Swift onboarding + end-to-end plumbing test wrapped into one.

**Deliverable:** Xcode project that builds, a menu bar icon appears when run, clicking the icon opens a popover that says "Sabi." Closing/reopening the app works. Nothing else.

**Code touched:** `MenuBarApp` only. ~50–100 lines of Swift.

**Verification:**
- `cmd+R` in Xcode → icon appears in menu bar
- Click icon → popover opens, says "Sabi"
- Click elsewhere → popover closes
- Quit app → icon disappears

**Risks:**
- Xcode setup, code signing certificates, provisioning — can eat hours. Stay unsigned for dev.
- `MenuBarExtra` has macOS version requirements (Ventura 13+ for most features).

**Budget impact:** $0. No API calls.

**Day budget:** Days 1–2. If not shipped by end of day 3, invoke Tauri fallback per Design Doc.

**Fallback trigger:** end of day 3 with no working menu bar icon → stop, move to Tauri + TypeScript stack.

---

## Slice 2 — Intent + augment + confirm

**Why second:** tests the LLM integration on the simplest call. One API request, one response, stored locally. If this breaks, we learn early whether the friend's API key works and whether we can parse Anthropic responses from Swift.

**Deliverable:** popover has a text field ("What are you learning right now?"), an "Augment" button. Click Augment → Haiku returns a refined intent → shown as editable text → "Looks good" button stores it to `IntentStore`. Restart app → refined intent is still there.

**Code touched:** `IntentStore`, `AugmentFlow`, `LLMProvider` (Anthropic implementation), minimal popover UI. API key read from `.env` or a hardcoded constant for dev.

**Verification:**
- Type "AI stuff I'm learning" → click Augment → get back something specific (e.g., "Context engineering for coding agents, CRISPE workflow, agent prompt design")
- Click "Looks good" → quit app → relaunch → see the refined intent persisted
- Try with a non-sense seed → see what Haiku does (error states become visible)

**Risks:**
- API key handling in Swift (`.env` loader, Keychain, or just a constant-for-dev approach).
- JSON parsing of Anthropic response.
- Haiku's augment quality with no examples — might need prompt iteration.

**Budget impact:** ~$0.005 per augment call. Probably $0.10 total across dev testing.

**Day budget:** Days 3–4.

---

## Slice 3 — Retrieval from Brave

**Why third:** the other external API. Independent of the LLM path except it reads from `IntentStore`. Tests whether we can get good candidates from Brave with the intent string as a query.

**Deliverable:** given the current intent, a "Sabi now" button fetches from Brave and shows the raw candidate list in the popover (title + URL, no ranking yet). Domain allowlist is applied.

**Code touched:** `RetrievalEngine`, `SearchProvider` (Brave implementation), domain allowlist (hardcoded constant for v1).

**Verification:**
- Intent: "context engineering for coding agents" → click "Sabi now" → see 5–10 real URLs from arXiv, Anthropic Blog, HumanLayer, etc.
- No allowlist violations (no random news sites showing up)
- Query fails gracefully when offline

**Risks:**
- Brave API key signup (5 min, no card)
- Brave's `result_filter` / domain filter syntax — needs docs check.
- Query construction: does passing the refined intent directly work, or do we need to extract keywords?

**Budget impact:** $0 (Brave free tier 2k/month; we'll use maybe 20 queries during this slice).

**Day budget:** Day 5.

---

## Slice 4 — Ranking + one ping (END-TO-END)

**Why fourth:** the killer slice. First moment the product actually behaves like a product. Take Brave's candidates, hand them to Haiku with the intent, get one winner back, show it in the popover.

**Deliverable:** click "Sabi now" → Brave fetch → Haiku ranks → one ping shows in popover with title + URL. Click link opens it in browser. This is Sabi's success scene running end-to-end for the first time.

**Code touched:** `RankingEngine`, `PingQueue` (simplest version — just holds the latest ping), popover view with link+click.

**Verification:**
- The Success Scene from the Design Doc: intent is about CRISPE / coding agents → click Sabi now → ping comes back about context engineering or related → it's actually good → click link → opens in browser.
- Try with 3 different intents. Does the winner feel right for each?
- If the winner feels consistently bad, iterate on the ranking prompt before moving on.

**Risks:**
- **Ranking prompt quality.** This is where the product lives or dies. Budget 1–2 days for prompt iteration if needed.
- Token budget in the prompt: 10 candidates × ~200 tokens each = 2k in. Stays within Haiku's limits easily.

**Budget impact:** ~$0.003 per ranking call. $0.30 across dev testing.

**Day budget:** Days 6–7. Add a half-day for prompt iteration if early tests are rough.

**Gate:** if after 2 days of prompt iteration the rankings still feel bad, re-evaluate model choice (upgrade to Sonnet 4.6 for ranking only — still affordable at ~$0.02/call, ~1,500 calls on $40).

---

## Slice 5 — Feedback + daily cap

**Why fifth:** closes the learning loop. Product works without it; product doesn't *improve* without it. Also validates that feedback signal actually changes ranking in a visible way.

**Deliverable:** each ping shows 👍 / 👎 buttons. Feedback persists. A rolling feedback summary (last ~20 records, compressed to a short string by Haiku or a hardcoded template) gets included in the next ranking prompt. `Settings` has a slider for daily max pings (5–15, default 10). Cap is enforced.

**Code touched:** `FeedbackLoop`, `PingStore` (feedback table), `Settings` view, ranking prompt gets a new section for "user's recent preferences."

**Verification:**
- Thumbs down a ping → click Sabi now again → get a different kind of result
- Thumbs up another kind of content → see that style reflected in later pings
- Cap at 5/day → after 5 pings, "Sabi now" is disabled or shows "daily cap hit"

**Risks:**
- Feedback-summary-to-prompt is easy to get wrong. Keep it dumb: concatenate the 5 most-recent-thumbs-down URLs with their domains, tell Haiku "avoid this kind."
- Daily cap reset at local midnight — watch out for timezone edge cases.

**Budget impact:** minor. Feedback summaries add ~100 tokens to each ranking prompt.

**Day budget:** Days 8–9.

---

## Slice 6 — Scheduler + auto-trigger (optional)

**Why sixth:** makes Sabi autonomous. Without it, user must click "Sabi now." With it, pings arrive on their own every N hours. This is the "feels like a product" slice — but it's also the most macOS-gotcha-prone slice. **Cuttable if days run short.**

**Deliverable:** menu bar icon shows a dot when a new ping is queued. Scheduler fires every 4 hours (configurable) while app is running. Icon dot clears when user reads the ping.

**Code touched:** Swift `Timer` (foreground polling) as the simple path, `BGAppRefreshTask` as the "right way" if we have time. Menu bar icon state.

**Verification:**
- Leave Sabi running 4 hours → see a dot appear on the icon automatically
- Click icon → ping appears → dot clears

**Risks:**
- macOS suspends menu bar apps. `BGAppRefreshTask` needs entitlements and specific configuration. Could burn a full day.
- `Timer` while foreground is trivial but stops when app is suspended.

**Cut criterion:** if we're at end of day 10 and slices 1–5 aren't all shipped, **skip this slice**. Sabi works manually. Users click "Sabi now" when they want a ping. Ship that version; mention auto-trigger as "v1.1" in the pitch.

**Budget impact:** $0 (no new API calls; same cycle on a timer).

**Day budget:** Day 10.

---

## Slice 7 — Polish + onboarding + landing page + pitch video

**Why last:** this is submission prep. Product is working; now we make it look professional for judges.

**Deliverable breakdown:**

- **First-run onboarding:** install → icon → click → popover shows "What are you learning?" → walk user through augment → confirm → first ping arrives.
- **Empty states:** no intent set, API error, Brave returned zero results, daily cap hit, offline. Each with a clear one-line message.
- **Landing page:** static HTML on Vercel free tier. Above the fold: what Sabi is in 5 seconds (contest criterion #1), a screenshot or short GIF, a "download" link (GitHub release), and the "built with Claude Code, runs on Claude Haiku" line.
- **Pitch video:** 60–90 seconds. Success scene recorded on Chandler's Mac. Voiceover explaining what Sabi is, who it's for, why it's different, built-with-Codex-errr-Claude story.
- **GitHub release:** unsigned `.app` bundle with a README that includes right-click-to-open instructions.

**Code touched:** onboarding flow in `MenuBarApp`, error state views, landing page in its own folder (`/sabi/landing/`), pitch video assets in `/sabi/pitch/`.

**Verification:**
- Fresh user flow: install → see icon → click → guided through → first ping → success scene works
- All error states reachable and handled cleanly
- Landing page live at a public URL, loads in 5 seconds
- Pitch video plays in QuickTime, audio levels OK, under 90 seconds
- Handshake submission draft ready with URL + description

**Risks:**
- Time. Submission prep always expands. Budget 3 days minimum.
- Pitch video quality. Do one take, don't over-produce. The product does the talking.

**Budget impact:** $0 (hosting free, recording free).

**Day budget:** Days 11–13.

---

## Slice 11 — `sabi` CLI (post-contest)

**Why it exists:** the landing page frames Sabi as *your* corner of the web — users bringing their own domains, editing sources, scripting their own pings. A menu bar popover is the right surface for *reading* a ping; it's the wrong surface for power users who want to `grep`, pipe, cron, or SSH into their taste. A CLI closes that gap and turns Sabi from an app into a tool. Explicitly **out of scope for the April 30 contest submission** — this is a post-contest slice the landing page advertises as "Coming soon" in the roadmap strip.

**Deliverable:** a `sabi` binary on `$PATH` that shares the exact same pipeline (augment → retrieve → rank → seen-log) as the menu bar app, with three subcommands:

- `sabi fetch "<seed>"` — one-shot: refine the seed, search curated sources, print ranked results to stdout (title, URL, domain, published date). Respects the same allowlist the menu bar app uses.
- `sabi sources <add|remove|list|disable|enable> [domain]` — the same sources editor, on the command line. Writes to the same UserDefaults/JSON the app reads from, so edits from either side stay in sync.
- `sabi watch` — runs the background poller in the foreground, printing a one-line log each cycle and a notification-equivalent line when a new top-5 unseen hit lands. Ctrl-C to stop. Useful for `tmux` or a launchd plist.

**Architecture:** the pipeline (`AugmentFlow`, `RetrievalEngine`, `RankingEngine`, `SourcesStore`, `SeenLog`) moves into a shared Swift package — call it `SabiCore` — with zero SwiftUI/AppKit imports. The existing macOS app links `SabiCore`; the new CLI target links `SabiCore` plus `ArgumentParser`. Both read the same `Secrets.swift` and the same on-disk state, so a `sabi sources add danwang.co` in the terminal shows up in the popover's sources sheet after a reload.

**Code touched:** new `Packages/SabiCore/` Swift package; move `Augment*`, `Retrieval*`, `Ranking*`, `Sources*`, `SeenLog*` into it; new `Sabi/CLI/` executable target wired to the same scheme; README gets a `brew tap` / install line; landing-page roadmap card promotes "sabi CLI" from "coming soon" to "shipped" once this lands.

**Verification:**
- `sabi fetch "industrial policy"` returns the same top-5 the menu bar app would, printed as clean text.
- `sabi sources add danwang.co` → open the app → sources sheet shows `danwang.co` enabled. And vice versa.
- `sabi watch` running in tmux for 4+ hours prints exactly one "new hit" line matching what the app's notification would have said.
- Both targets build clean in Xcode, both targets share one `Secrets.swift`.

**Risks:**
- Swift Package Manager + Xcode target wiring is fiddly the first time. Budget a half-day just for package layout.
- The seen-log and sources store were written against `UserDefaults` — CLI processes don't share the app's `UserDefaults` suite by default. Need a shared container (App Group) or migrate both to a JSON file in `~/Library/Application Support/Sabi/`.
- Anthropic + Brave keys in a CLI: ship with `SABI_ANTHROPIC_KEY` / `SABI_BRAVE_KEY` env-var fallbacks alongside the existing `Secrets.swift` path.

**Budget impact:** ~$0 new runtime cost (same pipeline, same per-call price). One-time dev effort: ~2 days of real work.

**Day budget:** post-contest. Not on the April 30 critical path.

**Gate:** do not start this before submission ships. Landing page advertises it as planned; users who care will ask for it and that's the signal to build.

---

## Summary table

| # | Slice | Days | Budget | Cuttable? |
|---|-------|------|--------|-----------|
| 1 | Menu bar hello world | 1–2 | $0 | No |
| 2 | Intent + augment + confirm | 3–4 | ~$0.10 | No |
| 3 | Retrieval from Brave | 5 | $0 | No |
| 4 | Ranking + one ping end-to-end | 6–7 | ~$0.30 | No |
| 5 | Feedback + daily cap | 8–9 | ~$0.20 | No |
| 6 | Scheduler / auto-trigger | 10 | $0 | **Yes** — ship manual-only |
| 7 | Polish + onboarding + landing + pitch | 11–13 | $0 | No |
| 11 | `sabi` CLI | post-contest | ~$0 | Deferred by design |
| | **Total projected runtime spend** | | **< $1** | |

Leaves ~$39 of the $40.56 as safety margin. Spend projection is for dev + demo week; if it runs high we still have an order of magnitude of headroom.

---

## Rules for the build

From Dex's CRISPE + our own locked decisions:

1. **One slice at a time.** Don't half-build two slices in parallel.
2. **Read every diff.** Non-negotiable. Slice 1's diff is your Swift tutorial.
3. **Ship each slice before moving on.** "Ship" = builds clean, runs, does what the slice says, committed to git.
4. **Don't skip ahead to polish.** Ugly working code beats pretty non-working code.
5. **If a slice runs >50% over budget on time, stop and reassess.** Don't sunk-cost.
6. **Write notes as you go.** Build journal lives in `/sabi/BUILD-NOTES.md` (create in slice 1).

---

## Change log

- **2026-04-17 (evening):** First draft of slice plan. 7 slices, risk-ordered, ~13 days. Slice 6 (auto-scheduler) marked cuttable. Pitch video + landing + onboarding collapsed into slice 7.
- **2026-04-17 (late evening):** Slice 1 shipped same day as the plan (menu bar hello world + Scout→Sabi rename).
- **2026-04-17 (late night → 2026-04-18 past midnight):** Slices 2a, 2b, 3, and 4 all shipped in one long Day 1 session. End of Day 1: core product is real (intent → retrieval → rank → notify), 5 slices in ~4 hours vs. the ~7-day budget. Swift + SwiftUI + Anthropic + Brave all integrated, all diffs read. `nonisolated` discipline for network types became muscle memory by end of slice 3.
- **2026-04-18 (Day 2):** Slices 5, 6, 7 shipped. Scope reordering vs. the original plan: (1) original slice 6 ("scheduler, cuttable") was *not* cut — it became slice 7 and is now core to the product identity. (2) Original slice 5 ("feedback + daily cap") was replaced by a copy + retrieval-hardening pass — feedback loops are deferred to post-contest because we don't have enough users to need them yet, and the daily cap is handled implicitly by BackgroundPoller's seen-log + past-week freshness. (3) Original slice 7 ("polish + onboarding + landing + pitch video") broke into its own phase after the feature slices — those are now tracked as shipping-prep tasks, not a single slice. Allowlist expanded from 17 → 60 domains in slice 5. Scheduled polling runs every 4h via `NSBackgroundActivityScheduler`.
- **2026-04-18 (late morning):** Post-feature polish pass — 5 small UX papercuts fixed. Commit `4118b49`.
- **2026-04-18 (midday):** Retrieval diversity fix — all-arxiv top-5 symptom. Root cause was batch-order pool starvation in Retrieval, not ranker bias. Added round-robin-by-host in Retrieval + 2-per-canonical-domain cap in Ranker. Commits `2fe9068`, `cabf48d`.
- **2026-04-19 onward:** Post-feature roadmap reframed into 3 new slices — **Slice 8 (visual polish):** paw icon integration + UI papercuts. **Slice 9 (speed):** end-to-end latency profiling, likely parallelizing Brave batches and caching augment output. **Slice 10 (ideas):** brainstorm + pick 1–2 cool additions for the contest window. Shipping prep (landing page, pitch video, README screenshots, Handshake submission, distribution story) is parallel to these.
- **2026-04-19 (landing page reframe):** Landing page v2 rebuilt around *user curation as the thesis* — new "Bring your own web" section, sources heading changed from "Who Sabi listens to" to "Start with 60. Replace with yours.", roadmap strip added promoting a CLI as next. Formalized that plan as **Slice 11 (`sabi` CLI, post-contest):** extract the pipeline into a shared `SabiCore` Swift package, ship a `sabi` binary with `fetch` / `sources` / `watch` subcommands, shared state with the menu bar app. Not on the April 30 critical path; advertised as "Coming soon" on the landing page.
