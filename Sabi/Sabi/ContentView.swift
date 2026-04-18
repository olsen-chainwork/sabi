//
//  ContentView.swift
//  Sabi
//
//  Slice 2b — Intent + augment + confirm.
//  Slice 3  — Saved view adds "Sabi now" → Brave retrieval + allowlist.
//  Slice 4  — Ranker (Haiku) + one-ping notification for the top pick.
//  Slice 5  — Minimum lovable copy: rotating augment spinners, "Use as-is"
//             escape hatch on idle, strings tightened throughout. Renamed
//             the retrieval CTA "Sabi now" → "Fetch" — a verb with some
//             personality that fits the little-assistant framing without
//             leaning on the brand name itself. Also pulled the top-pick
//             notification from the manual path: it's redundant when the
//             popover is open and the ranked list is right there. The
//             ping earns its keep on the slice 7 background-polling path,
//             where Sabi surfaces new reading while the user is off-task.
//
//  Four-mode state machine for the intent flow:
//    .idle        seed TextField + Augment + Use as-is
//    .augmenting  spinner while the refiner runs
//    .reviewing   editable refined focus + Looks good / Regenerate
//    .saved       persisted focus + Fetch + ranked list + Edit
//
//  Retrieval state lives inside the saved view as its own ad-hoc mini-machine
//  (isRetrieving → isRanking → ranked list) so the four-mode top-level switch
//  stays focused on intent.
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

    /// Rotating spinner copy for the augment step. A fresh phrase is picked
    /// every time `augment()` runs so repeated use feels alive instead of stale.
    private static let spinnerPhrases = [
        "Pulling it into focus…",
        "Reading between the lines…",
        "Turning it over…",
    ]

    @State private var mode: Mode = .idle
    @State private var seed: String = ""
    @State private var draft: String = ""
    @State private var errorMessage: String? = nil
    @State private var spinnerPhrase: String = "Pulling it into focus…"

    // Slice 3+4 retrieval state (scoped to the saved view).
    @State private var ranked: [Ranker.RankedResult] = []
    @State private var isRetrieving: Bool = false
    @State private var isRanking: Bool = false
    @State private var retrievalError: String? = nil

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
        .frame(width: 420, height: 560)
        .onAppear(perform: onAppear)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Sabi")
                .font(.title)
                .fontWeight(.semibold)
            Text(headerSubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var headerSubtitle: String {
        switch mode {
        case .idle: return "What are you curious about?"
        case .augmenting: return "Sharpening your focus…"
        case .reviewing: return "Does this look right?"
        case .saved: return "Sabi's watching the web for this"
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
            Text("What's caught your attention lately?")
                .font(.headline)
            TextField(
                "e.g. AI, industrial policy, or black holes",
                text: $seed,
                axis: .vertical
            )
            .textFieldStyle(.roundedBorder)
            .lineLimit(2...4)

            HStack {
                Button("Use as-is", action: useSeedAsIs)
                    .buttonStyle(.bordered)
                    .disabled(trimmedSeed.isEmpty)
                Spacer()
                Button("Augment", action: augment)
                    .buttonStyle(.borderedProminent)
                    .disabled(trimmedSeed.isEmpty)
                    .keyboardShortcut(.return, modifiers: [.command])
            }
            Text("⌘↩ to augment (recommended)")
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
                Text(spinnerPhrase)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Reviewing

    private var reviewingView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What Sabi heard · edit if needed")
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
            Text("Your focus")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(intents.currentIntent)
                .font(.body)
                .textSelection(.enabled)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Button(action: runRetrieval) {
                    if isRetrieving {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("Searching the web…")
                        }
                    } else if isRanking {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("Picking the best one…")
                        }
                    } else {
                        Text("Fetch")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRetrieving || isRanking)
                .keyboardShortcut(.return, modifiers: [.command])

                Spacer()

                Button("Edit", action: startEdit)
                    .buttonStyle(.bordered)
            }

            Divider()

            candidatesSection
        }
    }

    @ViewBuilder
    private var candidatesSection: some View {
        if let retrievalError {
            errorBanner(retrievalError)
            Spacer(minLength: 0)
        } else if isRetrieving {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Searching the web…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        } else if isRanking {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Picking the best one…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        } else if ranked.isEmpty {
            Text("Hit Fetch and we'll find you a good read.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(ranked) { result in
                        rankedRow(result)
                        Divider()
                    }
                }
                .padding(.trailing, 4)
            }
        }
    }

    private func rankedRow(_ result: Ranker.RankedResult) -> some View {
        Link(destination: result.base.url) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("#\(result.rank)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Text(result.base.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Text(result.base.hostname)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                if !result.reason.isEmpty {
                    Text(result.reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                } else if !result.base.description.isEmpty {
                    Text(result.base.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Error banner

    private func errorBanner(_ message: String) -> some View {
        ScrollView {
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 80)
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
        if intents.hasIntent && mode == .idle {
            mode = .saved
        }
    }

    private func augment() {
        guard !trimmedSeed.isEmpty else { return }
        errorMessage = nil
        // Pick a fresh spinner phrase so repeat runs feel alive.
        spinnerPhrase = Self.spinnerPhrases.randomElement() ?? "Sharpening your focus…"
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
                mode = .idle
            }
        }
    }

    /// Skip the augment step and persist the raw seed as the focus.
    /// Gated on a non-empty seed; no other guardrails — the visual hierarchy
    /// (bordered vs. prominent) and the "(recommended)" caption nudge users
    /// toward the happy path without blocking the escape hatch.
    private func useSeedAsIs() {
        guard !trimmedSeed.isEmpty else { return }
        intents.save(trimmedSeed)
        errorMessage = nil
        ranked = []
        retrievalError = nil
        mode = .saved
    }

    private func save() {
        guard !trimmedDraft.isEmpty else { return }
        intents.save(trimmedDraft)
        errorMessage = nil
        // Clear any stale retrieval state when the intent changes.
        ranked = []
        retrievalError = nil
        mode = .saved
    }

    private func startEdit() {
        seed = ""
        draft = ""
        errorMessage = nil
        // Don't clear ranked here — intent is still saved, user may come back.
        mode = .idle
    }

    private func runRetrieval() {
        let intent = intents.currentIntent
        guard !intent.isEmpty else { return }
        retrievalError = nil
        isRetrieving = true
        Task {
            // 1. Brave + allowlist
            let candidates: [BraveClient.Result]
            do {
                candidates = try await Retrieval.fetch(for: intent)
                print("[Sabi] Retrieved \(candidates.count) allowlisted candidates for: \(intent)")
            } catch {
                print("[Sabi] Retrieval error: \(error)")
                retrievalError = error.localizedDescription
                ranked = []
                isRetrieving = false
                return
            }

            if candidates.isEmpty {
                retrievalError = RetrievalError.noAllowedResults.localizedDescription
                ranked = []
                isRetrieving = false
                return
            }

            // 2. Haiku re-rank
            isRetrieving = false
            isRanking = true
            let rankedResults: [Ranker.RankedResult]
            do {
                rankedResults = try await Ranker.rank(intent: intent, candidates: candidates)
                print("[Sabi] Ranked \(rankedResults.count) candidates. Top: \(rankedResults.first?.base.title ?? "<none>")")
            } catch {
                // Ranker.rank only throws on truly unexpected failures — parse/network
                // failures fall back internally. Surface anything else as an error.
                print("[Sabi] Ranking error: \(error)")
                retrievalError = error.localizedDescription
                ranked = []
                isRanking = false
                return
            }
            ranked = rankedResults
            isRanking = false

            // Slice 5: no notification on the manual path. Notifications
            // come back in slice 7 on the scheduled-polling background path.
        }
    }
}

#Preview {
    ContentView()
}
