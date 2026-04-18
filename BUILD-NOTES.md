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
