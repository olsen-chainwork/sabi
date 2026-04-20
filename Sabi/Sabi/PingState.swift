//
//  PingState.swift
//  Sabi
//
//  Slice 7 polish — "there's something new" indicator for the menu bar.
//
//  The problem: when Sabi's background poller fires a notification and the
//  user dismisses the banner (or misses it entirely because their screen
//  was locked, in Do Not Disturb, or they blinked), the menu bar icon
//  looks identical to "nothing has happened." They'd have to click the
//  icon to discover there's a fresh pick waiting.
//
//  The fix: a tiny piece of state that tracks "has a new ping arrived
//  since the user last opened the popover?" SabiApp overlays a small red
//  dot on the menu bar icon when `hasUnread == true`. The dot clears the
//  instant the user opens the popover (`ContentView.onAppear`), which is
//  the natural "I see it" signal.
//
//  Persisted so that if the user quits Sabi before looking at the ping
//  — or the poller fires, the OS tears the app down in the background,
//  and the user clicks the menu bar hours later — the red dot survives.
//
//  Mirrors the PollingPrefs pattern exactly: @Observable @MainActor
//  singleton with a versioned UserDefaults key for future-proof migration.
//

import Foundation
import Observation

@Observable
@MainActor
final class PingState {
    static let shared = PingState()

    private let hasUnreadKey = "sabi.pingstate.hasUnread.v1"
    private let defaults: UserDefaults

    /// True when a background poll has fired a notification that the user
    /// hasn't acknowledged by opening the popover yet.
    var hasUnread: Bool {
        didSet {
            defaults.set(hasUnread, forKey: hasUnreadKey)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let stored = defaults.object(forKey: hasUnreadKey) as? Bool {
            self.hasUnread = stored
        } else {
            self.hasUnread = false
        }
    }

    /// Called by BackgroundPoller right after a notification is sent.
    func markUnread() {
        hasUnread = true
    }

    /// Called by ContentView.onAppear — opening the popover is the user's
    /// "I see it" signal. Also exposed so callers (e.g. a Settings "Check
    /// now" button) can clear the badge without the user needing to
    /// re-open the popover, though that path isn't used today.
    func markRead() {
        hasUnread = false
    }
}
