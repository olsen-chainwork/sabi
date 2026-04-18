//
//  AnthropicClient.swift
//  Sabi
//
//  Minimal Anthropic Messages API client. One round-trip, no streaming,
//  no tool use, no retry. Slice 2 proof-of-life.
//
//  Marked `nonisolated` because the project default is @MainActor and we
//  don't want network work pinned to the main thread.
//

import Foundation

nonisolated enum AnthropicClient {
    // Haiku 4.5 per DESIGN-DOC. Locked.
    static let model = "claude-haiku-4-5-20251001"
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    static let apiVersion = "2023-06-01"

    /// Send a single user message to Claude, return the assistant's text reply.
    /// Throws on missing key, network error, non-2xx response, or malformed body.
    static func complete(
        prompt: String,
        system: String? = nil,
        maxTokens: Int = 1024
    ) async throws -> String {
        guard Secrets.anthropicAPIKey != "REPLACE_ME",
              !Secrets.anthropicAPIKey.isEmpty else {
            throw AnthropicError.missingAPIKey
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Secrets.anthropicAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")

        let body = MessagesRequest(
            model: model,
            maxTokens: maxTokens,
            system: system,
            messages: [.init(role: "user", content: prompt)]
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AnthropicError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "<no body>"
            throw AnthropicError.httpError(status: http.statusCode, body: errorBody)
        }

        let decoded = try JSONDecoder().decode(MessagesResponse.self, from: data)
        guard let text = decoded.content.first(where: { $0.type == "text" })?.text,
              !text.isEmpty else {
            throw AnthropicError.emptyContent
        }
        return text
    }
}

// MARK: - Wire types

extension AnthropicClient {
    struct MessagesRequest: Encodable {
        let model: String
        let maxTokens: Int
        let system: String?
        let messages: [Message]

        struct Message: Encodable {
            let role: String
            let content: String
        }

        enum CodingKeys: String, CodingKey {
            case model
            case maxTokens = "max_tokens"
            case system
            case messages
        }
    }

    struct MessagesResponse: Decodable {
        let content: [ContentBlock]

        struct ContentBlock: Decodable {
            let type: String
            let text: String?
        }
    }
}

// MARK: - Errors

enum AnthropicError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case httpError(status: Int, body: String)
    case emptyContent

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Anthropic API key is missing. Paste your key into Sabi/Sabi/Secrets.swift."
        case .invalidResponse:
            return "Response was not a valid HTTP response."
        case .httpError(let status, let body):
            return "Anthropic API error \(status): \(body)"
        case .emptyContent:
            return "Anthropic returned no text content."
        }
    }
}
