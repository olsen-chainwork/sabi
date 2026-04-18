# Sabi — Research Report

*CRISPE Phase 2 output. Facts only. Produced April 17, 2026 by delegated research agent. No design decisions made here — raw landscape for use in Design Doc completion.*

---

## 1. Menu-bar AI apps on macOS

**Raycast** — Command launcher and extension platform. Hybrid model: main search palette + menu bar commands. Menu bar items are on-demand, not persistent processes. Output via popover, submenu, clipboard, or action chains.
→ [Raycast API docs](https://developers.raycast.com/api-reference/menu-bar-commands)

**Superhuman** — Email client with keyboard-first design. Recently launched native macOS app (not primarily menu-bar). Output: traditional app window with fast keyboard shortcuts throughout.
→ [Superhuman for macOS](https://new.superhuman.com/superhuman-for-macos-53765)

**Arc / Arc Max** — Browser with optional AI plug-ins. Arc Max adds AI capabilities; not primarily a menu-bar app. Output: integrated within browser UI.
→ [Arc release notes](https://resources.arc.net/hc/en-us/articles/20498377604887-Arc-for-macOS-2023-Release-Notes)

**Google Gemini Mac** (2026 launch) — AI assistant with native Swift prototype. Menu-bar access available. Output: conversational interface, requires macOS 15 Sequoia+.
→ [9to5Mac coverage](https://9to5mac.com/2026/04/15/google-launches-gemini-mac-app-heres-what-it-offers/)

**Multi-AI aggregators** (Apple AI, GroAsk, ClaudeBar, etc.) — Lightweight menu-bar utilities that surface multiple LLM options in one keystroke. Output: popover or inline text response, minimal latency.
→ [MacMenuBar directory](https://macmenubar.com/ai-apps/) / [AppleAI on GitHub](https://github.com/bunnysayzz/AppleAI)

**Pattern observed:** Menu-bar AI apps split into on-demand launchers (Raycast) vs. persistent mini-interfaces (aggregators). None deliver feeds or subscriptions; most output text or actionable links to a menu-bar popover.

---

## 2. Personal content-discovery / smart reader products

**Readwise Reader** — Read-later app with highlighting, export, and an AI companion (Ghostreader). Delivery: email digest weekly or pull-based within app. AI role: document-level comprehension (define terms, simplify, summarize, Q&A on saved content). **No autonomous discovery.**
→ [Readwise](https://readwise.io/)

**Feedly** — RSS reader + news aggregator. Feedly AI (Leo) filters and prioritizes feeds before you read them. Delivery: feed view. AI role: pre-read filtering, headline-level summarization. **No autonomous discovery.**
→ [Feedly](https://feedly.com/)

**Refind** — Curated discovery service. Delivers 5 hand-selected articles daily to your interests. Output: email digest or in-app discovery feed. AI role: ranking/filtering to reduce noise. Integrates with Readwise for export. **Closest in spirit to Sabi** but delivered as email digest, not push, and sources are curated not agentically fetched.
→ [Refind](https://refind.com/)

**MyMind** — Private note-taking + visual bookmarking. AI auto-organizes clips and suggests backlinks. **No feed;** content is user-saved.
→ [MyMind](https://mymind.com/)

**Matter** — Read-it-later app specialized in newsletters and Twitter/X threads. Unified reading queue. AI curation around newsletters/social. **No autonomous discovery.**
→ [Matter on App Store](https://apps.apple.com/us/app/matter-reading-app/id1501592184)

**Pattern observed:** Existing smart readers solve "too much content" by filtering existing feeds or curating newsletters. **None autonomously fetch links to new content the user hasn't found.** Discovery is passive (aggregation) or social (newsletter curation), not agentic (search then rank).

---

## 3. Agentic web search APIs

| API | Returns | Pricing | Notes |
|-----|---------|---------|-------|
| **Exa** | Semantic (embedding-based) search with optional summaries, full-text extraction, highlights. Exa Fast: <350ms P50. Exa Deep: 3.5s P50 (agentic re-search). | Bundled content extraction since Mar 2026. Custom enterprise pricing. | Filters: 1,200+ domain constraints. Exa 2.0 (2026) ships MCP server for Claude Desktop / VS Code. |
| **Tavily** | Raw URLs, snippets, ranked results. Acquired by Nebius Feb 2026. | Pre-acquisition pricing presumed unchanged. | Popular for basic search. Quality lags Exa on semantic similarity. |
| **Perplexity Sonar API** | LLM-generated answer grounded in live web data with inline citations. | $3 entry; $200–$400/mo typical. No free tier. | Highest quality in benchmarks. **Returns prose summaries, not raw links.** |
| **OpenAI Web Search (Responses API)** | Integration via `web_search` tool. Fast non-reasoning mode (lookup) + agentic mode with reasoning models. | Pay-per-token (pricing not fully public). | New in 2026. Snapshot + evergreen versions. |
| **Brave Search API** | Ranked SERP results, metadata, snippets. Independent index. | $3–$5 per 1k queries. Free tier: 2k queries/month. | Most affordable at scale. |
| **Google Search API** | Programmatic Search Engine: rigid templates. Gemini search grounding: $35/1k queries. | — | PSE not suitable for open-web AI discovery. |
| **Bing Search API** | SERP results. **DEPRECATED: retired Aug 2025.** | — | Not a viable option in 2026. |

**Benchmark (LangSmith, Apr 2026):** Perplexity (highest quality), Exa (close second), Gemini, Tavily. 8 recent-event questions, graded by GPT-4o.

**Dev ergonomics:** Exa dominates for semantic ("find docs like X") + agentic workflows. Perplexity best for grounded answers but prose, not link-first. Brave cheapest at scale. OpenAI Responses API newest, integrates cleanly with OpenAI-stack projects.

---

## 4. Mac menu-bar app tech stack

| Criterion | Swift/SwiftUI | Electron | Tauri |
|-----------|---------------|----------|-------|
| Binary size | 10–20 MB | 80–200 MB | 2–10 MB |
| Idle memory | 30–50 MB | 200–300 MB | 30–40 MB |
| Launch time | <500ms | 1–2s | <500ms |
| Menu-bar dev friction | Lowest (MenuBarExtra scene) | Medium (darkModeSupport gotcha) | Medium (Rust learning curve) |
| Notarization | Standard CLI, Apple Dev cert ($99/yr) | electron-builder automates | tauri-cli automates (can hang >1hr) |
| Community | Apple-native, smaller | Largest (web devs) | Growing |

**Sources:** [Apple SwiftUI docs](https://developer.apple.com/documentation/SwiftUI/Building-and-customizing-the-menu-bar-with-SwiftUI) • [Tauri v2 macOS signing](https://v2.tauri.app/distribute/sign/macos/) • [Electron 2026 distribution guide](https://dev.to/raxxostudios/how-to-build-and-distribute-an-electron-desktop-app-in-2026-24nk) • [Tauri vs Electron 2026](https://www.pkgpulse.com/blog/best-desktop-app-frameworks-2026)

---

## Constraints / caveats

- Tauri notarization is known to hang (>1hr in some reports).
- OpenAI Responses API pricing not fully public (pay-per-token).
- Google PSE not viable for open-web discovery.
- Exa simplified pricing March 2026; Nebius acquired Tavily Feb 2026; OpenAI web search is new in 2026.
- Apple Developer Program membership ($99/yr) required for all distribution paths outside the App Store.
