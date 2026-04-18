//
//  Retrieval.swift
//  Sabi
//
//  Orchestrates BraveClient + DomainAllowlist + SourcesStore.
//
//  Slice 3 — search the open web, then filter to allowlist.
//  Slice 5 — flipped to site-restricted search. For broad seeds like
//            "economics" the allowlist sources don't crack Brave's top
//            20 on the open web (Wikipedia/Investopedia/etc. dominate),
//            so we ask Brave directly for results from our sites via
//            `site:a OR site:b OR …` chains.
//  Slice 6 — `fetch` takes an explicit `suffixes` list so callers can
//            pass the effective (curated + user-edited) set. Keeps
//            actor isolation clean: SourcesStore is MainActor, but
//            Retrieval runs off-actor for the Brave round-trips.
//
//  Brave caps the `q` param at 400 characters. Fixed-count batching
//  (e.g. 15 domains) is fragile — a batch full of long domain names
//  like `applieddivinitystudies.com` blows past the limit while a
//  batch of short ones wastes budget. So we pack by character budget
//  instead: domains accrete into a batch until adding the next would
//  exceed ~250 chars of site-clause, leaving ~150 for the intent plus
//  wrapping. Self-tunes as the allowlist grows.
//
//  Batches fire serially — Brave's free tier rate-limits to ~1 req/sec
//  and will 429 on simultaneous bursts. Results are unioned and URL-deduped.
//
//  Two signals bias us toward articles over navigation pages:
//    1. `freshness=py` — past-year content, which is overwhelmingly
//       posts/papers rather than evergreen homepages.
//    2. Path-shape filter — drop URLs whose path looks like a root or
//       a short hub (`/`, `/about`, `/research`). Keep anything with
//       a slug, file extension, or ≥2 path segments.
//

import Foundation

nonisolated enum Retrieval {
    /// Max length of the `site:a OR site:b OR …` clause we'll send in one
    /// Brave query. Brave's hard limit on `q` is 400; we reserve ~150
    /// for the intent and the wrapping parens/space.
    private static let maxSiteClauseLength = 250

    /// Fetch candidates for the given intent from `suffixes` via Brave's
    /// `site:` operator, then return up to `limit` deduped results.
    ///
    /// `suffixes` is typically `SourcesStore.shared.effectiveSuffixes` snapshot
    /// on the MainActor before the call. Passing it in rather than reading a
    /// global keeps this function off-actor and avoids an actor hop per filter.
    ///
    /// `freshness` maps to Brave's freshness param:
    ///   - `"py"` (past year) for manual Fetch — biases toward articles over
    ///     evergreen hubs, but keeps the pool deep enough to fill top-10.
    ///   - `"pw"` (past week) for background polling (slice 7) — "brand new"
    ///     actually means new; we only want to ping for content that didn't
    ///     exist the last time we polled.
    static func fetch(
        for intent: String,
        suffixes: [String],
        limit: Int = 10,
        freshness: String = "py"
    ) async throws -> [BraveClient.Result] {
        let cleaned = intent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            throw RetrievalError.emptyIntent
        }
        guard !suffixes.isEmpty else {
            throw RetrievalError.noAllowedResults
        }

        let batches = packBatches(
            domains: suffixes,
            maxClauseLength: maxSiteClauseLength
        )

        var pooled: [BraveClient.Result] = []
        for batch in batches {
            let siteClause = batch
                .map { "site:\($0)" }
                .joined(separator: " OR ")
            let query = "\(cleaned) (\(siteClause))"
            let results = try await BraveClient.search(query: query, count: 10, freshness: freshness)
            pooled.append(contentsOf: results)
        }

        // Defense-in-depth: the `site:` operator is usually reliable but
        // re-filter against the passed-in suffixes so nothing sneaks through.
        // Also drop homepages / short hub pages — we want articles.
        let filtered = pooled.filter {
            isAllowed(url: $0.url, among: suffixes) && looksLikeArticle($0.url)
        }

        // Dedup by URL; the first occurrence wins (higher-ranked batch).
        var seen = Set<URL>()
        let deduped = filtered.filter { seen.insert($0.url).inserted }

        // Round-robin across hosts before trimming to `limit`.
        //
        // Why this exists: batches fire serially and each returns its own
        // top 10. For a topic-concentrated intent (e.g. "LLM evaluation"
        // hits arxiv hard), batch 1 alone can fill 10 slots with a single
        // host, and `prefix(limit)` on the pooled list would never reach
        // later batches' LessWrong / Distill / Stratechery hits. Ranker
        // diversify then has nothing to spread across.
        //
        // Interleaving by host forces the pool handed to the ranker to
        // carry source breadth, which Haiku can then prioritize by
        // topical match. Relative rank within a host is preserved —
        // we just cycle through hosts one at a time.
        return interleaveByHost(deduped, limit: limit)
    }

    /// Round-robin results by hostname. First pass picks the top result
    /// from each host in first-seen order; subsequent passes do the same
    /// with whatever's left, until we've hit `limit` or exhausted the pool.
    private static func interleaveByHost(
        _ results: [BraveClient.Result],
        limit: Int
    ) -> [BraveClient.Result] {
        var queues: [String: [BraveClient.Result]] = [:]
        var order: [String] = []
        for result in results {
            let host = (result.url.host ?? "").lowercased()
            if queues[host] == nil { order.append(host) }
            queues[host, default: []].append(result)
        }

        var out: [BraveClient.Result] = []
        while out.count < limit {
            var pulledThisRound = false
            for host in order {
                guard !(queues[host]?.isEmpty ?? true) else { continue }
                out.append(queues[host]!.removeFirst())
                pulledThisRound = true
                if out.count >= limit { return out }
            }
            if !pulledThisRound { break }
        }
        return out
    }

    /// Suffix-match a URL's host against the given list. Mirrors
    /// `DomainAllowlist.isAllowed(url:)` but takes the list as a parameter
    /// so we can use the effective (user-edited) list without coupling to
    /// a MainActor-isolated store.
    private static func isAllowed(url: URL, among suffixes: [String]) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return suffixes.contains { suffix in
            host == suffix || host.hasSuffix("." + suffix)
        }
    }

    /// Heuristic: is this URL's path shaped like an article rather than a
    /// homepage or hub page? Purely URL-based — no fetching.
    ///
    /// Keep:
    ///   - 2+ path segments (`/blog/post-name`, `/abs/2401.12345`)
    ///   - 1 segment with a slug marker (hyphen), file extension, or ≥20 chars
    ///
    /// Drop:
    ///   - Empty or root paths (`""`, `/`)
    ///   - Single short segments (`/about`, `/research`, `/en`, `/products`)
    private static func looksLikeArticle(_ url: URL) -> Bool {
        let path = url.path
        if path.isEmpty || path == "/" { return false }

        let segments = path.split(separator: "/").map(String.init)
        if segments.count >= 2 { return true }

        guard let only = segments.first else { return false }
        return only.contains("-") || only.contains(".") || only.count >= 20
    }

    /// Pack domains into batches such that no batch's resulting
    /// `site:a OR site:b OR …` clause exceeds `maxClauseLength` chars.
    /// Short domains pack densely; a long domain starts a new batch
    /// if the current one is full. A single domain longer than the
    /// budget gets its own batch (it'll fail the Brave length check
    /// on the intent side, which is the right place to error out).
    private static func packBatches(
        domains: [String],
        maxClauseLength: Int
    ) -> [[String]] {
        let separator = " OR "
        var batches: [[String]] = []
        var current: [String] = []
        var currentLen = 0

        for domain in domains {
            let piece = "site:\(domain)"
            let added = current.isEmpty ? piece.count : piece.count + separator.count
            if !current.isEmpty && currentLen + added > maxClauseLength {
                batches.append(current)
                current = [domain]
                currentLen = piece.count
            } else {
                current.append(domain)
                currentLen += added
            }
        }
        if !current.isEmpty {
            batches.append(current)
        }
        return batches
    }
}

enum RetrievalError: LocalizedError {
    case emptyIntent
    case noAllowedResults

    var errorDescription: String? {
        switch self {
        case .emptyIntent:
            return "Save your focus first, then hit Fetch."
        case .noAllowedResults:
            return "Couldn't find a good source for that. Try rephrasing your focus."
        }
    }
}
