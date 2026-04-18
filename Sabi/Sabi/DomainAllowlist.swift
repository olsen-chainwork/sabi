//
//  DomainAllowlist.swift
//  Sabi
//
//  Hardcoded v1 list of "high-signal" hostname suffixes. A URL passes if its
//  host exactly matches an entry, or is a subdomain of one (e.g. `blog.openai.com`
//  passes because its host ends in `.openai.com`).
//
//  Slice 7 may promote this to an editable user preference. For the hackathon
//  demo we want tight curation — no news sites, no listicles, no SEO farms.
//

import Foundation

nonisolated enum DomainAllowlist {
    /// Hostname suffixes. Lowercase, no scheme, no leading dot.
    /// Expand as we dogfood and find good sources we missed.
    static let suffixes: [String] = [
        // AI/ML research
        "arxiv.org",
        "distill.pub",
        "thegradient.pub",

        // Model labs — official blogs and docs
        "anthropic.com",
        "docs.claude.com",
        "openai.com",
        "platform.openai.com",
        "deepmind.google",
        "ai.google.dev",
        "ai.meta.com",
        "cohere.com",
        "mistral.ai",
        "together.ai",
        "huggingface.co",

        // AI/ML practitioner blogs
        "humanlayer.dev",
        "simonwillison.net",
        "eugeneyan.com",
        "lilianweng.github.io",
        "jalammar.github.io",
        "interconnects.ai",
        "karpathy.ai",
        "huyenchip.com",
        "sebastianraschka.com",

        // AI alignment & rationalist community
        "lesswrong.com",
        "alignmentforum.org",

        // Indie systems & engineering blogs
        "danluu.com",
        "jvns.ca",

        // Interviews & meta-science
        "dwarkeshpatel.com",
        "applieddivinitystudies.com",

        // Policy & applied economics (opinion-forward)
        "noahpinion.blog",
        "slowboring.com",

        // Finance meets tech
        "thediff.co",
        "kalzumeus.com",

        // Theory & complexity
        "scottaaronson.blog",

        // Startup/SaaS strategy + essays
        "stratechery.com",
        "paulgraham.com",
        "ycombinator.com",
        "firstround.com",
        "a16z.com",
        "nfx.com",
        "sequoiacap.com",
        "bvp.com",
        "tomtunguz.com",

        // Product + growth
        "reforge.com",
        "lennysnewsletter.com",
        "svpg.com",
        "37signals.com",

        // Code + projects
        "github.com",

        // Science & research — beyond AI/ML. Curated for curious readers.
        "nature.com",
        "science.org",
        "quantamagazine.org",
        "aeon.co",

        // Economics & applied social science
        "marginalrevolution.com",
        "worksinprogress.co",
        "construction-physics.com",
        "astralcodexten.com",
        "nber.org",
        "voxeu.org",
        "econlib.org",

        // Long-form essays & criticism
        "lrb.co.uk",
        "nybooks.com",
        "theatlantic.com",

        // Deep tech, math, philosophy
        "gwern.net",
        "plato.stanford.edu",
        "spectrum.ieee.org",
    ]

    /// True if the URL's host matches, or is a subdomain of, any allowed suffix.
    static func isAllowed(url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return suffixes.contains { suffix in
            host == suffix || host.hasSuffix("." + suffix)
        }
    }
}
