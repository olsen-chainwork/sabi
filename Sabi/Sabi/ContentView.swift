//
//  ContentView.swift
//  Sabi
//

import SwiftUI

struct ContentView: View {
    @State private var result: String = ""
    @State private var errorMessage: String? = nil
    @State private var isLoading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sabi")
                .font(.title)
                .fontWeight(.semibold)

            Text("Slice 2a — API round-trip test")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(action: ping) {
                if isLoading {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Pinging Haiku…")
                    }
                } else {
                    Text("Ping Haiku")
                }
            }
            .disabled(isLoading)

            Divider()

            if let errorMessage {
                ScrollView {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if result.isEmpty {
                Text("Click \"Ping Haiku\" to verify the API works.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    Text(result)
                        .font(.caption)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding()
        .frame(width: 340, height: 280)
    }

    private func ping() {
        Task {
            isLoading = true
            errorMessage = nil
            result = ""
            defer { isLoading = false }
            do {
                let text = try await AnthropicClient.complete(
                    prompt: "Say hi in one short sentence. Be friendly."
                )
                print("[Sabi] Anthropic reply: \(text)")
                result = text
            } catch {
                print("[Sabi] Anthropic error: \(error)")
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    ContentView()
}
