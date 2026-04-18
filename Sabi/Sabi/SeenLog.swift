//
//  SeenLog.swift
//  Sabi
//
//  Slice 7 — persistent record of URLs Sabi has already surfaced.
//
//  Why: the background poller (slice 7) re-fetches every 4h and only
//  pings on "brand new" top-5 hits. "Brand new" means both (a) freshly
//  published (enforced by Brave freshness=pw at query time) and (b) not
//  something we've already shown this user. Without (b), the same URL
//  would re-notify on every tick until it aged out of the past-week window.
//
//  Both paths write here:
//    - Manual Fetch in ContentView: marks displayed URLs as seen so the
//      next background tick doesn't re-notify about them.
//    - Background poller: marks every top-5 URL it inspects as seen,
//      whether or not it ended up notifying.
//
//  Storage: UserDefaults as an ordered `[String]` (oldest → newest) plus a
//  mirror `Set<String>` in memory for O(1) `hasSeen` checks. Hard cap at
//  `maxEntries` (500) with FIFO eviction so the list can't grow forever.
//  500 is an order of magnitude more than a typical user will burn through
//  in the ~1-week Brave past-week window before URLs fall out anyway.
//

import Foundation
import Observation

@Observable
@MainActor
final class SeenLog {
    static let shared = SeenLog()

    private let key = "sabi.seenURLs.v1"
    private let maxEntries = 500
    private let defaults: UserDefaults

    /// Order of first-seen, oldest at index 0. Used for FIFO eviction.
    private(set) var order: [String] = []
    /// Mirror of `order` for O(1) membership checks.
    private var seenSet: Set<String> = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let stored = defaults.array(forKey: key) as? [String] {
            self.order = stored
            self.seenSet = Set(stored)
        }
    }

    // MARK: - Queries

    func hasSeen(_ url: URL) -> Bool {
        seenSet.contains(url.absoluteString)
    }

    // MARK: - Mutations

    /// Mark a single URL as seen. No-op if already present.
    func markSeen(_ url: URL) {
        markSeen([url])
    }

    /// Mark a batch of URLs as seen. Batching matters because `save()` writes
    /// to UserDefaults; we want one write per fetch, not N.
    func markSeen(_ urls: [URL]) {
        var changed = false
        for url in urls {
            let key = url.absoluteString
            if !seenSet.contains(key) {
                seenSet.insert(key)
                order.append(key)
                changed = true
            }
        }
        guard changed else { return }

        // FIFO evict if we've blown past the cap.
        if order.count > maxEntries {
            let dropCount = order.count - maxEntries
            let dropped = order.prefix(dropCount)
            order.removeFirst(dropCount)
            for key in dropped { seenSet.remove(key) }
        }

        save()
    }

    /// Wipe the log. Useful for a hypothetical "clear notification history"
    /// affordance or when switching focus to a fresh topic.
    func clear() {
        order.removeAll()
        seenSet.removeAll()
        save()
    }

    // MARK: - Persistence

    private func save() {
        defaults.set(order, forKey: key)
    }
}
