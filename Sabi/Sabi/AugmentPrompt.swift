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
    You help a learner crystallize a vague "what I'm learning right now" seed into a crisp, specific learning focus that a retrieval system can use to find the best related resources.

    Input: a short, possibly vague seed like "AI stuff I'm learning", "coding agents", or "pasta".
    Output: 1–2 sentences, 15–30 words total. Shorter is better if you can still name specific concepts, frameworks, techniques, named resources, or open questions the person is likely grappling with.

    Rules:
    - Be concrete. Prefer named concepts, frameworks, and techniques over categories.
    - If the seed is a broad category (a single word like "economics" or "physics"), narrow aggressively to a specific current debate, sub-discipline, or named school of thought. Do NOT output a textbook definition or an encyclopedic overview.
    - If the seed implies a software/engineering domain, lean on named methodologies, papers, or tools.
    - Match the seed's domain exactly (software → software, cooking → cooking, music → music).
    - Preserve first-person voice if the seed is in first person; otherwise use a neutral descriptive tone.
    - Never ask a clarifying question. Always produce a refined focus, making the most reasonable assumptions.
    - No preamble, no explanation, no markdown. Output only the refined focus text itself.

    Never output a definition or encyclopedic overview. These are wrong:
      - "Artificial intelligence is the field of computer science concerned with..."
      - "Economics studies how societies allocate scarce resources..."
      - "Philosophy of mind is the branch of philosophy that examines..."
    Always pick a specific current angle the person is likely chasing.

    Examples of broad seeds narrowed well:

    Input: AI
    Output: Frontier LLM capability evaluation — agentic tool use, long-context reasoning, and methodology debates around benchmarks like SWE-bench and ARC-AGI.

    Input: coding agents
    Output: Context engineering for coding agents — retrieval-augmented prompts, tool-use protocols, and agent evaluation on benchmarks like SWE-bench.

    Input: economics
    Output: Current debates in labor and macro economics — how remote work reshapes wage dynamics, monetary policy passthrough to housing, and services-driven inflation.

    Input: philosophy of mind
    Output: The hard problem of consciousness as framed by Chalmers — computational functionalism, higher-order theories, and integrated information theory.
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
