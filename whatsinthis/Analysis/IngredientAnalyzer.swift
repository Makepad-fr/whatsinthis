//
//  IngredientAnalyzer.swift
//  whatsinthis
//
//  Created by Codex on 28/04/2026.
//

import Foundation

@MainActor
final class IngredientAnalyzer {
    private var glossaryByTerm: [String: IngredientGlossaryItem] = [:]

    private let knownAllergens = [
        "milk", "wheat", "soy", "peanut", "tree nut", "almond", "cashew", "egg", "fish", "shellfish",
        "sesame", "gluten", "mustard", "celery", "sulfites", "sulphites", "lactose"
    ]

    private let additiveKeywords = [
        "flavour", "flavor", "colour", "color", "emulsifier", "stabiliser", "stabilizer",
        "sweetener", "preservative", "thickener", "acidity regulator", "anti-caking"
    ]

    private let beautyCautionKeywords: [AnalysisMarker: [String]] = [
        .fragrance: ["fragrance", "parfum", "perfume"],
        .preservative: ["phenoxyethanol", "sodium benzoate", "potassium sorbate", "preservative"],
        .surfactant: ["sulfate", "sulphate", "cocamidopropyl betaine", "surfactant"],
        .irritant: ["denat alcohol", "alcohol denat", "menthol", "camphor"]
    ]

    func updateGlossary(_ items: [IngredientGlossaryItem]) {
        var mapped: [String: IngredientGlossaryItem] = [:]
        for item in items {
            mapped[normalized(item.name)] = item
            for alias in item.aliases {
                mapped[normalized(alias)] = item
            }
        }
        glossaryByTerm = mapped
    }

    func inferCategory(from text: String) -> ProductCategory {
        let text = normalized(text)
        let beautySignals = ["aqua", "parfum", "glycerin", "cocamidopropyl", "tocopherol", "linalool", "ci 77491"]
        let beautyMatches = beautySignals.filter { text.contains($0) }.count
        if beautyMatches >= 2 {
            return .beauty
        }
        return .food
    }

    func analyze(product: NormalizedProduct) -> AnalyzedProduct {
        let tokens = tokenize(product.ingredientText)
        let ingredientTokens = tokens.map { buildToken(from: $0, product: product, ingredientCount: tokens.count) }
        let highlightCards = buildHighlightCards(for: product, ingredients: ingredientTokens)
        let summary = buildSummary(for: product, ingredients: ingredientTokens, cards: highlightCards)
        return AnalyzedProduct(product: product, ingredients: ingredientTokens, highlightCards: highlightCards, summary: summary)
    }

    private func buildToken(from rawToken: String, product: NormalizedProduct, ingredientCount: Int) -> IngredientToken {
        let trimmed = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedToken = normalized(trimmed)
        let glossaryMatch = glossaryByTerm[normalizedToken] ?? glossaryByTerm.first(where: { normalizedToken.contains($0.key) || $0.key.contains(normalizedToken) })?.value

        var flags: [AnalysisFlag] = []
        var confidence: Double = glossaryMatch == nil ? 0.35 : 0.9

        if containsAllergen(normalizedToken, product: product) {
            flags.append(AnalysisFlag(kind: .allergen, severity: .caution, reason: "This ingredient matches a common allergen term."))
            confidence = max(confidence, 0.95)
        }

        if containsAdditive(normalizedToken, product: product) {
            flags.append(AnalysisFlag(kind: .additive, severity: .caution, reason: "This ingredient looks like an additive or processing aid."))
            confidence = max(confidence, 0.9)
        }

        if product.category == .beauty {
            for (marker, keywords) in beautyCautionKeywords where keywords.contains(where: normalizedToken.contains) {
                flags.append(AnalysisFlag(kind: marker, severity: .caution, reason: "This ingredient is commonly used in \(marker.displayName.lowercased()) contexts."))
                confidence = max(confidence, 0.85)
            }
        }

        if glossaryMatch?.caution == true, let marker = glossaryMatch?.markers.first {
            flags.append(AnalysisFlag(kind: marker, severity: .caution, reason: "This ingredient is marked for extra context in the glossary."))
        }

        if flags.isEmpty, glossaryMatch == nil, isLikelySingleWholeFoodIngredient(normalizedToken, ingredientCount: ingredientCount, product: product) {
            return IngredientToken(
                text: trimmed,
                normalizedText: normalizedToken,
                matchedTerm: nil,
                confidence: 0.55,
                explanation: IngredientExplanation(
                    summary: "\(displayText(trimmed)) looks like a straightforward food ingredient.",
                    function: "This appears to be a simple whole-food or spice ingredient rather than an additive.",
                    whyHighlighted: "No caution markers were detected, even though this term is not yet in the offline glossary.",
                    provenance: .inferred
                ),
                flags: []
            )
        }

        if flags.isEmpty, glossaryMatch == nil {
            flags.append(AnalysisFlag(kind: .unknown, severity: .unknown, reason: "This ingredient is not yet in the offline glossary."))
            confidence = 0.2
        }

        let explanation = buildExplanation(match: glossaryMatch, normalizedToken: normalizedToken, flags: flags)

        return IngredientToken(
            text: trimmed,
            normalizedText: normalizedToken,
            matchedTerm: glossaryMatch?.name,
            confidence: confidence,
            explanation: explanation,
            flags: deduplicatedFlags(flags)
        )
    }

    private func buildExplanation(
        match: IngredientGlossaryItem?,
        normalizedToken: String,
        flags: [AnalysisFlag]
    ) -> IngredientExplanation {
        if let match {
            let reason = flags.first?.reason ?? "This ingredient is recognized from the offline glossary."
            return IngredientExplanation(
                summary: match.summary,
                function: match.function,
                whyHighlighted: reason,
                provenance: .glossary
            )
        }

        if let flag = flags.first(where: { $0.kind == .allergen }) {
            return IngredientExplanation(
                summary: "This ingredient matches a common allergen term.",
                function: "Ingredient details were inferred from the label text because no glossary match was available.",
                whyHighlighted: flag.reason,
                provenance: .inferred
            )
        }

        if let flag = flags.first(where: { $0.kind == .additive }) {
            return IngredientExplanation(
                summary: "This ingredient looks like an additive or processing aid.",
                function: "Additives can affect texture, color, flavor, or shelf stability.",
                whyHighlighted: flag.reason,
                provenance: .inferred
            )
        }

        if let flag = flags.first(where: { $0.severity == .caution }) {
            return IngredientExplanation(
                summary: "This ingredient was highlighted for extra context.",
                function: "The app uses deterministic keyword rules when a glossary description is unavailable.",
                whyHighlighted: flag.reason,
                provenance: .inferred
            )
        }

        return IngredientExplanation(
            summary: "This ingredient is currently unknown to the offline glossary.",
            function: "No trusted match was available from the current label text.",
            whyHighlighted: "The term “\(normalizedToken)” needs more reference data before it can be explained confidently.",
            provenance: .inferred
        )
    }

    private func buildHighlightCards(for product: NormalizedProduct, ingredients: [IngredientToken]) -> [HighlightCard] {
        let allergenCount = ingredients.flatMap(\.flags).filter { $0.kind == .allergen }.count
        let additiveCount = ingredients.flatMap(\.flags).filter { $0.kind == .additive }.count
        let unknownCount = ingredients.flatMap(\.flags).filter { $0.kind == .unknown }.count
        let processingClues = processingClues(for: product, ingredients: ingredients)

        var cards: [HighlightCard] = []

        if allergenCount > 0 {
            cards.append(
                HighlightCard(
                    title: "Allergens",
                    detail: "Detected \(allergenCount) ingredient\(allergenCount == 1 ? "" : "s") that match common allergen terms.",
                    systemImage: "exclamationmark.triangle.fill",
                    tint: .caution
                )
            )
        }

        if additiveCount > 0 {
            cards.append(
                HighlightCard(
                    title: "Additives",
                    detail: "Found \(additiveCount) ingredient\(additiveCount == 1 ? "" : "s") that look like additives or processing aids.",
                    systemImage: "sparkles.rectangle.stack",
                    tint: .caution
                )
            )
        }

        if processingClues > 0 {
            cards.append(
                HighlightCard(
                    title: "Processing Clues",
                    detail: "The ingredient list shows \(processingClues) rule-based clue\(processingClues == 1 ? "" : "s") linked to heavier processing.",
                    systemImage: "list.bullet.clipboard",
                    tint: .neutral
                )
            )
        }

        if product.category == .beauty {
            let beautyFlags = ingredients.flatMap(\.flags).filter {
                [.fragrance, .preservative, .surfactant, .irritant].contains($0.kind)
            }

            if !beautyFlags.isEmpty {
                cards.append(
                    HighlightCard(
                        title: "Beauty Markers",
                        detail: "Highlighted \(beautyFlags.count) ingredient\(beautyFlags.count == 1 ? "" : "s") commonly associated with fragrance, preservation, cleansing, or irritation cues.",
                        systemImage: "drop.fill",
                        tint: .neutral
                    )
                )
            }
        }

        if unknownCount > 0 {
            cards.append(
                HighlightCard(
                    title: "Unknown Terms",
                    detail: "\(unknownCount) ingredient\(unknownCount == 1 ? "" : "s") could not be matched confidently and should be treated as informational gaps.",
                    systemImage: "questionmark.circle.fill",
                    tint: .neutral
                )
            )
        }

        return cards
    }

    private func buildSummary(for product: NormalizedProduct, ingredients: [IngredientToken], cards: [HighlightCard]) -> InsightSummary {
        let allergenCount = ingredients.flatMap(\.flags).filter { $0.kind == .allergen }.count
        let additiveCount = ingredients.flatMap(\.flags).filter { $0.kind == .additive }.count
        let unknownCount = ingredients.flatMap(\.flags).filter { $0.kind == .unknown }.count
        let cautionIngredients = ingredients.filter { $0.severity == .caution }
        let simpleCount = ingredients.filter { $0.severity == .safe }.count

        let headline: String
        let supportingText: String
        if product.ingredientsProvenance == .ocr && product.barcode == nil {
            headline = "Ingredient list scanned from the label."
            supportingText = "The app is explaining the ingredients from the captured label because a verified product record was not available."
        } else if allergenCount > 0 || additiveCount > 0 {
            let names = cautionIngredients.prefix(2).map(\.text).joined(separator: ", ")
            headline = "\(cautionIngredients.count) ingredient\(cautionIngredients.count == 1 ? "" : "s") deserve a closer look."
            supportingText = names.isEmpty
                ? "The product includes ingredients that need extra context before you decide how you feel about them."
                : "Start with \(names). The rest of the list may still be simple, but these are the ingredients the app would check first."
        } else if ingredients.count == 1 && unknownCount == 0 {
            headline = "Single ingredient recognized without caution markers."
            supportingText = "\(ingredients.first?.text ?? "This ingredient") looks like a straightforward food ingredient rather than an additive-heavy formula."
        } else if unknownCount > 0 {
            headline = "Mostly simple ingredients, with a few terms that need more context."
            supportingText = "\(simpleCount) ingredient\(simpleCount == 1 ? "" : "s") look straightforward. \(unknownCount) term\(unknownCount == 1 ? "" : "s") still need better reference coverage."
        } else {
            headline = "Mostly straightforward ingredients."
            supportingText = "\(simpleCount) ingredient\(simpleCount == 1 ? "" : "s") look familiar, and no strong caution markers were detected in the available data."
        }

        return InsightSummary(
            headline: headline,
            supportingText: supportingText,
            disclaimer: "Informational only, not medical advice."
        )
    }

    private func containsAllergen(_ token: String, product: NormalizedProduct) -> Bool {
        if product.allergens.contains(where: { normalized($0).contains(token) || token.contains(normalized($0)) }) {
            return true
        }

        return knownAllergens.contains(where: token.contains)
    }

    private func containsAdditive(_ token: String, product: NormalizedProduct) -> Bool {
        if product.additives.contains(where: { normalized($0).contains(token) || token.contains(normalized($0)) }) {
            return true
        }

        if token.range(of: #"^e\d{3,4}[a-z]?$"#, options: .regularExpression) != nil {
            return true
        }

        return additiveKeywords.contains(where: token.contains)
    }

    private func processingClues(for product: NormalizedProduct, ingredients: [IngredientToken]) -> Int {
        var score = 0

        if ingredients.count >= 12 {
            score += 1
        }

        if ingredients.flatMap(\.flags).contains(where: { $0.kind == .additive }) {
            score += 1
        }

        let text = normalized(product.ingredientText)
        let processingKeywords = ["concentrate", "reconstituted", "flavour", "flavor", "modified starch", "hydrolyzed"]
        if processingKeywords.contains(where: text.contains) {
            score += 1
        }

        return score
    }

    private func isLikelySingleWholeFoodIngredient(_ token: String, ingredientCount: Int, product: NormalizedProduct) -> Bool {
        guard product.category == .food, ingredientCount == 1 else {
            return false
        }

        guard !token.isEmpty, !token.contains(where: { $0.isNumber }) else {
            return false
        }

        let words = token.split(separator: " ")
        guard !words.isEmpty, words.count <= 4 else {
            return false
        }

        let disallowedKeywords = additiveKeywords + knownAllergens + ["extract", "concentrate", "aroma", "flavor", "flavour"]
        return !disallowedKeywords.contains(where: token.contains)
    }

    private func tokenize(_ text: String) -> [String] {
        let sanitized = text
            .replacingOccurrences(of: "\n", with: ", ")
            .replacingOccurrences(of: ";", with: ",")
            .replacingOccurrences(of: "•", with: ",")

        var tokens: [String] = []
        var current = ""
        var depth = 0

        for character in sanitized {
            switch character {
            case "(":
                depth += 1
                current.append(character)
            case ")":
                depth = max(0, depth - 1)
                current.append(character)
            case "," where depth == 0:
                if !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    tokens.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                current.removeAll(keepingCapacity: true)
            default:
                current.append(character)
            }
        }

        if !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            tokens.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return tokens
    }

    private func normalized(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "%", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: #"[^a-z0-9\s]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func deduplicatedFlags(_ flags: [AnalysisFlag]) -> [AnalysisFlag] {
        var seen = Set<String>()
        return flags.filter { flag in
            seen.insert(flag.id).inserted
        }
    }

    private func displayText(_ value: String) -> String {
        guard let first = value.first else { return value }
        return first.uppercased() + value.dropFirst()
    }
}
