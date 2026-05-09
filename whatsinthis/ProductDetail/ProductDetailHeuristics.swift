//
//  ProductDetailHeuristics.swift
//  whatsinthis
//
//  Created by Codex on 01/05/2026.
//

import Foundation

enum ProductMarketCategory {
    case jam
    case dryStaple
    case yogurtOrDairy
    case cereal
    case sweetDrink
    case biscuitsOrSweets
    case sauceOrCondiment
    case readyMeal
    case beauty
    case unknown
}

enum ProductRecommendationFamily: Hashable {
    case jam
    case cocoaSpread
    case yogurt
    case biscuit
    case cereal
    case soda
    case dryStaple
    case unknown
}

enum ProductDetailFormatting {
    static func normalized(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    static func matchesAny(of candidates: [String], in text: String) -> Bool {
        candidates.contains(where: text.contains)
    }

    static func formattedValue(_ value: Double, unit: String, decimals: Int = 1) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = decimals == 0 ? 0 : (value.rounded() == value ? 0 : 1)
        formatter.maximumFractionDigits = decimals
        let number = formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(decimals)f", value)
        return "\(number)\(unit)"
    }
}
