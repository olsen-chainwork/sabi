//
//  IntentStore.swift
//  Sabi
//
//  Persists the current "what I'm learning right now" intent.
//  Slice 2b: UserDefaults is fine; one string, no history, no migration.
//  Slice 5+ may add a separate feedback/pings store backed by a JSON file.
//

import Foundation
import Observation

@Observable
final class IntentStore {
    /// Singleton so any view can observe without plumbing.
    static let shared = IntentStore()

    private let key = "sabi.intent.current.v1"
    private let defaults: UserDefaults

    /// The refined intent the user has confirmed.
    /// Empty string == no intent saved.
    var currentIntent: String {
        didSet {
            defaults.set(currentIntent, forKey: key)
        }
    }

    var hasIntent: Bool { !currentIntent.isEmpty }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.currentIntent = defaults.string(forKey: key) ?? ""
    }

    func save(_ intent: String) {
        currentIntent = intent.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func clear() {
        currentIntent = ""
    }
}
