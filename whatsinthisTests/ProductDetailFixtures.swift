//
//  ProductDetailFixtures.swift
//  whatsinthisTests
//
//  Created by Codex on 01/05/2026.
//

import Foundation
@testable import whatsinthis

enum ProductDetailFixtures {
    static func makeAnalyzer() -> IngredientAnalyzer {
        let analyzer = IngredientAnalyzer()
        analyzer.updateGlossary([
            IngredientGlossaryItem(
                id: "fig",
                name: "Fig",
                aliases: ["figues", "figues violettes"],
                category: .food,
                summary: "Fig is a fruit used for sweetness, texture, and fruit flavor.",
                function: "It is a whole-fruit ingredient rather than an additive.",
                caution: false,
                markers: []
            ),
            IngredientGlossaryItem(
                id: "sugar",
                name: "Sugar",
                aliases: ["sucre", "sucre roux de canne"],
                category: .food,
                summary: "Sugar is a sweetener used for taste, texture, and preservation.",
                function: "It adds sweetness and can help balance acidity or support shelf life.",
                caution: false,
                markers: []
            ),
            IngredientGlossaryItem(
                id: "fruit-pectin",
                name: "Fruit Pectin",
                aliases: ["pectine de fruits", "gelifiant pectine de fruits", "gélifiant pectine de fruits"],
                category: .food,
                summary: "Fruit pectin is a gelling fiber commonly used in jams and fruit preserves.",
                function: "It helps fruit mixtures set into a spreadable texture.",
                caution: false,
                markers: []
            ),
            IngredientGlossaryItem(
                id: "concentrated-lemon-juice",
                name: "Concentrated Lemon Juice",
                aliases: ["jus de citron concentré", "jus de citrons concentré"],
                category: .food,
                summary: "Concentrated lemon juice is used for acidity and brightness.",
                function: "It can balance sweetness and help preserve flavor in fruit products.",
                caution: false,
                markers: []
            ),
            IngredientGlossaryItem(
                id: "wholegrain-wheat-flour",
                name: "Wholegrain Wheat Flour",
                aliases: ["type 150 wholemeal wheat flour", "farine de blé complète t150", "wholemeal wheat flour"],
                category: .food,
                summary: "Wholegrain wheat flour.",
                function: "Main ingredient.",
                caution: true,
                markers: [.allergen]
            ),
            IngredientGlossaryItem(
                id: "milk",
                name: "Milk",
                aliases: ["milk"],
                category: .food,
                summary: "Milk ingredient.",
                function: "Dairy base.",
                caution: true,
                markers: [.allergen]
            ),
            IngredientGlossaryItem(
                id: "strawberry",
                name: "Strawberry",
                aliases: ["strawberry", "fraise", "fraises"],
                category: .food,
                summary: "Fruit ingredient.",
                function: "Adds fruit flavor.",
                caution: false,
                markers: []
            ),
            IngredientGlossaryItem(
                id: "parfum",
                name: "Fragrance",
                aliases: ["parfum", "fragrance"],
                category: .beauty,
                summary: "Used to scent the product.",
                function: "Adds fragrance.",
                caution: true,
                markers: [.fragrance]
            ),
            IngredientGlossaryItem(
                id: "benzyl-alcohol",
                name: "Benzyl Alcohol",
                aliases: ["benzyl alcohol"],
                category: .beauty,
                summary: "Preservative and fragrance component.",
                function: "Helps preserve the formula.",
                caution: true,
                markers: [.preservative]
            ),
            IngredientGlossaryItem(
                id: "dimethicone",
                name: "Dimethicone",
                aliases: ["dimethicone"],
                category: .beauty,
                summary: "Silicone smoothing agent.",
                function: "Improves slip and feel.",
                caution: false,
                markers: []
            )
        ])
        return analyzer
    }

    static func jamProduct() -> NormalizedProduct {
        NormalizedProduct(
            id: "fixture-jam",
            barcode: "111",
            name: "Confiture de figues violettes",
            brand: "Bonne Maman",
            imageURL: nil,
            ingredientText: "Figues violettes, sucre, sucre roux de canne, jus de citron concentré, gélifiant : pectine de fruits",
            ingredientTags: [],
            categoryTags: ["en:jams"],
            additives: [],
            allergens: [],
            category: .food,
            source: .openFoodFacts,
            nutrition: NutritionSnapshot(
                energyKcalPer100g: 242,
                sugarsPer100g: 59,
                saturatedFatPer100g: 0,
                fiberPer100g: 1.3,
                proteinPer100g: 0.5,
                saltPer100g: 0,
                nutritionGrade: nil,
                novaGroup: nil,
                ecoScoreGrade: nil
            ),
            ingredientsProvenance: .api,
            capturedAt: .now
        )
    }

    static func flourProduct() -> NormalizedProduct {
        NormalizedProduct(
            id: "fixture-flour",
            barcode: "222",
            name: "Farine de blé complète T150",
            brand: "Francine",
            imageURL: nil,
            ingredientText: "Type 150 wholemeal wheat flour",
            ingredientTags: [],
            categoryTags: ["en:flours"],
            additives: [],
            allergens: ["en:gluten"],
            category: .food,
            source: .openFoodFacts,
            nutrition: NutritionSnapshot(
                energyKcalPer100g: 337,
                sugarsPer100g: 1.4,
                saturatedFatPer100g: 0.4,
                fiberPer100g: 11,
                proteinPer100g: 12,
                saltPer100g: 0.01,
                nutritionGrade: nil,
                novaGroup: nil,
                ecoScoreGrade: nil
            ),
            ingredientsProvenance: .api,
            capturedAt: .now
        )
    }

    static func yogurtProduct() -> NormalizedProduct {
        NormalizedProduct(
            id: "fixture-yogurt",
            barcode: "333",
            name: "Strawberry Yogurt",
            brand: "Demo",
            imageURL: nil,
            ingredientText: "Milk, Strawberry, Sugar",
            ingredientTags: [],
            categoryTags: ["en:yogurts"],
            additives: [],
            allergens: ["en:milk"],
            category: .food,
            source: .openFoodFacts,
            nutrition: NutritionSnapshot(
                energyKcalPer100g: 98,
                sugarsPer100g: 12,
                saturatedFatPer100g: 2.1,
                fiberPer100g: 0.5,
                proteinPer100g: 4.8,
                saltPer100g: 0.1,
                nutritionGrade: nil,
                novaGroup: nil,
                ecoScoreGrade: nil
            ),
            ingredientsProvenance: .api,
            capturedAt: .now
        )
    }

    static func ocrFoodProduct() -> NormalizedProduct {
        NormalizedProduct(
            id: "fixture-ocr",
            barcode: nil,
            name: "Scanned Ingredient Label",
            brand: nil,
            imageURL: nil,
            ingredientText: "Figues violettes, sucre",
            ingredientTags: [],
            categoryTags: [],
            additives: [],
            allergens: [],
            category: .food,
            source: .ocr,
            nutrition: nil,
            ocrConfidence: 0.71,
            ingredientsProvenance: .ocr,
            capturedAt: .now
        )
    }

    static func beautyProduct() -> NormalizedProduct {
        NormalizedProduct(
            id: "fixture-beauty",
            barcode: "444",
            name: "Gentle Face Cream",
            brand: "Demo Beauty",
            imageURL: nil,
            ingredientText: "Aqua, Glycerin, Parfum, Benzyl Alcohol, Dimethicone",
            ingredientTags: [],
            categoryTags: ["en:face-creams"],
            additives: [],
            allergens: [],
            category: .beauty,
            source: .openBeautyFacts,
            ingredientsProvenance: .api,
            capturedAt: .now
        )
    }

    static func analyzedJam(analyzer: IngredientAnalyzer? = nil) -> AnalyzedProduct {
        let analyzer = analyzer ?? makeAnalyzer()
        return analyzer.analyze(product: jamProduct())
    }

    static func analyzedFlour(analyzer: IngredientAnalyzer? = nil) -> AnalyzedProduct {
        let analyzer = analyzer ?? makeAnalyzer()
        return analyzer.analyze(product: flourProduct())
    }

    static func analyzedYogurt(analyzer: IngredientAnalyzer? = nil) -> AnalyzedProduct {
        let analyzer = analyzer ?? makeAnalyzer()
        return analyzer.analyze(product: yogurtProduct())
    }

    static func analyzedOCRFood(analyzer: IngredientAnalyzer? = nil) -> AnalyzedProduct {
        let analyzer = analyzer ?? makeAnalyzer()
        return analyzer.analyze(product: ocrFoodProduct())
    }

    static func analyzedBeauty(analyzer: IngredientAnalyzer? = nil) -> AnalyzedProduct {
        let analyzer = analyzer ?? makeAnalyzer()
        return analyzer.analyze(product: beautyProduct())
    }
}
