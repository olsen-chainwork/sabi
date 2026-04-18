//
//  BraveClient.swift
//  Sabi
//
//  Minimal Brave Search Web API client. One GET, no streaming, no retry,
//  no goggles or advanced filters. Slice 3 proof-of-life for retrieval.
//
//  Endpoint: https://api.search.brave.com/res/v1/web/search
//  Auth: X-Subscription-Token header.
//

import Foundation

nonisolated enum BraveClient {
    static let endpoint = URL(string: "https://api.search.brave.com/res/v1/web/search")!

    /// A single search result. Identifiable so SwiftUI List/ForEach can render it.
    struct Result: Identifiable, Hashable {
        let id = UUID()
        let title: String
        let url: URL
        let description: String
        var hostname: String { url.host ?? url.absoluteString }
    }

    /// Run a web search for `query` and return up to `count` raw results.
    /// No allowlist applied here — filtering is `Retrieval`'s job.
    ///
    /// `freshness` maps to Brave's `freshness` param: `pd` (past day),
    /// `pw` (past week), `pm` (past month), `py` (past year), or a
    /// `YYYY-MM-DDtoYYYY-MM-DD` range. Nil means no date filter.
    static func search(query: String, count: Int = 20, freshness: String? = nil) async throws -> [Result] {
        guard Secrets.braveAPIKey != "REPLACE_ME", !Secrets.braveAPIKey.isEmpty else {
            throw BraveError.missingAPIKey
        }

        var items: [URLQueryItem] = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "count", value: String(count)),
            URLQueryItem(name: "safesearch", value: "moderate"),
        ]
        if let freshness {
            items.append(URLQueryItem(name: "freshness", value: freshness))
        }

        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = items
        guard let url = components.url else {
            throw BraveError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
        request.setValue(Secrets.braveAPIKey, forHTTPHeaderField: "X-Subscription-Token")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BraveError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<no body>"
            throw BraveError.httpError(status: http.statusCode, body: body)
        }

        let decoded = try JSONDecoder().decode(WebSearchResponse.self, from: data)
        let raws = decoded.web?.results ?? []
        return raws.compactMap { raw in
            guard let url = URL(string: raw.url) else { return nil }
            return Result(
                title: raw.title.strippedHTML,
                url: url,
                description: (raw.description ?? "").strippedHTML
            )
        }
    }

    // MARK: - Wire types

    private struct WebSearchResponse: Decodable {
        let web: WebSection?
        struct WebSection: Decodable {
            let results: [RawResult]
        }
        struct RawResult: Decodable {
            let title: String
            let url: String
            let description: String?
        }
    }
}

enum BraveError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case httpError(status: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Brave API key is missing. Paste it into Sabi/Sabi/Secrets.swift."
        case .invalidResponse:
            return "Brave returned a non-HTTP response."
        case .httpError(let status, let body):
            return "Brave API error \(status): \(body)"
        }
    }
}

// MARK: - Helpers

private extension String {
    /// Brave results include `<strong>` tags around matched query terms.
    /// Strip a basic set so we don't render raw HTML in SwiftUI.
    var strippedHTML: String {
        replacingOccurrences(of: "<strong>", with: "")
            .replacingOccurrences(of: "</strong>", with: "")
            .replacingOccurrences(of: "<b>", with: "")
            .replacingOccurrences(of: "</b>", with: "")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}
