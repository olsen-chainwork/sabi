# Scout — Build Notes

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
