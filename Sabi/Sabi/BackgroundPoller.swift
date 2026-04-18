//
//  BackgroundPoller.swift
//  Sabi
//
//  Slice 7 — the "while you work, Sabi watches" loop.
//
//  What it does: every ~4 hours while Sabi is running, re-fetch candidates
//  for the user's current intent, narrowed to past-week publications. Rank.
//  Take the top 5. If any of those 5 URLs are ones we haven't shown the
//  user before, fire exactly one notification pointing at the best one.
//  Mark all 5 as seen so we don't re-notify on the next tick.
//
//  Why `NSBackgroundActivityScheduler` and not a plain `Timer`:
//    - It's the canonical macOS primitive for "cooperative, deferrable,
//      repeating background work." The scheduler respects battery state,
//      thermal throttling, and power source. If the user is on battery
//      and the lid's closing, the tick skips instead of spinning the CPU.
//    - `Timer` would fire regardless and would also get suspended when
//      the app's run loop pauses (which menu-bar accessories do aggressively).
//    - `interval` is a target; `tolerance` gives the scheduler slack to
//      coalesce with other system work. We allow 25% tolerance (1h) — this
//      is a "fresh-ish content" app, not a stopwatch.
//
//  Actor isolation: the poller is `@MainActor` because it reads from
//  MainActor-isolated singletons (IntentStore, SourcesStore, PollingPrefs,
//  SeenLog) and writes to the notifier. The expensive work —
//  `Retrieval.fetch` and `Ranker.rank` — is nonisolated and will hop off
//  the main actor automatically on `await`, so we don't block UI.
//
//  Debugging: the `tick()` method is public so you can call it manually
//  from a throwaway button or an LLDB expression to test without waiting
//  4 hours between runs.
//

import Foundation

@MainActor
final class BackgroundPoller {
    static let shared = BackgroundPoller()

    private let identifier = "com.sabi.backgroundPoll"
    /// 4 hours. Tuned to feel like "I checked a few times today" rather
    /// than "stream of interruptions." Matches the product vision of
    /// scheduled quiet pings, not a real-time feed.
    private let interval: TimeInterval = 4 * 60 * 60
    private var activity: NSBackgroundActivityScheduler?

    private init() {}

    // MARK: - Lifecycle

    /// Schedule the repeating activity. Safe to call once from the app
    /// delegate — subsequent calls are no-ops.
    func start() {
        guard activity == nil else { return }

        let scheduler = NSBackgroundActivityScheduler(identifier: identifier)
        scheduler.repeats = true
        scheduler.interval = interval
        scheduler.tolerance = interval * 0.25
        scheduler.qualityOfService = .utility

        scheduler.schedule { [weak self] completion in
            // The scheduler calls us on a background queue. Hop to main
            // to read the observable stores, then kick off the async work.
            Task { @MainActor in
                await self?.tick()
                completion(.finished)
            }
        }
        self.activity = scheduler
        print("[Sabi] BackgroundPoller scheduled every \(Int(interval/60))min.")
    }

    /// Tear down the scheduled activity. Currently unused — we don't expose
    /// a "stop polling forever" path because `PollingPrefs.isEnabled` is the
    /// runtime guard. Kept for symmetry in case we ever want it.
    func stop() {
        activity?.invalidate()
        activity = nil
    }

    // MARK: - Tick

    /// One poll cycle. Public so it can be triggered manually from debug UI.
    /// Returns nothing — logs explain outcomes so we can trace from Console.
    func tick() async {
        guard PollingPrefs.shared.isEnabled else {
            print("[Sabi] Poll skipped: polling disabled in settings.")
            return
        }
        let intent = IntentStore.shared.currentIntent
        guard !intent.isEmpty else {
            print("[Sabi] Poll skipped: no intent saved.")
            return
        }
        let suffixes = SourcesStore.shared.effectiveSuffixes
        guard !suffixes.isEmpty else {
            print("[Sabi] Poll skipped: no enabled sources.")
            return
        }

        // Past-week freshness is the "brand new" filter. If nothing in the
        // user's sources published anything new this week on this topic,
        // there's legitimately nothing to ping about.
        let candidates: [BraveClient.Result]
        do {
            candidates = try await Retrieval.fetch(
                for: intent,
                suffixes: suffixes,
                limit: 10,
                freshness: "pw"
            )
        } catch {
            print("[Sabi] Poll: retrieval error — \(error)")
            return
        }
        guard !candidates.isEmpty else {
            print("[Sabi] Poll: no past-week candidates for \"\(intent)\".")
            return
        }

        let ranked: [Ranker.RankedResult]
        do {
            ranked = try await Ranker.rank(intent: intent, candidates: candidates)
        } catch {
            print("[Sabi] Poll: ranker error — \(error)")
            return
        }

        let top5 = Array(ranked.prefix(5))
        let unseen = top5.filter { !SeenLog.shared.hasSeen($0.base.url) }

        // Mark all top-5 URLs as seen whether or not we notified. If we
        // only marked the one we notified about, next tick could pick a
        // different top-5 member that was actually present this tick too
        // and re-notify — effectively spamming for the same cluster.
        SeenLog.shared.markSeen(top5.map(\.base.url))

        guard let winner = unseen.first else {
            print("[Sabi] Poll: \(top5.count) in top-5, 0 new. Staying quiet.")
            return
        }

        print("[Sabi] Poll: \(unseen.count) new in top-5; pinging for \(winner.base.url.absoluteString)")
        await Notifier.shared.sendTopPick(
            title: winner.base.title,
            hostname: winner.base.hostname,
            url: winner.base.url
        )
    }
}
