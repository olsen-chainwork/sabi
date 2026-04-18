//
//  ContentView.swift
//  Scout
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Scout")
                .font(.title)
                .fontWeight(.semibold)
            Text("Menu bar hello world.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(width: 240, height: 140)
    }
}

#Preview {
    ContentView()
}
