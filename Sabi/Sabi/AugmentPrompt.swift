//
//  AugmentPrompt.swift
//  Sabi
//
//  Intent refinement prompt + helper. Keeps the prompt out of view code
//  so we can iterate on it independently.
//

import Foundation

nonisolated enum AugmentPrompt {
    /// System prompt for the augment step. The model's job: take a vague seed
    /// like "AI stuff I'm learning" and produce a specific learning intent
    /// like "Context engineering for coding agents, CRISPE workflow, agent prompt design."
    static let systemPrompt = """
    You help a developer crystallize a vague "what I'm learning right now" seed into a crisp, specific learning intent that a retrieval system can use to find the best related resources.

    Input: a short, possibly vague seed like "AI stuff I'm learning", "coding agents", or "pasta".
    Output: 1–2 sentences, roughly 15–40 words total, that name specific concepts, frameworks, techniques, named resources, or open questions the person is likely grappling with.

    Rules:
    - Be concrete. Prefer named concepts, frameworks, and techniques over categories.
    - If the seed implies a software/engineering domain, lean on named methodologies, papers, or tools.
    - Match the seed's domain exactly (software → software, cooking → cooking, music → music).
    - Preserve first-person voice if the seed is in first person; otherwise use a neutral descriptive tone.
    - Never ask a clarifying question. Always produce a refined intent, making the most reasonable assumptions.
    - No preamble, no explanation, no markdown. Output only the refined intent text itself.
    """

    /// Send the seed to Haiku with the augment system prompt, return the refined intent.
    static func refine(seed: String) async throws -> String {
        let cleanSeed = seed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanSeed.isEmpty else {
            throw AugmentError.emptySeed
        }
        let refined = try await AnthropicClient.complete(
            prompt: cleanSeed,
            system: systemPrompt,
            maxTokens: 256
        )
        return refined.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum AugmentError: LocalizedError {
    case emptySeed

    var errorDescription: String? {
        switch self {
        case .emptySeed:
            return "Type something first — even a few words work."
        }
    }
}
