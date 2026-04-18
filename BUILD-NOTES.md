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
