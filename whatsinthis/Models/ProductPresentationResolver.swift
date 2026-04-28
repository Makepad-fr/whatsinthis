//
//  ProductPresentationResolver.swift
//  whatsinthis
//
//  Created by Codex on 28/04/2026.
//

import Foundation

enum ProductPresentationResolver {
    static func resolvedName(
        primaryName: String?,
        secondaryName: String? = nil,
        genericName: String? = nil,
        ingredientText: String,
        categoryTags: [String],
        fallback: String = "Unknown Product"
    ) -> String {
        if let primaryName = cleaned(primaryName) {
            return primaryName
        }

        if let secondaryName = cleaned(secondaryName) {
            return secondaryName
        }

        if let genericName = cleaned(genericName) {
            return genericName
        }

        if let ingredientName = singleIngredientDisplayName(from: ingredientText) {
            return ingredientName
        }

        if let categoryName = humanizedCategoryName(from: categoryTags) {
            return categoryName
        }

        return fallback
    }

    private static func singleIngredientDisplayName(from ingredientText: String) -> String? {
        let candidate = ingredientText
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard candidate.count == 1, let value = candidate.first else {
            return nil
        }

        let simplified = value.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        guard simplified.count <= 40 else {
            return nil
        }

        return sentenceCase(simplified)
    }

    private static func humanizedCategoryName(from categoryTags: [String]) -> String? {
        for tag in categoryTags {
            let rawValue = tag.split(separator: ":", maxSplits: 1).last.map(String.init) ?? tag
            let formatted = rawValue
                .replacingOccurrences(of: "-", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !formatted.isEmpty else { continue }

            if formatted == "fruits and vegetables" || formatted == "foods" {
                continue
            }

            return sentenceCase(formatted)
        }

        return nil
    }

    private static func cleaned(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func sentenceCase(_ value: String) -> String {
        guard let first = value.first else { return value }
        return first.uppercased() + value.dropFirst()
    }
}
