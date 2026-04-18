# Scout — Design Doc

*Working name. Rename when the right word lands.*
*Project started April 17, 2026. Submission due April 30, 2026 (13 days).*
*For the OpenAI × Handshake Codex Creator Challenge.*
*Following Dex's CRISPE sequence. Passed the PROJECT-PREFLIGHT filter (6/6).*

---

## One line

> **An AI scout that watches what I'm learning and pings me the best related thing I haven't found yet — no subscriptions, no feed, just "you should see this" when there's actually something worth seeing.**

---

## Who it's for (first user)

**Me — Chandler, student founder.** This week I watched 2+ hours of AI talks (Dex on CRISPE, Jess on evals), set up a personal knowledge folder, and realized I want the *next* good thing pushed to me without subscribing to a newsletter or scrolling through 40 tabs. I don't want another feed. I want one good next thing when I'm ready for it.

**Secondary user already in view:** my roommate Zane — heavy political/geopolitical content consumer who already tried to build his own social media because existing apps don't fit his behavior. He'd use this for his stuff, not mine.

## Lived-experience anchor

I built the brain this would feed. I have real, frustrated, this-week experience with subscription fatigue and AI-learning overwhelm. I am the first user, and I know exactly what it feels like when the current tools fail me.

---

## Current state (the landscape, April 2026)

Summarized from Phase 2 research — full report in [`research.md`](research.md).

**Smart readers** (Readwise, Feedly, Refind, Matter, MyMind) filter or aggregate existing feeds. None autonomously fetch new content based on declared intent. Discovery is passive (aggregation) or social (curation), not agentic.

**Menu-bar AI apps** (Raycast, Gemini Mac, multi-AI aggregators) are on-demand launchers or chat popovers. None are push-delivery scouts.

**Agentic search APIs** (Exa, OpenAI Responses API, Brave) are mature enough for an indie dev to build a content scout on top of. Perplexity Sonar returns prose, not links — doesn't fit decision #6. Bing is deprecated.

**The gap:** declared-intent + agent-fetch + one-link-push doesn't exist in the reader space. That's the seam Scout sits in.

## Patterns to follow

- **Raycast's menu-bar discipline** — clickable icon + popover, lightweight process, no dock icon.
- **Refind's "one good thing" delivery spirit** — but push (menu bar) instead of email digest.
- **CRISPE workflow** — thin vertical slices, read every diff, one feature at a time.
- **User-in-driver-seat AI** — the augment step shows refined intent for confirmation. No silent inference, no silent curation.

## Patterns to avoid

- **Feed / infinite scroll** — out of scope; fights every user-experience decision.
- **Email digest** — wrong channel for "push me one thing." Already crowded ground (Refind, newsletters).
- **Prose-summary retrieval** (Perplexity-style) — fights decision #6 (one clean link).
- **Electron weight** — 200MB+ RAM idle, 80–200MB binary. Undermines the "lives quietly in the menu bar" feel.
- **General AI assistant framing** — Scout does one verb (ping). Not a chat, not a search, not a summarizer.

---

## Locked design decisions

**1. Declared intent, not inferred.**
User types a seed → AI augments it into a sharper, more specific description of what the user is learning → user confirms or edits → the scout uses the confirmed version to find pings. The AI doesn't guess from behavior. The user is always in the driver's seat. *(This is the anti-hallucination move — the scout can't drift off into unrelated content because the intent is always explicit and user-confirmed.)*

**2. Mac-only — deliberately.**
Lives in the Mac menu bar. Positioning signal: *"if you have a Mac, this is for you."* Exclusivity is a feature, not a limitation. No Windows, iOS, Android, or Linux in v1.

**3. Menu bar UI.**
Top of the screen, non-intrusive. Clickable icon with a small indicator when there's a new ping. Can be hidden like other menu bar items.

**4. User-capped ping rate.**
User sets a daily max — e.g., 5, 10, up to 15 pings per day. Scout respects the cap. *(Trigger logic — schedule vs. on-demand vs. quality-gated — is still open.)*

**5. Thumbs up / thumbs down feedback.**
Binary. Feedback data goes back to the scout so it can learn what counts as "the best related thing" for this specific user.

**6. A ping is one clean link.**
No AI commentary, no "why I picked this" note, no ranked top-3, no synthesized digest. Title + URL + click-to-open. Reasoning: the value lives in whether the *link itself* is right. If it's right, no commentary is needed; if it's wrong, no commentary will save it. Starting minimal forces the retrieval + ranking quality to carry the product — which is where the product has to win anyway. *(Reversible in v2 if real usage says otherwise.)*

**Candidate product name: "Ping."** Parked — decided to revisit before submission. "Scout" stays as the working name in files and folders.

---

## Still open (resolve in next rounds)

- **What triggers a ping?** User-capped daily count is a quality gate, not a trigger. Does the scout run on a schedule, on-demand, or only when it clears a "good enough" bar?
- **Augment step UX.** How does the refined intent show up — editable text, topic list, natural-language summary?
- **First-run onboarding.** User installs the app. Then what?

*Resolved April 17, 2026:*

- ~~**Where do pings come from?**~~ → Brave Search API with a domain allowlist as the quality floor. Intent IS the curation (decision #1); the allowlist is the quality gate. User doesn't configure feeds.

---

## Deliberately out of scope for v1

- No feed / no infinite scroll
- No social layer / no multi-user / no sharing-with-friends
- No user-subscribed sources (the scout finds them; the user doesn't configure feeds)
- No Windows, iOS, Android, Linux
- No accounts beyond the minimum required to persist state
- No monetization, billing, or paywall

---

## Success scene (60 seconds of real use)

Monday morning. I open my laptop. The Scout icon in the menu bar has a small dot — one new ping. I click. It's an article about context engineering for coding agents, related to the CRISPE work I did last week. I read it in 8 minutes. It's actually good. I thumbs-up. The dot disappears. I go back to my work.

*This scene is also the pitch video outline.*

---

## Budget + architecture constraints

*Locked April 17, 2026. Design constraints that flow from $40.56 total runtime budget, Claude Max for dev, and zero other money.*

**Total runtime budget: $40.56** on a friend's Anthropic API account (credit grant, auto-reload disabled, expires Mar 2027). This is demo-week fuel, not dev fuel.

**Build is free.** Claude Max writes the Swift. Xcode is free from the Mac App Store. Claude Code teaches Swift in real-time through diffs — Chandler doesn't know Swift coming in, and reads every diff on the way out.

**Runtime LLM:** Claude Haiku 4.5 via Anthropic Messages API. Ranking call ≈ $0.003. Single-user demo burn rate ≈ $1–3 over the 13-day window.

**Retrieval:** Brave Search API free tier. 2k queries/month, no credit card required. Quality floor comes from a domain allowlist, not a category filter.

**State:** Local SQLite or plist on the Mac. No backend, no database hosting, no accounts.

**Landing page:** Free-tier static hosting (Vercel, Netlify, or GitHub Pages). Subdomain is fine for contest submission; no custom domain for v1.

**No Apple Developer Program ($99/yr) for v1.** Distribution for demo = GitHub release with "right-click → Open" note, or pitch-video-only. Notarization is a post-contest decision.

**LLM provider abstracted.** Code behind an `LLMProvider` interface so Haiku can swap to a local model (MLX / Ollama) without a rewrite — insurance against friend's account disappearing mid-build.

**Anti-slop rule stays: read every diff.** Non-negotiable. The whole CRISPE thesis depends on it. SwiftUI is readable enough that diff-reading is ~10 min/slice, not a Swift course.

---

## Tech stack

*Locked April 17, 2026.*

- **Language / UI:** Swift + SwiftUI. `MenuBarExtra` scene for the menu bar item. Native Mac feel (matches decisions #2 and #3), small binary (~10–20 MB), low idle memory (30–50 MB).
- **Build tool:** Claude Code via Claude Max. All code written here; every diff read.
- **Runtime LLM:** Claude Haiku 4.5 via Anthropic Messages API.
- **Retrieval:** Brave Search API free tier with domain allowlist.
- **State:** Local SQLite or plist. Single-user, no sync, no backend.
- **LLM abstraction:** `LLMProvider` interface for swap-out resilience.

**Fallback plan:** If slice 1 (menu bar icon → popover → hello world in SwiftUI) isn't shippable by day 3, re-evaluate. Tauri (TypeScript/React) is the backup stack — heavier binary but closer to web familiarity. Don't sunk-cost into a framework that isn't working.

---

## Slice plan

TBD. Written after the structure outline.

---

## Change log

- **2026-04-17 (morning):** Project started. Idea locked after running the 6-point PROJECT-PREFLIGHT filter (6/6). Working name: "Scout." Five design decisions locked in first round of clarifying questions.
- **2026-04-17 (afternoon):** Sixth design decision locked — a ping is one clean link (no AI note, no top-3, no digest). Candidate product name "Ping" parked for later. Clarifying questions phase closed. Moving to Research.
- **2026-04-17 (evening):** Research phase complete (`research.md`). Tech stack locked: Swift + SwiftUI (Chandler doesn't know Swift; Claude Code teaches through diffs), Claude Haiku 4.5 runtime, Brave Search free tier, local SQLite. Budget locked at $40.56 total runtime (friend's Anthropic credit grant, auto-reload disabled). No Apple Developer Program for v1. Domain allowlist decided as retrieval quality floor, resolving "where do pings come from?" OpenAI student credits denied — project builds and runs entirely on Anthropic stack + Brave free tier, no hoops. Anti-slop rule (read every diff) stays non-negotiable. Moving to structure outline.
