//
//  ContentView.swift
//  Sabi
//
//  Slice 2b — Intent + augment + confirm.
//
//  Four-mode state machine:
//    .idle        seed TextField + Augment button
//    .augmenting  spinner while Haiku refines
//    .reviewing   editable refined intent + Looks Good / Regenerate
//    .saved       persisted intent + Edit
//
//  Errors surface in-place without losing seed/draft state.
//

import SwiftUI

struct ContentView: View {
    enum Mode {
        case idle
        case augmenting
        case reviewing
        case saved
    }

    /// @Observable singleton — SwiftUI re-renders when `currentIntent` changes.
    private let intents = IntentStore.shared

    @State private var mode: Mode = .idle
    @State private var seed: String = ""
    @State private var draft: String = ""
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            content
            if let errorMessage {
                errorBanner(errorMessage)
            }
        }
        .padding()
        .frame(width: 380, height: 360)
        .onAppear(perform: onAppear)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Sabi")
                .font(.title)
                .fontWeight(.semibold)
            Text("Intent — what are you learning?")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Mode switch

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .idle:
            idleView
        case .augmenting:
            augmentingView
        case .reviewing:
            reviewingView
        case .saved:
            savedView
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What are you learning right now?")
                .font(.headline)
            TextField(
                "e.g. coding agents, italian cooking, jazz piano",
                text: $seed,
                axis: .vertical
            )
            .textFieldStyle(.roundedBorder)
            .lineLimit(2...4)

            HStack {
                Spacer()
                Button("Augment", action: augment)
                    .buttonStyle(.borderedProminent)
                    .disabled(trimmedSeed.isEmpty)
                    .keyboardShortcut(.return, modifiers: [.command])
            }
            Text("⌘↩ to augment")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Augmenting

    private var augmentingView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Seed")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(seed)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Sharpening with Haiku…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Reviewing

    private var reviewingView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Refined intent · edit if needed")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $draft)
                .font(.body)
                .frame(minHeight: 110)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.secondary.opacity(0.35), lineWidth: 1)
                )

            HStack {
                Button("Regenerate", action: augment)
                    .buttonStyle(.bordered)
                Spacer()
                Button("Looks good", action: save)
                    .buttonStyle(.borderedProminent)
                    .disabled(trimmedDraft.isEmpty)
                    .keyboardShortcut(.return, modifiers: [.command])
            }
        }
    }

    // MARK: - Saved

    private var savedView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Current intent")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView {
                Text(intents.currentIntent)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 160)

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button("Edit", action: startEdit)
                    .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Error banner

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.red)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(Color.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Derived

    private var trimmedSeed: String {
        seed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Actions

    private func onAppear() {
        // If an intent is already saved, open straight to the saved view.
        if intents.hasIntent && mode == .idle {
            mode = .saved
        }
    }

    private func augment() {
        guard !trimmedSeed.isEmpty else { return }
        errorMessage = nil
        mode = .augmenting
        Task {
            do {
                let refined = try await AugmentPrompt.refine(seed: trimmedSeed)
                print("[Sabi] Refined intent: \(refined)")
                draft = refined
                mode = .reviewing
            } catch {
                print("[Sabi] Augment error: \(error)")
                errorMessage = error.localizedDescription
                // Fall back to whatever mode we came from, but idle is the safe default.
                mode = .idle
            }
        }
    }

    private func save() {
        guard !trimmedDraft.isEmpty else { return }
        intents.save(trimmedDraft)
        errorMessage = nil
        mode = .saved
    }

    private func startEdit() {
        // Leave the persisted intent in place until a new one is saved.
        // Editing starts fresh from a blank seed.
        seed = ""
        draft = ""
        errorMessage = nil
        mode = .idle
    }
}

#Preview {
    ContentView()
}
