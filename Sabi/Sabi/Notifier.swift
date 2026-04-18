//
//  Notifier.swift
//  Sabi
//
//  Slice 4 — macOS local notifications. Requests auth on first use,
//  fires one banner per top pick, opens the pick's URL on click.
//
//  `UNUserNotificationCenter` works in a sandboxed macOS app without any
//  additional entitlement — the user grants permission at runtime on the
//  first authorization request.
//
//  Lives on the main actor because:
//   - `UNUserNotificationCenter.delegate` touches UI
//   - the click handler opens a URL via `NSWorkspace`
//

import AppKit
import Foundation
import UserNotifications

@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()

    private override init() { super.init() }

    /// Wire up the delegate so we can (a) show banners while foregrounded
    /// and (b) handle taps. Call once from `SabiApp` at launch.
    func bootstrap() {
        UNUserNotificationCenter.current().delegate = self
    }

    /// Ask the system for alert + sound permission. Safe to call repeatedly;
    /// macOS only prompts the user the first time.
    func requestAuthorization() async {
        do {
            _ = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            print("[Sabi] Notification auth error: \(error)")
        }
    }

    /// Fire a single "Sabi has a pick" banner for `url`. Stores the URL in
    /// `userInfo` so the click handler can open it.
    func sendTopPick(title: String, hostname: String, url: URL) async {
        let content = UNMutableNotificationContent()
        content.title = "Sabi has a pick"
        content.body = "\(title) — \(hostname)"
        content.sound = .default
        content.userInfo = ["url": url.absoluteString]

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil  // deliver immediately
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("[Sabi] Notification deliver error: \(error)")
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Show the banner even when Sabi is the foreground app. Without this,
    /// macOS swallows the notification while our popover is open.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    /// User clicked (or otherwise interacted with) the banner. Open the URL
    /// we stashed in `userInfo` in the default browser.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let urlString = userInfo["url"] as? String,
           let url = URL(string: urlString) {
            Task { @MainActor in
                NSWorkspace.shared.open(url)
            }
        }
        completionHandler()
    }
}
