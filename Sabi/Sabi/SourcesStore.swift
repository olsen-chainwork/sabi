//
//  SourcesStore.swift
//  Sabi
//
//  Slice 6 — user edits on top of the curated source list.
//
//  Model: curated baseline is immutable (DomainAllowlist.suffixes). The
//  user can (a) add their own domains, and (b) disable any domain — curated
//  or their own — by flipping it off. Two arrays on disk:
//
//    userAdditions: [String]  — domains the user typed in, in add order
//    userRemovals:  Set<String> — domains the user has flipped off
//
//  The effective list Sabi searches is:
//    (curated ∪ additions) - removals
//
//  Persisted in UserDefaults under versioned keys so we can migrate later.
//

import Foundation
import Observation

@Observable
@MainActor
final class SourcesStore {
    static let shared = SourcesStore()

    private let additionsKey = "sabi.sources.userAdditions.v1"
    private let removalsKey = "sabi.sources.userRemovals.v1"
    private let defaults: UserDefaults

    private(set) var userAdditions: [String] = []
    private(set) var userRemovals: Set<String> = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let additions = defaults.array(forKey: additionsKey) as? [String] {
            self.userAdditions = additions
        }
        if let removals = defaults.array(forKey: removalsKey) as? [String] {
            self.userRemovals = Set(removals)
        }
    }

    // MARK: - Effective list

    /// The actual list Sabi uses for retrieval. Curated items come first
    /// (preserving the curated order), then user additions in add order.
    /// Disabled domains are filtered out.
    var effectiveSuffixes: [String] {
        let curatedKept = DomainAllowlist.suffixes.filter { !userRemovals.contains($0) }
        let addedKept = userAdditions.filter { !userRemovals.contains($0) }
        return curatedKept + addedKept
    }

    // MARK: - Queries

    /// True if `suffix` is part of the curated baseline (as opposed to a user addition).
    func isCurated(_ suffix: String) -> Bool {
        DomainAllowlist.suffixes.contains(suffix)
    }

    /// True if the user has turned this suffix off.
    func isDisabled(_ suffix: String) -> Bool {
        userRemovals.contains(suffix)
    }

    // MARK: - Mutations

    /// Add a user-defined domain. Accepts raw input like `https://example.com/blog`
    /// or `example.com`. Normalizes to the bare host. No-op on invalid or empty input.
    @discardableResult
    func addDomain(_ raw: String) -> Bool {
        guard let host = normalizeHost(raw), !host.isEmpty else { return false }

        // If the user had previously disabled this (curated or added), un-disable it.
        if userRemovals.contains(host) {
            userRemovals.remove(host)
        }
        // Don't duplicate a curated domain in the user additions list.
        if !DomainAllowlist.suffixes.contains(host),
           !userAdditions.contains(host) {
            userAdditions.append(host)
        }
        save()
        return true
    }

    /// Remove a user-added domain entirely. No effect on curated domains
    /// (use `setEnabled(_:enabled:)` to toggle curated items instead).
    func removeUserDomain(_ suffix: String) {
        guard userAdditions.contains(suffix) else { return }
        userAdditions.removeAll { $0 == suffix }
        // Also clean up any stale removal entry for this domain.
        userRemovals.remove(suffix)
        save()
    }

    /// Toggle a domain on or off. Off → moved to removals; on → removed from removals.
    /// Works for both curated and user-added domains.
    func setEnabled(_ suffix: String, enabled: Bool) {
        if enabled {
            userRemovals.remove(suffix)
        } else {
            userRemovals.insert(suffix)
        }
        save()
    }

    /// Wipe user edits. Every curated domain is re-enabled; every user addition is removed.
    func resetToDefaults() {
        userAdditions = []
        userRemovals = []
        save()
    }

    // MARK: - Persistence

    private func save() {
        defaults.set(userAdditions, forKey: additionsKey)
        defaults.set(Array(userRemovals), forKey: removalsKey)
    }

    // MARK: - Normalization

    /// Pull a hostname out of user input. Handles `https://example.com/path`,
    /// `www.example.com`, or bare `example.com`. Returns lowercased host or nil.
    private func normalizeHost(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.isEmpty { return nil }

        // Try parsing as a URL; strip scheme if present.
        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        if let url = URL(string: candidate), let host = url.host, !host.isEmpty {
            // Strip a leading "www." since the allowlist uses suffix matching;
            // "www.example.com" would never match "example.com" otherwise.
            return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        }

        // Fall back: treat input as a bare host, strip any trailing path.
        let bare = trimmed
            .split(separator: "/", maxSplits: 1)
            .first
            .map(String.init) ?? trimmed
        return bare.hasPrefix("www.") ? String(bare.dropFirst(4)) : bare
    }
}
