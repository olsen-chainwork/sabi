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
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Explicit accessory policy. Defensive against LSUIElement edge cases
        // and notification-tap respawns.
        NSApp.setActivationPolicy(.accessory)

        // Wire up notification delegate before any banner can present.
        // Auth is requested lazily the first time `Sabi now` runs.
        Notifier.shared.bootstrap()
    }
}
