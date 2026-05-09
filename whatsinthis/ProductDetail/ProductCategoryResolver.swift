//
//  ProductCategoryResolver.swift
//  whatsinthis
//
//  Created by Codex on 01/05/2026.
//

import Foundation

struct ProductCategoryResolver {
    static func marketCategory(for product: NormalizedProduct) -> ProductMarketCategory {
        if product.category == .beauty {
            return .beauty
        }

        let contextText = ProductDetailFormatting.normalized(
            ([product.name] + product.categoryTags + [product.ingredientText])
                .joined(separator: " ")
        )

        let hasWaterTerms = ProductDetailFormatting.matchesAny(
            of: ["water", "eau", "mineral water", "sparkling water", "still water", "eau minerale", "eau minérale"],
            in: contextText
        )
        let hasSugaredDrinkTerms = ProductDetailFormatting.matchesAny(
            of: [
                "soda", "cola", "soft drink", "soft-drinks", "energy drink", "energy drinks",
                "sweetened beverage", "sweetened drink", "sugary drink", "boisson sucree", "boisson sucrée",
                "juice", "fruit juice", "nectar", "lemonade", "iced tea", "ice tea", "jus", "sirop", "syrup"
            ],
            in: contextText
        )

        if hasWaterTerms && !hasSugaredDrinkTerms {
            return .unknown
        }

        if ProductDetailFormatting.matchesAny(of: ["flour", "farine", "wholemeal", "whole wheat", "semolina", "semoule", "rice", "oat", "oats", "lentil", "quinoa", "couscous", "dry pasta", "pasta", "farina"], in: contextText) {
            return .dryStaple
        }

        if ProductDetailFormatting.matchesAny(of: ["jam", "jams", "confiture", "marmalade", "jelly", "preserve", "preserves", "fruit spread", "sweet spread", "pate a tartiner"], in: contextText) {
            return .jam
        }

        if ProductDetailFormatting.matchesAny(
            of: [
                "soda", "cola", "soft drink", "soft-drinks", "energy drink", "energy drinks",
                "sweetened beverage", "sweetened drink", "sugary drink", "boisson sucree", "boisson sucrée",
                "juice", "fruit juice", "nectar", "lemonade", "iced tea", "ice tea", "jus", "sirop", "syrup"
            ],
            in: contextText
        ) {
            return .sweetDrink
        }

        if ProductDetailFormatting.matchesAny(of: ["yogurt", "yoghurt", "yaourt", "dairy", "milk", "fromage blanc"], in: contextText) {
            return .yogurtOrDairy
        }

        if ProductDetailFormatting.matchesAny(of: ["cereal", "cereals", "granola", "muesli", "breakfast cereal"], in: contextText) {
            return .cereal
        }

        if ProductDetailFormatting.matchesAny(of: ["biscuit", "biscuits", "cookie", "cookies", "chocolate", "candy", "confectionery", "sweet", "dessert"], in: contextText) {
            return .biscuitsOrSweets
        }

        if ProductDetailFormatting.matchesAny(of: ["sauce", "ketchup", "mustard", "mayo", "mayonnaise", "condiment", "vinaigrette", "dressing"], in: contextText) {
            return .sauceOrCondiment
        }

        if ProductDetailFormatting.matchesAny(of: ["ready meal", "prepared meal", "frozen meal", "pizza", "lasagna", "lasagne", "meal"], in: contextText) {
            return .readyMeal
        }

        return .unknown
    }

    static func displayName(for product: NormalizedProduct, marketCategory: ProductMarketCategory) -> String {
        switch marketCategory {
        case .jam:
            return "Jam"
        case .dryStaple:
            let text = ProductDetailFormatting.normalized(product.name)
            if ProductDetailFormatting.matchesAny(of: ["flour", "farine"], in: text) {
                return "Flour"
            }
            return "Dry staple"
        case .yogurtOrDairy:
            return "Yogurt"
        case .cereal:
            return "Cereal"
        case .sweetDrink:
            return "Drink"
        case .biscuitsOrSweets:
            return "Sweet snack"
        case .sauceOrCondiment:
            return "Sauce"
        case .readyMeal:
            return "Ready meal"
        case .beauty:
            return "Beauty"
        case .unknown:
            return product.category.displayName
        }
    }

    static func comparisonCriteria(for marketCategory: ProductMarketCategory) -> [String] {
        switch marketCategory {
        case .jam:
            return ["Sugar", "Fruit %", "Additives"]
        case .dryStaple:
            return ["Fiber", "Wholegrain", "Gluten"]
        case .yogurtOrDairy:
            return ["Sugar", "Protein", "Fat"]
        case .cereal:
            return ["Sugar", "Fiber", "Additives"]
        case .sweetDrink:
            return ["Sugar", "Sweeteners", "Additives"]
        case .biscuitsOrSweets:
            return ["Sugar", "Sat. fat", "Additives"]
        case .sauceOrCondiment:
            return ["Salt", "Sugar", "Additives"]
        case .readyMeal:
            return ["Salt", "Sat. fat", "Protein"]
        case .beauty:
            return ["Fragrance", "Alcohol", "Preservatives"]
        case .unknown:
            return ["Ingredients", "Allergens", "Additives"]
        }
    }
}
