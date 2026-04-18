//
//  Ranker.swift
//  Sabi
//
//  Slice 4 — Haiku-backed re-ranker on top of Brave + allowlist.
//
//  Flow:
//    intent + [BraveClient.Result]  →  JSON prompt  →  Haiku  →
//    JSON array of {index, reason}  →  [RankedResult] (best→worst)
//
//  If Haiku's response fails to parse, we fall back to Brave's original order
//  with an empty reason — retrieval still works, just without the LLM polish.
//

import Foundation

nonisolated enum Ranker {
    /// A candidate after the ranking pass. `base` is the original Brave hit;
    /// `rank` is 1-based (1 = best). `reason` is a one-liner from Haiku.
    struct RankedResult: Identifiable, Hashable {
        let id = UUID()
        let base: BraveClient.Result
        let rank: Int
        let reason: String
    }

    /// Rank `candidates` against `intent`. Returns them best→worst.
    /// Never throws on parse failure — falls back to Brave order instead.
    ///
    /// After Haiku's ranking, we apply a domain-diversification pass that
    /// caps each hostname at `maxPerDomain` in the top segment and pushes
    /// overflow to the end. This exists because Sabi's product promise is
    /// "curated mix of ~60 sources" but arxiv (and similar dominant sources)
    /// can easily sweep all 5 top slots for research-heavy queries. A
    /// soft cap preserves relevance (Haiku's top picks still win) while
    /// ensuring the top 5 telegraphs source breadth.
    static func rank(
        intent: String,
        candidates: [BraveClient.Result]
    ) async throws -> [RankedResult] {
        guard !candidates.isEmpty else { return [] }

        let prompt = buildPrompt(intent: intent, candidates: candidates)

        let reply: String
        do {
            reply = try await AnthropicClient.complete(
                prompt: prompt,
                system: Self.systemPrompt,
                maxTokens: 1024
            )
        } catch {
            print("[Sabi] Ranker network error: \(error) — falling back to Brave order")
            return diversify(fallback(candidates: candidates))
        }

        guard let parsed = parse(reply: reply, count: candidates.count) else {
            print("[Sabi] Ranker parse failed. Raw reply:\n\(reply)")
            return diversify(fallback(candidates: candidates))
        }

        let ordered = parsed.enumerated().map { (position, entry) in
            RankedResult(
                base: candidates[entry.index],
                rank: position + 1,
                reason: entry.reason
            )
        }
        return diversify(ordered)
    }

    // MARK: - Diversify

    /// Cap each domain at `maxPerDomain` in the top segment; overflow goes
    /// to the end, preserving within-bucket order. Rank numbers are
    /// recomputed so `#1…#N` always counts up in display order.
    ///
    /// Two-pass because single-pass "skip if over cap" would silently drop
    /// results — we want them pushed down, not omitted, since a user might
    /// scroll past the top 5.
    private static func diversify(
        _ results: [RankedResult],
        maxPerDomain: Int = 2
    ) -> [RankedResult] {
        var primary: [RankedResult] = []
        var overflow: [RankedResult] = []
        var counts: [String: Int] = [:]

        for result in results {
            let host = result.base.hostname
            let count = counts[host, default: 0]
            if count < maxPerDomain {
                primary.append(result)
                counts[host] = count + 1
            } else {
                overflow.append(result)
            }
        }

        return (primary + overflow).enumerated().map { (position, r) in
            RankedResult(base: r.base, rank: position + 1, reason: r.reason)
        }
    }

    // MARK: - Prompt

    private static let systemPrompt = """
    You are ranking candidate learning resources for a focused learner.

    You will receive the learner's intent and a JSON array of candidate \
    resources. Each candidate has an index (0-based), a title, a hostname, \
    and a short description.

    Your job: return a JSON array sorted from BEST to WORST match for the \
    intent. Each element must be an object with exactly two keys:
      - "index": the original 0-based index of the candidate
      - "reason": one short sentence (max 120 chars) explaining why this \
        candidate matches (or doesn't match) the intent. The reason must \
        add information beyond the title — say what specifically connects \
        this resource to the intent, not just restate what the resource is.

    Ranking criteria, in priority order:
      1. Topical specificity — does it address the exact intent, or just \
         the general area?
      2. Depth and authority — primary sources, original research, \
         and practitioner write-ups beat roundups and SEO content.
      3. Directness — a focused essay on the topic beats a broad hub page.

    Return ONLY the JSON array. No prose, no code fences, no keys outside \
    the array. Include every candidate exactly once.
    """

    private static func buildPrompt(
        intent: String,
        candidates: [BraveClient.Result]
    ) -> String {
        struct CandidatePayload: Encodable {
            let index: Int
            let title: String
            let hostname: String
            let description: String
        }

        let payload = candidates.enumerated().map { (i, c) in
            CandidatePayload(
                index: i,
                title: c.title,
                hostname: c.hostname,
                description: c.description
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = (try? encoder.encode(payload)) ?? Data()
        let json = String(data: data, encoding: .utf8) ?? "[]"

        return """
        Intent:
        \(intent)

        Candidates:
        \(json)
        """
    }

    // MARK: - Parse

    private struct RankEntry: Decodable {
        let index: Int
        let reason: String
    }

    /// Parse Haiku's reply. Tolerates leading/trailing prose and code fences
    /// by locating the first `[` and last `]`. Validates indices are in range
    /// and cover the full candidate set.
    private static func parse(reply: String, count: Int) -> [RankEntry]? {
        guard let jsonSlice = extractJSONArray(from: reply) else { return nil }
        guard let data = jsonSlice.data(using: .utf8) else { return nil }

        let decoder = JSONDecoder()
        guard let entries = try? decoder.decode([RankEntry].self, from: data) else {
            return nil
        }

        // Validate — every index in range, no duplicates, covers all candidates.
        let indices = entries.map(\.index)
        guard indices.count == count,
              Set(indices).count == count,
              indices.allSatisfy({ (0..<count).contains($0) }) else {
            return nil
        }

        return entries
    }

    private static func extractJSONArray(from text: String) -> String? {
        guard let start = text.firstIndex(of: "["),
              let end = text.lastIndex(of: "]"),
              start < end else {
            return nil
        }
        return String(text[start...end])
    }

    // MARK: - Fallback

    private static func fallback(candidates: [BraveClient.Result]) -> [RankedResult] {
        candidates.enumerated().map { (i, c) in
            RankedResult(base: c, rank: i + 1, reason: "")
        }
    }
}
