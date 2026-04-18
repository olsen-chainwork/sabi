//
//  SabiApp.swift
//  Sabi
//

import SwiftUI

@main
struct SabiApp: App {
    var body: some Scene {
        MenuBarExtra("Sabi", systemImage: "binoculars") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
