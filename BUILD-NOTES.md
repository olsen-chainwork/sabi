# Sabi — Build Notes

*(Journal started under the working name "Scout"; project renamed to Sabi on Day 1 — see rename entry below. Prior entries reference "Scout" intentionally, as written at the time.)*

*CRISPE execution journal. One entry per working session. Short, factual, forward-looking.*

---

## 2026-04-17 — Slice 1 complete (Day 1)

**Shipped:** menu bar hello world. Binoculars icon appears in menu bar, click opens popover saying "Scout / Menu bar hello world", click-away closes it, quit removes the icon.

**Stack committed:** Swift + SwiftUI, `MenuBarExtra` scene, `.menuBarExtraStyle(.window)`, `LSUIElement = YES` (agent app, no dock icon, no app menu).

**Code touched:**
- `ScoutApp.swift` — replaced default `WindowGroup` with `MenuBarExtra` scene, system image `binoculars`
- `ContentView.swift` — replaced default Hello World with a `VStack` of "Scout" + subtitle, fixed 240x140 frame
- `project.pbxproj` — added `Application is agent (UIElement) = YES` via Xcode Info tab

**Gotchas hit:**
1. Xcode saved the project to `~/chainwork/Scout/` instead of `~/Developer/scout/`. Moved with `mv`, closed Xcode's reopen-at-old-path dialog, reopened from new path.
2. Xcode wrote its own `.git` inside the project folder despite the "Create Git repository" checkbox — had to `rm -rf` it before staging, otherwise git would've treated the folder as a submodule.
3. When running without `LSUIElement = YES`, the binoculars icon was getting lost on the MacBook Pro notch overflow — too many other menu bar apps (rocket launcher, CPU/MEM monitors, Figma, Notion). Setting `LSUIElement = YES` made the app an agent and the icon appeared reliably.
4. Console showed `[BSBlockSentinel:FBSWorkspaceScenesClient] failed!` messages on launch. Harmless macOS chatter, ignored.

**Time spent:** ~2 hours from Xcode install through first working slice. Budgeted for days 1–2; came in at half budget.

**Diffs read:** yes (small ones).

**Next:** Slice 2 — Intent + augment + confirm. Brings in the Anthropic API (friend's $40.56 account), intent storage, first popover interaction beyond static text.

---

## 2026-04-17 (late evening) — Rename: Scout → Sabi

**Shipped:** product renamed end-to-end after slice 1 landed. Sabi is named after Chandler's first dog (still alive). Xcode project, Swift types, bundle identifier, and all forward-looking docs carry the new name. The original "Scout" name stays inside this journal's slice-1 entry and as a verb the product performs ("Sabi is an AI scout that watches...").

**Code touched:**
- `Scout/` → `Sabi/` (outer wrapper), `Scout/Scout/` → `Sabi/Sabi/` (source folder), `Scout.xcodeproj` → `Sabi.xcodeproj`
- `ScoutApp.swift` → `SabiApp.swift`; `struct ScoutApp` → `struct SabiApp`; `MenuBarExtra("Scout", …)` → `MenuBarExtra("Sabi", …)`
- `ContentView.swift`: popover title `Text("Scout")` → `Text("Sabi")`
- `project.pbxproj`: global Scout → Sabi (target name, product name, group paths, references). Bundle id `com.olsen-chainwork.Scout` → `com.olsen-chainwork.Sabi` in both Debug and Release configs
- Forward-looking docs rewritten: `DESIGN-DOC.md`, `SLICES.md`, `STRUCTURE.md`, `README.md`, `research.md`
- This journal's title updated; slice-1 entry preserved as-written (history-honest)

**Gotchas hit:**
1. Xcode 26.4 uses `PBXFileSystemSynchronizedRootGroup` in pbxproj (file-system sync) so the source folder rename was mostly auto-reflected — only the `path = Scout;` group entry and the target/product-name fields needed explicit edits. Modern Xcode is friendlier to renames than the old every-file-listed-in-pbxproj world.
2. `xcuserdata/` had a stale `Scout.xcscheme_...` key in `xcschememanagement.plist`. Directory is gitignored (so no commit impact) but Xcode reads it on next open — updated the key to `Sabi.xcscheme_...` to avoid a rebuilt-scheme detour.
3. Not a gotcha, a note: `/scout/` paths inside planning docs (`/scout/landing/`, `/scout/pitch/`, `/scout/BUILD-NOTES.md`) rewritten to `/sabi/` in the forward-looking docs. The BUILD-NOTES Day-1 entry still references `~/Developer/scout/` because that's the folder we were in at the time; folder rename to `~/Developer/sabi/` hasn't happened yet (happens in the follow-up commands).
4. "Scout now" button copy became "Sabi now" in plan docs via global replace — button copy is still TBD; that's a UX decision for slice 3/4, not a rename artifact.

**Time spent:** ~30 min, including a name conversation first.

**Diffs read:** yes.

**Next:** open Xcode, hit cmd+R, verify build still works — same slice-1 behavior but popover now reads "Sabi / Menu bar hello world" and bundle is `com.olsen-chainwork.Sabi`. Then run the repo/folder rename commands (gh repo rename, git remote set-url, mv `~/Developer/scout` → `~/Developer/sabi`), commit, and push. Then slice 2.

---

## 2026-04-17 (late night) — Slice 2a: Anthropic API round-trip (Day 1)

**Shipped:** Ping Haiku button in the popover does a real `POST /v1/messages` round-trip to Haiku 4.5 and shows the reply. End-to-end proof-of-life for the LLM integration. Haiku replied: *"Hey there, how's it going! 👋"* — confirms key works, network path works, JSON decode works, SwiftUI state update works.

**Code touched:**
- `.gitignore` — added `Secrets.swift` / `**/Secrets.swift` / `Secrets.local.swift` patterns **before** creating the secrets file (zero-window-of-exposure)
- `Sabi/Sabi/Secrets.swift` (NEW, gitignored) — `enum Secrets` with `static let anthropicAPIKey`
- `Sabi/Sabi/Sabi.entitlements` (NEW) — `com.apple.security.app-sandbox` + `com.apple.security.network.client`
- `Sabi/Sabi.xcodeproj/project.pbxproj` — added `CODE_SIGN_ENTITLEMENTS = Sabi/Sabi.entitlements;` to Debug + Release configs
- `Sabi/Sabi/AnthropicClient.swift` (NEW) — `nonisolated enum AnthropicClient` with one `static async throws func complete(prompt:system:maxTokens:)`, Codable request/response structs, `AnthropicError: LocalizedError` with four cases (missingAPIKey, invalidResponse, httpError, emptyContent)
- `Sabi/Sabi/ContentView.swift` — replaced hello world with three-state UI (idle / loading / result-or-error), throwaway Ping Haiku button wired to the client

**Gotchas hit:**
1. **Sandbox-on + no entitlements file = silent network fail.** Xcode 26's default macOS-app template ships with `ENABLE_APP_SANDBOX = YES` but no `.entitlements` file. That means the sandbox is locked to the *default* (zero network), and `URLSession` calls fail invisibly. Fix: create `Sabi.entitlements` with `com.apple.security.network.client = true` AND set `CODE_SIGN_ENTITLEMENTS` in both build configs. The entitlements file won't get auto-picked-up by PBXFileSystemSynchronizedRootGroup for codesigning purposes — the build setting is required.
2. **`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` is the project default.** Swift 6 approachable-concurrency behavior: any type you don't annotate runs on `@MainActor`. Means `URLSession.shared.data(for:)` would run on main thread and block UI during network I/O. Fix: annotated `AnthropicClient` as `nonisolated`. This is worth remembering for every future non-UI type (Brave client in slice 3, IntentStore in slice 2b).
3. **API-key-in-a-comment-but-not-the-constant** is a silent no-op. Swift ignores `///` doc comments at runtime, so the missing-key guard fired even after "pasting" the key. Fix is just "paste on line 16 between the existing quotes," but the confusion is real first time. Consider: for slice 2b's real UI, show the key's first/last 4 chars somewhere in dev-only diagnostics so it's obvious when it's set correctly.
4. **`cd` to the repo before git commands.** Ran the commit flow from `~` the first time (bad prompt-reading on my side). Always verify the shell prompt reads `sabi` before running git. Zsh shows the repo name in the prompt — use it.
5. **Key hygiene to-do for slice 7:** API key has been on-screen in screenshots during this session. Key is $40-budget friend's; file is gitignored; local risk only. Before Handshake submission: rotate the key at console.anthropic.com and re-paste.

**Time spent:** ~30 min of build + debug. Most of the time was Xcode build cycles, not thinking.

**Diffs read:** yes, every one. ContentView changed the most structurally — three-state rendering + `Task { ... }` for async call + `defer { isLoading = false }`. Worth re-reading once more tomorrow to internalize.

**Next:** Slice 2b — the real UI. Text field "What are you learning right now?" → Augment button → `AnthropicClient.complete(prompt:system:)` with a system prompt that refines the seed into a specific-enough intent → show refined text as editable → "Looks good" button → persist to `IntentStore` (likely `UserDefaults` for v1, FileManager JSON if we get fancy). Restart app → intent survives. Budget: 1–2 hours tomorrow.

---

## 2026-04-17 (late night) — Slice 2b: Intent + augment + confirm, fully persisted (Day 1)

**Shipped:** full slice 2 done. Popover opens to a seed text field ("What are you learning right now?"), Augment button sends the seed to Haiku 4.5 with a refinement system prompt, the refined intent comes back in an editable text box, "Looks good" persists it to `IntentStore`, quit+relaunch reopens straight to the saved view with the intent still there. Four-mode state machine: idle → augmenting → reviewing → saved. Edit button on the saved view goes back to idle without clobbering the saved intent.

**Code touched:**
- `Sabi/Sabi/IntentStore.swift` (NEW) — `@Observable` singleton, `UserDefaults` backing under key `sabi.intent.current.v1`. `currentIntent: String`, `save(_:)`, `clear()`, `hasIntent`. Persistence trims whitespace on save.
- `Sabi/Sabi/AugmentPrompt.swift` (NEW) — `nonisolated enum AugmentPrompt` holding the system prompt + a `refine(seed:)` async throws helper that calls `AnthropicClient.complete(prompt:system:maxTokens: 256)`. Keeps prompt text out of view code.
- `Sabi/Sabi/ContentView.swift` — rewrote the slice-2a throwaway as a real 4-mode state machine. Each mode has its own sub-view. Errors render as an in-place red banner without losing seed/draft state. `⌘↩` keyboard shortcut on the primary button in each mode.

**Gotchas hit:**
1. **Haiku refusal lands silently as a "refined intent."** Seeded Haiku with something that triggered safety refusal; the refusal text ("I can't help with that request…") came back and the UI treated it as a valid refinement — savable and everything. Not a slice 2 blocker (user sees the refusal and can retry with a different seed), but in slice 5 or 7 this should turn into: (a) system prompt teaches Haiku to return a sentinel like `"[unable_to_refine]"` on refusal, OR (b) post-process detects refusal-shaped responses and surfaces them as the error banner rather than savable state. Logged for future hardening.
2. **macOS benign console chatter is real and constant.** Saw `fopen failed for data file: errno = 2`, `Unable to obtain a task name port right for pid …: (os/kern) failure (0x5)`, and `ViewBridge to RemoteViewService Terminated` during the session. All harmless SwiftUI/AppKit internals. Mental filter: if it's not prefixed with `[Sabi]`, it's not ours. Console grep `[Sabi]` to cut the noise when debugging.
3. **Prompt quality is good but imperfect.** One refinement included "without writing custom code" — tautological (no-code implies no custom code). If we see more restating-the-seed patterns, tighten the system prompt with an explicit "don't restate the input; add specificity on top." Haven't iterated yet — four seeds of data is too few to justify a prompt change.
4. **`@Observable` + `UserDefaults` + singleton plays nice with SwiftUI.** SwiftUI re-renders the saved view when `currentIntent` changes. `onAppear` transitions to `.saved` when `hasIntent` is true, covering the relaunch case without extra plumbing.

**Time spent:** ~30 min for slice 2b, ~60 min cumulative for slice 2. SLICES.md budget was days 3–4. Came in on day 1.

**Diffs read:** yes. ContentView grew to ~240 lines; most of that is the four mode sub-views. Worth re-reading the state-transition actions (`augment`, `save`, `startEdit`) once more when fresh — the rest is declarative SwiftUI boilerplate.

**Next:** Slice 3 — Retrieval from Brave. Sign up for a Brave Search API key (5 min, no card). Build `SearchProvider` (Brave implementation) + `RetrievalEngine`. Add a "Sabi now" button to the saved view that fetches candidates for the current intent and shows them as a raw list (title + URL). Domain allowlist hardcoded. No ranking yet — that's slice 4. Budget: day 5 per SLICES.md, probably ~1 hour of work.

---

## 2026-04-17 (late night) — Slice 3: Brave retrieval + domain allowlist (Day 1)

**Shipped:** "Sabi now" button on the saved view pulls real candidates from the Brave Search Web API, filters them through a hardcoded hostname-suffix allowlist, and renders them as a scrollable list of clickable titles (title / hostname / description). First end-to-end retrieval pass: saved intent about SaaS/PMF/growth pulled "Levels of PMF" (First Round) and "A Founder's Guide to SaaS Strategy & Growth" (Tomasz Tunguz). Both on-theme, both from curated sources.

**Code touched:**
- `Sabi/Sabi/Secrets.swift` (modified, gitignored) — added `static let braveAPIKey` alongside the Anthropic key. Same pattern: paste between quotes, never commit. `braveAPIKey` sourced from `api-dashboard.search.brave.com`; user paid $5 for the paid tier rather than fuss with free-tier limits.
- `Sabi/Sabi/BraveClient.swift` (NEW) — `nonisolated enum BraveClient` with one `static async throws func search(query:count:) -> [Result]`. `Result` is `Identifiable, Hashable` (UUID id, title, url, description, computed hostname). GET to `https://api.search.brave.com/res/v1/web/search` with `X-Subscription-Token` header, `safesearch=moderate`, `count=20`. Private `WebSearchResponse` decodes `web.results[]`. HTML-strip helper removes `<strong>`/`<b>` tags and common entities so we don't render raw HTML in SwiftUI.
- `Sabi/Sabi/DomainAllowlist.swift` (NEW) — `nonisolated enum DomainAllowlist` with a flat `[String]` of lowercase hostname suffixes. `isAllowed(url:)` passes if the URL's host exactly matches an entry or is a subdomain of one (`host.hasSuffix("." + suffix)`). Two buckets on first pass: AI/ML research + model labs + practitioner blogs (arxiv, anthropic, openai, huggingface, simonwillison, lilianweng, etc.), and startup/SaaS/product strategy (stratechery, paulgraham, ycombinator, firstround, a16z, reforge, lennysnewsletter, tomtunguz, svpg, 37signals, etc.). 30+ domains total after the mid-slice expansion.
- `Sabi/Sabi/Retrieval.swift` (NEW) — thin orchestrator: `nonisolated enum Retrieval.fetch(for intent:, limit: 10)` calls `BraveClient.search(count: 20)`, filters through `DomainAllowlist`, returns `prefix(limit)` in Brave's native ranking order. `RetrievalError` cases: `emptyIntent`, `noAllowedResults`. Slice 4 will add a ranking pass on top.
- `Sabi/Sabi/ContentView.swift` — saved view grew a "Sabi now" primary button next to Edit, a retrieval state block (`isRetrieving`, `candidates`, `retrievalError`), and a `candidatesSection` that renders a loading spinner / empty hint / error banner / `ScrollView + LazyVStack` of `Link`-based rows. `candidateRow` opens the URL in the user's default browser. `⌘↩` now primes the Sabi-now button when on the saved view. `save()` clears stale candidates when a new intent is committed.

**Gotchas hit:**
1. **Allowlist curation is product-defining, not just a filter.** First pass of the allowlist was 17 domains, entirely AI/ML/SWE (arxiv, anthropic, openai, huggingface, plus practitioner blogs). Saved intent was SaaS/PMF → zero hits → `noAllowedResults` error banner. This is exactly the "tight curation is load-bearing" moment: Brave returned plenty of relevant results, but Medium/Substack/HBR/TechCrunch all got filtered out by design, and we had no startup-native substitutes. Expanded mid-slice to cover stratechery/paulgraham/firstround/a16z/reforge/lennysnewsletter/tomtunguz/etc. — test-passed on the same intent. Lesson for slice 7: surface the allowlist as user-editable. The list *is* the product taste.
2. **Brave free tier actually required a card.** User expected free-tier to be keyless or at least card-free; it wanted a payment method to provision the key. Paid $5 for paid-tier headroom, moved on. Documented for anyone reading later.
3. **HTML in search results would render as literal `<strong>` text.** Brave wraps query-matched substrings in `<strong>` tags inside `title` and `description`. SwiftUI `Text` renders that as plain text (with the angle brackets visible). Added a tiny `strippedHTML` helper that pulls `<strong>`/`</strong>`, `<b>`/`</b>`, and common entities. Good enough for v1 — if we ever see other tags we'll AttributedString this up.
4. **`nonisolated` discipline held.** `BraveClient`, `DomainAllowlist`, `Retrieval` all marked `nonisolated` from the start. No actor-isolation warnings, no surprise hops to main thread on network work. The `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` default is real and will keep biting if forgotten, so it's becoming muscle memory: network/pure-data type → `nonisolated` at the enum/class level.
5. **Not a bug, a note on demo flow:** with results rendered as SwiftUI `Link`s, clicking opens the system default browser. For the Handshake demo we may want a first-class "Open all" or "Open top 3" convenience, or even a peek-preview mode. Parking it for slice 5/6 once ranking is in.

**Time spent:** ~45 min. Most of it was wiring the candidatesSection sub-states (loading / empty / error / populated) to read cleanly in SwiftUI. Allowlist expansion was a 2-minute edit once the symptom was visible.

**Diffs read:** yes. ContentView's saved view is now the most content-dense screen in the app; worth re-skimming tomorrow to make sure the state transitions between retrieval-empty / retrieval-loading / retrieval-error / retrieval-populated are airtight.

**Next:** Slice 4 — ranking pass + one ping (end-to-end). Take the allowlisted candidates, score them (freshness + domain authority + intent-match), surface the top N, and fire the "one ping" notification path so the user gets a macOS notification when Sabi has a new pick. SLICES.md budget: days 6–7. First real MVP moment.

---

## 2026-04-18 (past midnight) — Slice 4: Ranking + one ping, end-to-end (Day 2)

**Shipped:** Sabi is now an AI scout for real. Click "Sabi now" → Brave retrieval → allowlist → Haiku re-ranks the candidates with a one-line reason for each → macOS notification banner fires with the top pick → clicking the banner opens the URL in the default browser. First slice where the product does something Google can't: the ranked list shows *why* each candidate matches the learner's specific intent, and the proactive ping is the beginnings of the "AI scout that watches while you work" UX promise.

**Code touched:**
- `Sabi/Sabi/Ranker.swift` (NEW) — `nonisolated enum Ranker` with `RankedResult` (base BraveClient.Result + rank + reason) and `rank(intent:candidates:)`. System prompt teaches Haiku to return a JSON array of `{index, reason}` sorted best→worst. JSON extraction tolerates prose and code-fence noise by locating first `[` and last `]`. Validates every original index is covered exactly once. Falls back to Brave order with empty reasons on parse failure (never throws — retrieval still works without the LLM polish).
- `Sabi/Sabi/Notifier.swift` (NEW) — `@MainActor final class Notifier: NSObject, UNUserNotificationCenterDelegate`, shared singleton. `bootstrap()` sets the delegate, `requestAuthorization()` asks for `[.alert, .sound]`, `sendTopPick(title:hostname:url:)` fires an immediate banner with the URL stashed in `userInfo`. Delegate methods are `nonisolated`; `didReceive` hops back to `@MainActor` to call `NSWorkspace.shared.open(url)`.
- `Sabi/Sabi/SabiApp.swift` — added `init()` that calls `Notifier.shared.bootstrap()` so the delegate is wired before any banner can present. Auth is requested lazily the first time `Sabi now` runs.
- `Sabi/Sabi/ContentView.swift` — swapped the raw `candidates: [BraveClient.Result]` state for `ranked: [Ranker.RankedResult]` + `isRanking: Bool`. `runRetrieval()` now does Brave → Rank → Ping in sequence, updating state between phases. New `rankedRow(_:)` renders `#N <title>`, hostname, and the Haiku-written reason. Button label shows "Searching…" then "Ranking…" then back to "Sabi now".

**Gotchas hit:**
1. **macOS only prompts for notification permission once — ever.** First click of Sabi now should have triggered the OS permission dialog. It didn't surface (best guess: my popover stealing focus caused the UN prompt to get auto-dismissed, OR the first launch raced with Xcode-attached-debugger focus behavior). macOS then remembered "user didn't grant" and silently refused to re-prompt. Fix was manual: System Settings → Notifications → Sabi → flip **Allow notifications** to ON. Worth remembering: if we ever rebundle or change the bundle ID, that nukes the stored decision and we get one fresh prompt. For the Handshake demo: verify the toggle is ON before recording.
2. **`@MainActor` class + `nonisolated` delegate methods is the right shape.** First instinct was to make the whole `Notifier` `@MainActor` and call it a day. But `UNUserNotificationCenterDelegate` methods are invoked by the system off-main, and Swift 6 strict concurrency refuses that conformance without an explicit escape hatch. Marking the delegate methods themselves `nonisolated` while keeping the rest of the class `@MainActor` lets the system call in freely, and we `Task { @MainActor in NSWorkspace.shared.open(url) }` back to main for the UI hop. Clean pattern — reusing it for any future delegate conformance.
3. **`willPresent` is required or foreground notifications get eaten.** If the delegate returns nothing (or doesn't exist) for `willPresent:`, macOS treats foreground notifications as "the app already knows" and suppresses the banner. Since Sabi's popover is explicitly what the user is looking at when the ranking completes, we're always foreground at the moment of ping. Returning `[.banner, .sound]` from `willPresent` solves it and is safe (we still get the normal suppression behavior when app isn't active — the OS decides).
4. **LLM-JSON-out needs belt + suspenders parsing.** First run with Haiku worked, but I know from past projects that "return only JSON" instructions don't hold 100% of the time — it'll sometimes prepend "Here's the ranking:" or wrap in triple backticks. The parse function locates first `[` and last `]` to tolerate both. On top of that, validation checks index range + coverage + uniqueness so a malformed-but-parseable JSON can't put garbage in the UI. Fallback returns Brave's native order so retrieval still works even if Haiku goes fully off the rails. Defensive by design — we want to ship, not debug ranking edge cases during a demo.
5. **Body copy is already fighting for space.** Brave titles can be 100+ chars ("GitHub - shinpr/claude-code-workflows: Production-ready development workflows for Claude Code, powered by specialized AI agents. · GitHub") and I'm appending " — hostname" on top. Banner renders fine but wraps to 4 lines and looks heavy. Parking a polish item: derive a short "display title" (strip the " · site-tail" SEO padding, truncate at the first colon when the prefix is just the site name, cap at ~60 chars). Not a slice 4 blocker but will matter for demo aesthetics.
6. **Ranker token budget.** Set `maxTokens: 1024` for ranking. At 10 candidates × ~120 chars per reason × JSON overhead, plausibly 800-1000 tokens of output. If we ever bump the candidate set to 20+ we need to revisit, or switch to streaming-and-parse-on-the-fly. Not a problem at current scale.

**Time spent:** ~45 min of Swift + wiring, plus ~15 min diagnosing the notification permission false-negative. The first banner hit at 12:58 AM.

**Diffs read:** yes. The ContentView changes are the densest; worth one more re-read tomorrow to internalize the isRetrieving → isRanking → ranked state transitions and make sure I didn't miss any reset points.

**Next:** Slice 5 — "Minimum lovable copy" pass. The product now works end-to-end for the first time; this is where we tighten every string the user sees (empty-state copy, error banners, notification body format, button labels). Also the first chance to iterate on the augment/ranking prompts based on real dogfooding. Budget: day 8 per SLICES.md, ~60 min.

Day 1 aimed for slices 1–2, day 2 aimed for slice 3. Actual: slices 1–4 shipped end-of-day-1-bleeding-into-day-2. Five days of budget consumed in one long session. Core product is real.

---

## 2026-04-18 (early AM) — Slice 5: Minimum lovable copy + scope + retrieval hardening (Day 2)

**Shipped:** the product gained a voice. Every user-facing string got a pass — button labels ("Fetch"), rotating loading copy, a "Use as-is" escape hatch from idle, plain-English error banners without internal vocabulary. Retrieval got teeth under the hood: allowlist expanded to ~60 domains across 11 buckets, Brave queries now use `site: OR` chains with dynamic batching to pack the 400-char `q` limit, a freshness filter (`py` = past year) pushes Brave toward recent articles, and a URL-shape filter drops homepages and hub pages so we bias toward individual essays. The augment prompt got a "do not define" anti-example and an "AI" few-shot for mega-broad single-word seeds. Notification was pulled from the manual Fetch path — slice 7 will own pings where they earn their interruption.

**Code touched:**
- `Sabi/Sabi/ContentView.swift` — copy pass across every mode, idle "Use as-is" path for users who don't want augmentation, rotating "Searching… / Thinking… / Almost there…" spinner messages, tightened error banners, removed the manual-fetch notification hop.
- `Sabi/Sabi/AugmentPrompt.swift` — tightened system prompt with explicit bad-output examples ("don't return a definition"), added a few-shot for the "AI" single-word seed case.
- `Sabi/Sabi/Ranker.swift` — reason-copy iteration: shorter, more specific, one sentence max. Prompt teaches Haiku to reference the intent explicitly in the reason string.
- `Sabi/Sabi/Retrieval.swift` — big expansion. `fetch(for:limit:)` now builds site-restricted query batches via `buildSiteQueryBatches(suffixes:maxQueryChars:)` that pack as many `site:domain.tld` clauses per query as fit under Brave's 400-char budget. Each batch runs a separate Brave call, results pool together and dedupe by URL. Added `looksLikeHomepage(_:)` URL-shape filter that drops `/`, `/blog`, `/about` and other short/generic paths.
- `Sabi/Sabi/DomainAllowlist.swift` — expanded from ~30 to ~60 domains. New buckets: hard science (nature, science, quantamagazine), econ (noahpinion, mattyglesias), long-form essays (nesslabs, morganhousel, danco, kwokchain), indie practitioner blogs (danluu, jvns, fabiensanglard, eugeneyan, sebastianraschka), alignment-adjacent (alignmentforum, lesswrong, aisafety.camp), theory/complexity (complexityexplorer, scottaaronson). Bucket comments kept inline for future editability.
- `Sabi/Sabi/BraveClient.swift` — added `freshness` parameter threaded through to the `freshness=py` query arg.
- `Sabi/Sabi/SabiApp.swift` — removed the slice-4 one-shot notification wiring; BackgroundPoller will own that path in slice 7.

**Gotchas hit:**
1. **Brave's `q=` param has a 400-char hard limit.** Tried concatenating `site:a.com OR site:b.com OR ...` for all 60 allowlist entries in one request — Brave 400'd with a helpful error message. Fix: `buildSiteQueryBatches` greedily packs clauses until the next one would push past 400 chars, then opens a new batch. Short domains (arxiv.org) pack densely; long domains (alignmentforum.org) get more room. Self-tunes as the allowlist grows — no hardcoded batch count.
2. **`freshness=pm` (past month) is too aggressive.** With the curated allowlist, past-month returned ~2-3 results total for most intents — starving the ranker. Past-year (`py`) hits the sweet spot: still biased toward recent work, but deep enough to have something to rank. Slice 7's scheduled polling will override this to `pw` (past week) because the re-fetch loop *wants* "brand new stuff since last tick."
3. **Homepages dominate raw Brave results.** When you `site:stratechery.com`, the first result is stratechery.com itself — literally the homepage. Same for every blog domain. `looksLikeHomepage` checks: path is empty or one of `{"/", "/blog", "/about", "/archive"}`, or path has ≤1 segment and no file extension. Drops maybe 30% of raw results but they were all useless.
4. **Notification hop on manual Fetch felt wrong.** User clicks Fetch, sees results in-app, *then* also gets a notification pinging them about what they literally just saw. Deleted the hop. Notifications are reserved for the surprise case — something new that appeared while they weren't looking. Slice 7 owns that path.
5. **Augment "don't define" anti-example was mandatory.** Seed "AI" came back refined to "Artificial intelligence: a field of computer science concerned with…" — literally defining the term instead of sharpening the intent. Anti-example pattern in the system prompt (`❌ don't say: "the field of X" / ✅ do say: "recent advances in X for Y"`) flipped the behavior on the next run. Took 2 retries to internalize; anti-examples > positive examples for correcting specific failure modes.

**Time spent:** ~90 min. Most of it was the allowlist expansion + Brave batching logic. Copy pass was the last 20 min and the cheapest thing to improve perceived quality.

**Diffs read:** yes, every one. Retrieval.swift grew the most (~100 lines added); re-read twice to convince myself the batching math couldn't emit a >400-char query.

**Next:** Slice 6 — user-editable sources. Make the allowlist visible and editable in Settings (Cmd+,). Big UX moment because the allowlist *is* the product taste — letting users curate it removes the "Sabi only shows X" complaint while keeping curation as the retrieval quality floor.

---

## 2026-04-18 (early AM) — Slice 6: User-editable sources (Day 2)

**Shipped:** Cmd+, opens a Settings window with an editable source list. Users can add a domain by pasting a URL (we normalize it), toggle any default source off (stays visible with strikethrough so they can flip it back), remove custom entries, and Reset to defaults. The effective allowlist is computed as `defaults + additions - disabled` and threaded through `Retrieval.fetch` on every search. The allowlist stopped being a hardcoded taste and started being *the user's* taste.

**Code touched:**
- `Sabi/Sabi/SourcesStore.swift` (NEW, 147 lines) — `@Observable @MainActor final class SourcesStore` singleton. UserDefaults-backed with two keys: `sabi.sources.additions.v1` and `sabi.sources.disabled.v1`. Doesn't store the full list, only the delta from defaults — means the default list can evolve in future versions without stomping user overrides. `add(_:)` normalizes URLs (strips scheme, `www.`, trailing slash, lowercases) before storing. `effectiveSuffixes: [String]` is the computed property Retrieval calls.
- `Sabi/Sabi/SourcesSettingsView.swift` (NEW, 156 lines) — `Form`-based settings UI. Sections: "Your sources" (additions, each with a Remove button), "Defaults" (default list with toggles — disabled items render strikethrough in the list), add-new row at the bottom with a "Paste URL" TextField + Add button, Reset button at the top. Live-bound to the store; no save button (every change persists immediately).
- `Sabi/Sabi/SabiApp.swift` — added a `Settings` scene with `SourcesSettingsView()`. Cmd+, is wired by SwiftUI automatically once a Settings scene exists.
- `Sabi/Sabi/Retrieval.swift` — `fetch(for:limit:suffixes:)` gained an explicit `suffixes: [String]` parameter. Callers pass `SourcesStore.shared.effectiveSuffixes`. Internal queries use the passed list; `DomainAllowlist.isAllowed` still uses the default list for post-filtering (defense in depth — if we ever miss a suffix in the query, the filter still catches it). Kept the async work nonisolated by copying the `[String]` in on the MainActor before the `await`.
- `Sabi/Sabi/ContentView.swift` — swap the `Retrieval.fetch(for: intent)` call to pass `suffixes: SourcesStore.shared.effectiveSuffixes`.

**Gotchas hit:**
1. **Storing the delta (additions + disabled set) vs storing the full list.** First instinct was to just store `[String]` of the current effective list. That has a nasty upgrade property: if we ship a new default list in v1.1, every existing user loses the new defaults because their stored list is treated as authoritative. Delta model: store only what's different from defaults. User adds a domain → it's in `additions`. User disables a default → it's in `disabled`. Default list grows → user automatically gets the new entries. Right call.
2. **"Toggle off a default" vs "remove" is a subtle UX distinction.** Disabling a default hides it from retrieval but keeps it in the list with strikethrough. Removing a custom addition deletes it entirely. Reason: defaults are curated; a user might toggle one off by mistake and want to bring it back without retyping. Custom additions are the user's typing — they know they can re-add.
3. **MainActor store + nonisolated retrieval is fiddly but clean.** `SourcesStore` is `@MainActor` because SwiftUI needs to observe it. `Retrieval.fetch` is nonisolated because it does network. Fix: caller (ContentView, also MainActor) reads `SourcesStore.shared.effectiveSuffixes` synchronously before the `await`, then passes the resulting `[String]` (Sendable) into the async call. No actor hops during the network phase, no stale data. Pattern worth reusing anywhere MainActor state crosses into async background work.
4. **Strikethrough type inference.** First attempt did `Text(domain).strikethrough(disabled ? true : false)` — compiled but SwiftUI rendered everything with strikethrough. Overload resolution landed on the wrong signature. Explicit `.strikethrough(disabled, color: .secondary)` with the bool as the active-flag fixed it. Swift's type inference around `ViewModifier` overloads bites back sometimes.

**Commits:** `a5bd398` (slice 6 core), `ac1e82e` (polish: fix strikethrough type, clear actor warnings).

**Time spent:** ~60 min for the core plus ~15 min for the polish follow-up.

**Diffs read:** yes. `SourcesStore` was the most important to re-read — the delta model is clever but subtle, and a future me will need to remember why we didn't just store `[String]` of the full list.

**Next:** Slice 7 — scheduled polling + notifications. `NSBackgroundActivityScheduler` every 4h, narrow to past-week, seen-log de-dup, fire one notification on "genuinely new" top-5 hits. This turns Sabi from "button I click" into "scout that watches while I work."

---

## 2026-04-18 (morning) — Slice 7: Scheduled polling + notifications (Day 2)

**Shipped:** Sabi is now an actual scout. `BackgroundPoller` runs every ~4 hours via `NSBackgroundActivityScheduler` while the app is open, re-fetches candidates for the current intent (narrowed to past-week), ranks them, and fires exactly one notification if any of the top 5 URLs haven't been shown before. `SeenLog` is a FIFO-capped (500 entries) UserDefaults-backed record of every URL Sabi has surfaced — manually or via the poller — so the same link never re-pings. Settings gained a "Check for new sources" toggle (default ON) and a manual "Check now" button. The product arc finally matches the pitch: save intent → Sabi watches → ping when worth your attention.

**Code touched:**
- `Sabi/Sabi/BackgroundPoller.swift` (NEW, 152 lines) — `@MainActor final class BackgroundPoller` singleton. `start()` spins up `NSBackgroundActivityScheduler` with `repeats=true`, `interval=4h`, `tolerance=1h` (25%). Each tick: read intent + sources from singletons, call `Retrieval.fetch(freshness: .pastWeek)`, call `Ranker.rank(...)`, scan top 5 for unseen URLs, fire `Notifier.sendTopPick` with the best unseen, mark all 5 as seen via `SeenLog`. `stop()` invalidates the scheduler. `tick()` is `public` so a throwaway debug button can call it directly without waiting 4h.
- `Sabi/Sabi/SeenLog.swift` (NEW, 102 lines) — `@Observable @MainActor final class SeenLog`. Two in-memory mirrors of UserDefaults: `order: [String]` (FIFO) + `seenSet: Set<String>` (O(1) lookup). `markSeen(_:)`, `hasSeen(_:)`, `reset()`. Hard cap at 500; oldest entry evicted on overflow.
- `Sabi/Sabi/PollingPrefs.swift` (NEW, 49 lines) — `@Observable @MainActor final class PollingPrefs`. Single `isEnabled: Bool` backed by `sabi.polling.enabled.v1`. Default ON. Kept in its own file (not folded into SourcesStore) because "which places Sabi searches" and "how often Sabi runs" are two different settings concerns — cleaner to have their own file for future growth.
- `Sabi/Sabi/Retrieval.swift` — `Freshness` enum (`.pastYear` / `.pastWeek`) threaded through `fetch(for:limit:suffixes:freshness:)`. Manual Fetch still uses `.pastYear` (deep); poller uses `.pastWeek` (fresh). Brave params: `freshness=py` vs `freshness=pw`.
- `Sabi/Sabi/SourcesSettingsView.swift` — new top section: "Checking" with the polling toggle (binds to `PollingPrefs.shared.isEnabled`) and a "Check now" button that calls `BackgroundPoller.shared.tick()`. Caption explains cadence plainly.
- `Sabi/Sabi/SabiApp.swift` — `init()` also calls `BackgroundPoller.shared.start()`. Scheduler is started unconditionally; the `tick()` reads `PollingPrefs.shared.isEnabled` early and no-ops if disabled. This is deliberate: means flipping the toggle OFF doesn't require tearing down the scheduler, and flipping it ON doesn't require starting one.
- `Sabi/Sabi/ContentView.swift` — Fetch path now calls `SeenLog.shared.markSeen(url)` for every URL rendered in the candidates list, so manual fetches don't re-notify via the background poller.

**Gotchas hit:**
1. **`NSBackgroundActivityScheduler` swallows errors silently in the completion handler.** First tick didn't fire any notification and there was no error in the console. Turns out if the block throws, the scheduler just logs internally and nothing surfaces to the app. Wrapped the tick body in a `do/catch` that prints `[Sabi] Background tick failed: \(error)` so failures are visible in Console.app when grepping for `[Sabi]`.
2. **`.pastWeek` + curated allowlist is sparse.** Most intents return 0–3 allowlisted results in the past-week window on the first tick. Design accommodates this: if nothing unseen in top 5, just don't notify. The point isn't "fire every 4h," it's "fire when there's something worth your attention." Silent ticks are a feature, not a bug.
3. **Menu-bar accessory apps have aggressive run loop pausing.** `Timer` and `DispatchSource` both get suspended when the popover is closed and the app goes idle. `NSBackgroundActivityScheduler` is the only primitive that keeps firing in that state. Confirmed by sleeping the Mac for 20 min then watching the poller tick on wake. Worth remembering for any future periodic work.
4. **`SeenLog` needs to survive app restarts but not grow forever.** UserDefaults is persistent + free. 500-entry cap is handwaved from: user fetches 2–3 times a day manually, poller fires 6×/day, average intent produces ~5 rendered URLs → ~25-50 new entries/day, 500 = ~two weeks of usage before FIFO kicks in. Since Brave's `pw` filter ages URLs out after 7 days anyway, entries in the tail of the log are unreachable — eviction loses nothing real.
5. **Permission state for notifications persists across app restarts and Xcode rebuilds, but NOT bundle ID changes.** If the team ever forks Sabi into a branded variant with a different bundle ID, that's a fresh permission prompt for every user. Noted for distribution planning.

**Time spent:** ~75 min. Most of it was getting `NSBackgroundActivityScheduler` configured correctly and verifying ticks fire in all the relevant states (app foregrounded, popover closed, Mac asleep+wake).

**Diffs read:** yes. `BackgroundPoller.tick()` is the most important to re-read — it's the function that defines Sabi's quiet behavior, and every new feature will want to hook into it.

**Next:** App polish pass — items found during a quick end-to-end walkthrough. Honest subtitle in saved view, prefill edit with current intent, dedup the loading spinner, clearer polling copy.

---

## 2026-04-18 (late morning) — App polish pass

**Shipped:** five small papercuts fixed before going to the contest submission pass. Saved view subtitle now tells the truth about polling state (reads "Sabi's watching the web for this" when polling is ON, "Polling paused — fetch manually" when OFF). Edit button prefills the seed field with the current intent so the user can tweak instead of retyping. "Check now" in Settings shows a success toast instead of silent completion. Sources panel caption got rewritten in plainer English. Duplicate loading spinner removed from the candidates section (the button label already says "Searching…"; the inline spinner was redundant noise).

**Code touched:**
- `Sabi/Sabi/ContentView.swift` — added `private let polling = PollingPrefs.shared` observed property. `headerSubtitle` is now a computed property that branches on `polling.isEnabled` in the `.saved` case. `startEdit()` prefills `seed = intents.currentIntent` and `draft = intents.currentIntent` before flipping mode to `.idle`. `candidatesSection` lost its inline `ProgressView`.
- `Sabi/Sabi/SourcesSettingsView.swift` — polling caption rewritten ("While Sabi is running, it checks your sources every few hours. You'll get a notification when there's something new."). "Check now" button onTap flips a `@State var justChecked: Bool` that drives a 2s success toast with copy "Checked — I'll ping you if anything new surfaces."

**Gotchas hit:**
1. **`@Observable` singletons don't automatically re-render when toggled from Settings.** `headerSubtitle` reads `polling.isEnabled`; flipping the toggle in Settings updates the singleton, but ContentView didn't re-render unless I explicitly observed `polling` at the struct level. Fix: declare the singleton as `private let polling = PollingPrefs.shared` in ContentView's body. SwiftUI registers it as a dependency and the subtitle updates live. Small detail, easy to miss.
2. **Every "your app is doing a thing" UI needs an "it finished" state.** "Check now" silently firing the tick was uncanny — button clicks, nothing visible changes, user has no idea if anything happened. Adding even a 2-second toast fixed the perception of sluggishness. General rule for slice 8 polish: audit every button for "and now what?"

**Commit:** `4118b49`.

**Time spent:** ~30 min.

**Diffs read:** yes.

**Next:** User reported all top-5 results are from arxiv.org. Investigate whether ranker is biased or pool is starved.

---

## 2026-04-18 (midday) — Retrieval diversity: round-robin by host + ranker cap

**Shipped:** fixed the "everything is from arxiv" symptom. Root cause was not the ranker — it was the retrieval pool. Brave's site-restricted batches return in batch order, and our first batch was packed with short-TLD academic domains (arxiv, openai, anthropic) that happen to dominate AI-topic searches. `prefix(limit)` on the pooled list took the first 10 arxiv results before ever reaching the second or third batch. Fixed by interleaving results by host in `Retrieval` before `prefix`, and by capping the ranker's output at 2 per canonical domain as a belt-and-suspenders second pass. First run after the fix: top-5 spanned 10 distinct hosts — arxiv, huggingface, a16z, sebastianraschka, lesswrong, simonwillison, nature, together.ai, alignmentforum, github.

**Code touched:**
- `Sabi/Sabi/Retrieval.swift` — added `interleaveByHost(_:limit:)` private helper. Groups raw Brave results by `url.host`, builds a dictionary of per-host FIFO queues preserving first-seen host order, then round-robins across hosts pulling one at a time until `limit` is reached or all queues are empty. Replaced `Array(deduped.prefix(limit))` with `interleaveByHost(deduped, limit: limit)`.
- `Sabi/Sabi/Ranker.swift` — added `diversify(_:maxPerDomain:)` private static. After `rank(...)` produces the Haiku-ordered list, we bucket by `canonicalDomain(for:hostname:)` (collapses `www.` and subdomain variants to the matching allowlist suffix). Keep up to 2 per canonical domain in the "primary" pool; the rest fall through to "overflow" appended at the end. Ranks get renumbered 1…N after. Added `[Sabi] Diversify:` print so we can see the canonical-domain counts at runtime.

**Gotchas hit:**
1. **"Cap 2 per domain in the ranker" is not enough if the pool is already one domain.** First fix was only in Ranker — it capped at 2 arxiv entries in the top slots, but the other 8 were still arxiv so they all appeared below ranks 1–2 anyway. The diversify log showed `["arxiv.org": 2]` with 8 overflow: literally every candidate was arxiv. The ranker can't diversify a pool it was never given diversity in. Real fix had to live in Retrieval: force per-host diversity *before* the pool crosses into the ranker. Lesson: when the output is monocultured, check the input first.
2. **`www.arxiv.org` and `arxiv.org` are different dictionary keys in raw Brave data.** First attempt bucketed by `url.host` directly and counted them separately, so we'd sometimes get 4 arxiv results (two under each host spelling). Canonical key: match against the allowlist suffix list and collapse both to `arxiv.org`. Same logic handles `blog.huggingface.co` / `huggingface.co`. `canonicalDomain(for:)` does the suffix match and falls back to stripping `www.` for any host that doesn't hit the allowlist.
3. **Debugging required explicit logging.** The first "did it work?" test looked the same as before — still arxiv-heavy. I thought the fix was wrong. Adding `print("[Sabi] Diversify: ... Keys: \(counts)")` made the actual state visible: the keys dictionary had only one entry. That made the real problem obvious in 10 seconds. Lesson: when a diversity/distribution fix doesn't seem to work, instrument the distribution itself, not the output.
4. **User had to rebuild to see the fix.** Normal Xcode caching — I had to confirm "yea i stopped and rebuilt it" before trusting that the symptom-reproduction was against the new code. Worth a mental note for any future "the fix didn't work" moment.

**Commits:** `2fe9068` (ranker diversify cap), `cabf48d` (retrieval round-robin + logging).

**Time spent:** ~40 min including the two-pass debug cycle.

**Diffs read:** yes. Both Retrieval and Ranker got subtle new state — worth re-reading once more before touching retrieval again.

**Next:** Icon + visual polish (slice 8), then speed profiling (slice 9), then cool-ideas brainstorm (slice 10).

---

## 2026-04-19 — Icon design: paw print (in progress)

**Shipped:** converged on a paw-print design for both the menu bar glyph and the app icon. Menu bar version is a black-on-transparent template image; macOS auto-tints it white on dark menu bars and black on light. App icon version is a caramel-brown paw on a cream-to-off-white vertical gradient squircle tile. Not yet wired into `Assets.xcassets` or the app itself — that's the next session.

**Process (for future me):**
1. Tried a bone icon first (v1 amber, v2 full reset). User feedback: "looks too much like a cock." Duly noted — what looks like a dog bone in isolation reads as phallic at 22pt in a menu bar. The four-lobe symmetry is the issue.
2. Pivoted to paw print. First attempt stacked 3 ellipses vertically for the main pad — read as an egg or acorn, not a paw.
3. Tried a two-lobe heart approach — got a cleft at the top that made it look like a frog body.
4. Final design sweeps many small ellipses from a wide, flat bottom to a narrow round top, with `rx(t) = r_top + (r_bot - r_top) * sqrt(t)`. The `sqrt` makes the sides bulge outward into a pear/rounded-triangle shape — wide base, smooth shoulders, rounded dome. Plus four toe pads in a gentle arc above.

**Code:** `outputs/paw_v1.py` (lives in the Claude session workspace, not the repo). Pillow-based generator, oversamples 8× for template and 4× for app icon, LANCZOS downscale. Emits template at 22 + 44pt, app icon at 16–1024.

**Gotchas hit:**
1. **"More shapes = smoother edges" is wrong for SDF-style silhouette construction.** 3 nested ellipses looked lumpy; 80 interpolated ellipses on a linear rx sweep looked *triangular* (straight sides). Needed `sqrt`-curved rx interpolation to get actual curvature. The math matters even when you're just stacking circles.
2. **Reading a preview at 256 ≠ reading it at 22.** The paw pad looked fine at 256×256 but disappeared into a blob at 22pt. Fix for next iteration: always render at target size and judge that before iterating on the master. For the final Assets.xcassets integration, render the template at 22 and 44 specifically and eyeball both.

**Next session:**
1. Copy `paw_v1_out/MenuBarIcon.png` + `MenuBarIcon@2x.png` into `Sabi/Sabi/Assets.xcassets/MenuBarIcon.imageset/` with a `Contents.json` that marks `template-rendering-intent: "template"`.
2. Copy `appicon_{16,32,64,128,256,512,1024}.png` into `Assets.xcassets/AppIcon.appiconset/`. Update `Contents.json` to reference each size @1x and @2x.
3. Flip `SabiApp.swift`: `MenuBarExtra("Sabi", systemImage: "binoculars")` → `MenuBarExtra("Sabi", image: "MenuBarIcon")`.
4. Rebuild and verify the menu bar glyph templates correctly (white on dark menu bar, black on light).

---

## Template for future entries

```
## YYYY-MM-DD — [slice name] [complete|in progress|blocked]

**Shipped:** one sentence.

**Code touched:** bullet list of files + what changed.

**Gotchas hit:** numbered list. Write these while they're fresh.

**Time spent:** rough hours.

**Diffs read:** yes/no + reason if no.

**Next:** what the next session opens with.
```
