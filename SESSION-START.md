# Session Start — Sabi

Short guide for resuming work in a new Cowork session. Save this in the repo root alongside BUILD-NOTES.md and SLICES.md.

---

## Step 0 — reconnect the folder

In Cowork, open the folder picker and select `~/Developer/sabi`. Until this is done, the agent can't read any files.

## Step 1 — paste this prompt

Fill in the bracketed bits from your head (or glance at BUILD-NOTES.md's latest entry), then paste verbatim:

```
Picking up Sabi — macOS menu bar app in Swift. Day [N] of a 13-day solo build.

Active slice: [e.g. "slice 2 — Intent + augment + confirm"]
Status: [one sentence — what's shipped, what's open, any mid-slice state]

Repo at ~/Developer/sabi. Please read, in this order:
1. ~/Developer/sabi/BUILD-NOTES.md — session journal; the bottom-most dated entry is where we left off
2. ~/Developer/sabi/SLICES.md — 7-slice risk-ordered plan, see the active slice
3. ~/Developer/sabi/DESIGN-DOC.md — locked design decisions (scan, don't memorize)

Then tell me (a) that you're caught up, (b) what you think the opening move is for the active slice, and (c) any gotchas from prior entries that are relevant. I'll steer from there.
```

## Step 2 — hold these rules during the session

From SLICES.md, non-negotiable:

- One slice at a time. Don't half-build two in parallel.
- Read every diff. This is your Swift tutorial. Slow is smooth, smooth is fast.
- Ship each slice before moving on. "Ship" = builds clean, runs, does what the slice says, committed, pushed.
- If a slice runs >50% over its day budget, stop and reassess. Don't sunk-cost.
- Log gotchas in BUILD-NOTES **while they're fresh**, not after.

## Step 3 — close the session with a BUILD-NOTES entry

Before you stop for the day, add a new dated entry to BUILD-NOTES.md using the template at the bottom of that file. Minimum fields:

- **Shipped:** one sentence
- **Code touched:** bullets (files + what changed)
- **Gotchas:** numbered, written fresh
- **Time spent:** rough hours
- **Diffs read:** yes/no + reason if no
- **Next:** what the next session opens with

This entry is what makes Step 1 cheap. Skip it and the next session has to re-derive state from git diff — slower and lossy.

## Tips

- **Mid-slice sessions are fine.** You don't have to finish a slice in one sitting. Just log "slice N in progress" in BUILD-NOTES when you close.
- **If Claude gets something wrong early, correct it immediately.** Hallucinations compound. A 30-second correction at turn 3 saves an hour at turn 30.
- **Paste raw terminal output rather than paraphrasing.** Git push output, Xcode errors, API responses — paste them verbatim. They contain details you'd miss summarizing.
- **If a design decision gets revisited, log it in DESIGN-DOC's change log.** That doc is the source of truth for "why we decided this." BUILD-NOTES is for "what I did today."
