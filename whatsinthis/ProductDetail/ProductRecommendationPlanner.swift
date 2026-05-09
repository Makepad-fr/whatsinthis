//
//  ProductRecommendationPlanner.swift
//  whatsinthis
//
//  Created by Codex on 01/05/2026.
//

import Foundation

struct ProductRecommendationPlanner {
    static func family(for product: NormalizedProduct) -> ProductRecommendationFamily {
        let contextText = ProductDetailFormatting.normalized(
            ([product.name] + product.categoryTags + [product.ingredientText])
                .joined(separator: " ")
        )

        if ProductDetailFormatting.matchesAny(of: ["confiture", "jam", "jams", "marmalade", "jelly", "preserve", "preserves", "fruit spread"], in: contextText) {
            return .jam
        }

        if ProductDetailFormatting.matchesAny(of: ["hazelnut spread", "chocolate spread", "cocoa and hazelnut", "pate a tartiner", "pâte à tartiner", "sweet spread"], in: contextText) {
            return .cocoaSpread
        }

        if ProductDetailFormatting.matchesAny(of: ["yogurt", "yoghurt", "yaourt"], in: contextText) {
            return .yogurt
        }

        if ProductDetailFormatting.matchesAny(of: ["biscuit", "biscuits", "cookie", "cookies", "cracker"], in: contextText) {
            return .biscuit
        }

        if ProductDetailFormatting.matchesAny(of: ["cereal", "cereals", "granola", "muesli"], in: contextText) {
            return .cereal
        }

        if ProductDetailFormatting.matchesAny(of: ["soda", "cola", "soft drink", "soft drinks", "beverage", "boisson"], in: contextText) {
            return .soda
        }

        if ProductCategoryResolver.marketCategory(for: product) == .dryStaple {
            return .dryStaple
        }

        return .unknown
    }

    static func familyLabel(for family: ProductRecommendationFamily) -> String {
        switch family {
        case .jam:
            return "jam or preserve"
        case .cocoaSpread:
            return "cocoa or hazelnut spread"
        case .yogurt:
            return "yogurt"
        case .biscuit:
            return "biscuit or cookie"
        case .cereal:
            return "cereal"
        case .soda:
            return "soft drink"
        case .dryStaple:
            return "dry staple"
        case .unknown:
            return "similar"
        }
    }

    static func subtypeKeywords(for product: NormalizedProduct, family: ProductRecommendationFamily? = nil) -> Set<String> {
        let resolvedFamily = family ?? self.family(for: product)
        guard resolvedFamily != .unknown else { return [] }

        let context = ProductDetailFormatting.normalized(
            ([product.name] + product.categoryTags + [product.ingredientText])
                .joined(separator: " ")
        )

        switch resolvedFamily {
        case .jam:
            return matchedSubtypeKeywords(in: context, groups: [
                ("strawberry", ["strawberry", "fraise", "fraises"]),
                ("fig", ["fig", "figue", "figues"]),
                ("apricot", ["apricot", "abricot", "abricots"]),
                ("raspberry", ["raspberry", "framboise", "framboises"]),
                ("blueberry", ["blueberry", "myrtille", "myrtilles"]),
                ("orange", ["orange", "oranges"]),
                ("peach", ["peach", "peche", "peches"]),
                ("cherry", ["cherry", "cerise", "cerises"]),
                ("blackberry", ["blackberry", "mure", "mures"]),
                ("mixed-berries", ["fruits rouges", "red fruits", "mixed berries"])
            ])
        case .cocoaSpread:
            return matchedSubtypeKeywords(in: context, groups: [
                ("hazelnut", ["hazelnut", "hazelnuts", "noisette", "noisettes"]),
                ("peanut", ["peanut", "peanuts", "cacahuete", "cacahuetes"]),
                ("almond", ["almond", "almonds", "amande", "amandes"]),
                ("cocoa", ["cocoa", "cacao", "chocolate", "chocolat"])
            ])
        case .yogurt:
            return matchedSubtypeKeywords(in: context, groups: [
                ("plain", ["plain", "nature", "natural"]),
                ("vanilla", ["vanilla", "vanille"]),
                ("strawberry", ["strawberry", "fraise", "fraises"]),
                ("blueberry", ["blueberry", "myrtille", "myrtilles"]),
                ("raspberry", ["raspberry", "framboise", "framboises"])
            ])
        case .biscuit:
            return matchedSubtypeKeywords(in: context, groups: [
                ("chocolate", ["chocolate", "chocolat", "cocoa", "cacao"]),
                ("butter", ["butter", "beurre"]),
                ("oat", ["oat", "oats", "avoine"]),
                ("vanilla", ["vanilla", "vanille"])
            ])
        case .cereal:
            return matchedSubtypeKeywords(in: context, groups: [
                ("chocolate", ["chocolate", "chocolat", "cocoa", "cacao"]),
                ("honey", ["honey", "miel"]),
                ("fruit", ["fruit", "fruits"]),
                ("oat", ["oat", "oats", "avoine"])
            ])
        case .soda:
            return matchedSubtypeKeywords(in: context, groups: [
                ("cola", ["cola"]),
                ("orange", ["orange"]),
                ("lemon", ["lemon", "citron"]),
                ("energy", ["energy", "energisant"])
            ])
        case .dryStaple:
            return matchedSubtypeKeywords(in: context, groups: [
                ("wheat", ["wheat", "ble", "blé"]),
                ("oat", ["oat", "oats", "avoine"]),
                ("rice", ["rice", "riz"]),
                ("corn", ["corn", "mais", "maïs"]),
                ("lentil", ["lentil", "lentils", "lentille", "lentilles"])
            ])
        case .unknown:
            return []
        }
    }

    static func specificCategoryLabels(for product: NormalizedProduct) -> [String] {
        product.categoryTags
            .compactMap { tag in
                let rawValue = tag.split(separator: ":").last.map(String.init) ?? tag
                let humanized = rawValue.replacingOccurrences(of: "-", with: " ")
                let normalizedValue = ProductDetailFormatting.normalized(humanized)
                return normalizedValue.isEmpty ? nil : normalizedValue
            }
            .filter { !isGenericLocalRecommendationCategoryLabel($0) }
    }

    static func isGenericLocalRecommendationCategoryLabel(_ label: String) -> Bool {
        let genericPhrases = [
            "foods",
            "foods and beverages",
            "beverages",
            "plant based foods",
            "plant based foods and beverages",
            "plant based spreads",
            "spreads",
            "sweet spreads",
            "fruit and vegetable preserves",
            "groceries"
        ]

        return genericPhrases.contains { phrase in
            label == phrase || label.hasPrefix("\(phrase) ")
        }
    }

    static func subtypeOverlap(currentSubtypes: Set<String>, candidate: NormalizedProduct) -> Int {
        guard !currentSubtypes.isEmpty else { return 0 }
        return currentSubtypes.intersection(subtypeKeywords(for: candidate)).count
    }

    private static func matchedSubtypeKeywords(in context: String, groups: [(String, [String])]) -> Set<String> {
        Set(
            groups.compactMap { canonical, aliases in
                aliases.contains(where: context.contains) ? canonical : nil
            }
        )
    }
}
