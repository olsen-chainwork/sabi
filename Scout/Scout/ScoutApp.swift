//
//  ScoutApp.swift
//  Scout
//

import SwiftUI

@main
struct ScoutApp: App {
    var body: some Scene {
        MenuBarExtra("Scout", systemImage: "binoculars") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
