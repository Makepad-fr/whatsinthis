//
//  ProductDetailViewModel+Ingredients.swift
//  whatsinthis
//
//  Created by Codex on 28/04/2026.
//

import Foundation

extension ProductDetailViewModel {
    var ingredientRows: [IngredientRow] {
        ingredients.enumerated().map { index, token in
            let allergens = allergenMentions(for: token)
            let whatItIs = compactWhatItIs(for: token)
            let whyItMatters = compactWhyItMatters(for: token, allergens: allergens)
            let usedFor = compactRole(for: token, position: index)

            return IngredientRow(
                id: token.id,
                token: token,
                position: index + 1,
                notice: ingredientNotice(for: token, allergens: allergens),
                compactRole: compactRoleLabel(for: token, position: index),
                whatItIs: whatItIs,
                whyItMatters: whyItMatters,
                usedFor: usedFor,
                severity: token.severity
            )
        }
    }

    var ingredientCountLabel: String {
        ingredients.count == 1 ? "1 item" : "\(ingredients.count) items"
    }

    func ingredientNotice(for token: IngredientToken, allergens: [String]) -> String? {
        guard let primaryFlag = token.primaryFlag else { return nil }

        switch primaryFlag.kind {
        case .allergen:
            if let first = allergens.first {
                return "Common allergen: \(first)"
            }
            return "Common allergen"
        case .additive:
            return "Additive found"
        case .processing:
            return "Worth noticing"
        case .fragrance:
            return "Fragrance ingredient"
        case .preservative:
            return "Preservative"
        case .surfactant:
            return "Cleansing ingredient"
        case .irritant:
            return "Irritation marker"
        case .unknown:
            return "Needs more context"
        }
    }

    func compactWhatItIs(for token: IngredientToken) -> String {
        if let heuristic = heuristicSummary(for: token.normalizedText) {
            return heuristic
        }

        let summary = token.shortSummary
        if summary.contains("looks like a straightforward food ingredient") {
            return "Straightforward food ingredient."
        }

        if summary == "This ingredient matches a common allergen term." {
            return "Ingredient containing a common allergen."
        }

        return summary
    }

    func compactRoleLabel(for token: IngredientToken, position: Int) -> String {
        let normalizedToken = token.normalizedText

        if normalizedToken.contains("pectine") || normalizedToken.contains("pectin") {
            return "gelling agent"
        }

        if ProductDetailFormatting.matchesAny(of: ["jus de citron", "lemon juice", "citric"], in: normalizedToken) {
            return "acidity"
        }

        if ProductDetailFormatting.matchesAny(of: ["sucre", "sugar", "sirop", "syrup", "miel", "honey"], in: normalizedToken) {
            return "sweetener"
        }

        if ProductDetailFormatting.matchesAny(of: ["farine", "flour"], in: normalizedToken) {
            return isWholegrainProduct ? "wholegrain flour" : "flour"
        }

        if position == 0,
           ProductDetailFormatting.matchesAny(
               of: ["fig", "figue", "fraise", "strawberry", "fruit", "framboise", "raspberry", "abricot", "apricot"],
               in: normalizedToken
           ) {
            return "fruit base"
        }

        if let function = token.explanation?.function {
            let loweredFunction = ProductDetailFormatting.normalized(function)
            if loweredFunction.contains("texture") || loweredFunction.contains("gelling") {
                return "texture"
            }
            if loweredFunction.contains("preserve") || loweredFunction.contains("shelf life") {
                return "preservation"
            }
            if loweredFunction.contains("flavor") || loweredFunction.contains("taste") {
                return "flavor"
            }
            if loweredFunction.contains("fragrance") || loweredFunction.contains("scent") {
                return "fragrance"
            }
        }

        if let usedFor = compactRole(for: token, position: position) {
            return normalizedRoleLabel(usedFor)
        }

        return position == 0 ? "main ingredient" : "ingredient"
    }

    func normalizedRoleLabel(_ value: String) -> String {
        let cleaned = value
            .replacingOccurrences(of: ".", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = cleaned.first else { return "ingredient" }
        return first.lowercased() + cleaned.dropFirst()
    }

    func compactWhyItMatters(for token: IngredientToken, allergens: [String]) -> String? {
        guard let primaryFlag = token.primaryFlag else { return nil }

        switch primaryFlag.kind {
        case .allergen:
            if let first = allergens.first {
                return "Contains \(first), a common allergen."
            }
            return "Contains a common allergen term."
        case .additive:
            return "May be used for texture, flavor, color, or shelf life."
        case .processing:
            return "The ingredient list suggests more processing."
        case .fragrance:
            return "Used to add scent to the product."
        case .preservative:
            return "Used to help preserve the formula."
        case .surfactant:
            return "Used for cleansing or foaming."
        case .irritant:
            return "May matter if you avoid common irritation triggers."
        case .unknown:
            return "The app could not match this term confidently."
        }
    }

    func compactRole(for token: IngredientToken, position: Int) -> String? {
        let function = token.supportingSummary

        if function == "Tap for more context." {
            return position == 0 ? primaryIngredientLabel : nil
        }

        if function.contains("Ingredient details were inferred from the label text")
            || function.contains("No trusted match was available")
            || function.contains("deterministic keyword rules") {
            return position == 0 ? primaryIngredientLabel : nil
        }

        if function.contains("simple whole-food or spice ingredient") {
            return position == 0 ? primaryIngredientLabel : "Simple food ingredient."
        }

        return function
    }

    var primaryIngredientLabel: String {
        ingredients.count == 1 ? "Main ingredient." : "Primary ingredient."
    }

    func heuristicSummary(for normalizedToken: String) -> String? {
        if normalizedToken.contains("wholemeal") && normalizedToken.contains("wheat") && normalizedToken.contains("flour") {
            return "Wholegrain wheat flour."
        }

        if normalizedToken.contains("wheat") && normalizedToken.contains("flour") {
            return "Wheat flour."
        }

        if normalizedToken.contains("radis") || normalizedToken.contains("radish") {
            return "Radish."
        }

        if normalizedToken.contains("poivre") || normalizedToken.contains("pepper") {
            return "Ground black pepper."
        }

        return nil
    }

    func allergenMentions(for token: IngredientToken) -> [String] {
        guard token.flags.contains(where: { $0.kind == .allergen }) else { return [] }

        let haystack = ProductDetailFormatting.normalized(
            ([token.normalizedText] + product.allergens.map(ProductDetailFormatting.normalized))
                .joined(separator: " ")
        )

        var values: [String] = []

        if haystack.contains("wheat") || haystack.contains("gluten") {
            values.append("wheat / gluten")
        }

        if ProductDetailFormatting.matchesAny(of: ["milk", "lactose", "whey"], in: haystack) {
            values.append("milk")
        }

        if haystack.contains("soy") {
            values.append("soy")
        }

        if haystack.contains("peanut") {
            values.append("peanut")
        }

        if ProductDetailFormatting.matchesAny(of: ["almond", "cashew", "hazelnut", "walnut", "tree nut"], in: haystack) {
            values.append("tree nuts")
        }

        if haystack.contains("egg") {
            values.append("egg")
        }

        if haystack.contains("sesame") {
            values.append("sesame")
        }

        if haystack.contains("mustard") {
            values.append("mustard")
        }

        if haystack.contains("celery") {
            values.append("celery")
        }

        if ProductDetailFormatting.matchesAny(of: ["sulfites", "sulphites"], in: haystack) {
            values.append("sulfites")
        }

        if values.isEmpty {
            values.append("common allergen")
        }

        return values
    }
}
