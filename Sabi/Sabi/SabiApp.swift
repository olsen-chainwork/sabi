//
//  SabiApp.swift
//  Sabi
//

import AppKit
import SwiftUI

@main
struct SabiApp: App {
    // Use an NSApplicationDelegate so we can:
    //  (a) call `setActivationPolicy(.accessory)` at the right lifecycle point,
    //      which keeps macOS from respawning the agent on notification tap
    //      (LSUIElement=YES in Info.plist does this at launch, but making it
    //      explicit prevents LaunchServices from re-launching on notification
    //      activation)
    //  (b) wire up the UNUserNotificationCenter delegate in
    //      `applicationDidFinishLaunching`, which is the canonical spot.
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Sabi", systemImage: "binoculars") {
            ContentView()
        }
        .menuBarExtraStyle(.window)

        // Slice 6 — `.settings { }` gives us a Cmd+, window for free.
        // Accessory apps don't have a menu bar, so Cmd+, from inside the
        // popover is the canonical way to open this on macOS.
        Settings {
            SourcesSettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Explicit accessory policy. Defensive against LSUIElement edge cases
        // and notification-tap respawns.
        NSApp.setActivationPolicy(.accessory)

        // Wire up notification delegate before any banner can present.
        Notifier.shared.bootstrap()

        // Slice 7 — prompt for notification permission up front, then start
        // the background poller. Auth request is idempotent; macOS only
        // actually prompts on the first run. If the user denies, the poller
        // still runs, `sendTopPick` just silently fails at delivery time.
        Task { @MainActor in
            await Notifier.shared.requestAuthorization()
            BackgroundPoller.shared.start()
        }
    }
}
