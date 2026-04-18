//
//  PollingPrefs.swift
//  Sabi
//
//  Slice 7 — single bool for whether background polling runs.
//
//  Kept in its own tiny file (not folded into SourcesStore) because these
//  are two different concerns: SourcesStore is about which *places* Sabi
//  searches; PollingPrefs is about how often Sabi *runs*. Bundling them
//  would couple unrelated settings UI sections to one object. A third
//  polling knob (cadence picker) could land here cleanly if we decide
//  to expose that later.
//
//  Default: polling ON. Matches the product vision — Sabi pings you when
//  something new shows up; you opt out if you'd rather pull than be pushed.
//

import Foundation
import Observation

@Observable
@MainActor
final class PollingPrefs {
    static let shared = PollingPrefs()

    private let enabledKey = "sabi.polling.enabled.v1"
    private let defaults: UserDefaults

    /// Whether the background poller is allowed to fire. BackgroundPoller
    /// reads this on every tick, so flipping this off takes effect on the
    /// next scheduled activity (within ~4h in the worst case).
    var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: enabledKey)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Default to true on first launch. `object(forKey:)` returns nil
        // if the key was never written, vs. `bool(forKey:)` which returns
        // false — we need to distinguish "not set yet" from "user turned off".
        if let stored = defaults.object(forKey: enabledKey) as? Bool {
            self.isEnabled = stored
        } else {
            self.isEnabled = true
        }
    }
}
