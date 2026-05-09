//
//  ProductHeuristicTests.swift
//  whatsinthisTests
//
//  Created by Codex on 01/05/2026.
//

import Testing
@testable import whatsinthis

@MainActor
struct ProductHeuristicTests {
    @Test
    func categoryResolverRecognizesJamFlourYogurtBeauty() {
        #expect(ProductCategoryResolver.marketCategory(for: ProductDetailFixtures.jamProduct()) == .jam)
        #expect(ProductCategoryResolver.marketCategory(for: ProductDetailFixtures.flourProduct()) == .dryStaple)
        #expect(ProductCategoryResolver.marketCategory(for: ProductDetailFixtures.yogurtProduct()) == .yogurtOrDairy)
        #expect(ProductCategoryResolver.marketCategory(for: ProductDetailFixtures.beautyProduct()) == .beauty)
    }

    @Test
    func categoryResolverReturnsExpectedComparisonCriteria() {
        #expect(ProductCategoryResolver.comparisonCriteria(for: .jam) == ["Sugar", "Fruit %", "Additives"])
        #expect(ProductCategoryResolver.comparisonCriteria(for: .dryStaple) == ["Fiber", "Wholegrain", "Gluten"])
        #expect(ProductCategoryResolver.comparisonCriteria(for: .beauty) == ["Fragrance", "Alcohol", "Preservatives"])
    }

    @Test
    func categoryResolverDoesNotTreatPlainWaterAsSweetDrink() {
        let water = NormalizedProduct(
            id: "water",
            barcode: "777",
            name: "Natural Mineral Water",
            brand: "Demo",
            imageURL: nil,
            ingredientText: "Natural mineral water",
            ingredientTags: [],
            categoryTags: ["en:waters", "en:mineral-waters"],
            additives: [],
            allergens: [],
            category: .food,
            source: .openFoodFacts,
            nutrition: NutritionSnapshot(
                energyKcalPer100g: 0,
                sugarsPer100g: 0,
                saturatedFatPer100g: 0,
                fiberPer100g: 0,
                proteinPer100g: 0,
                saltPer100g: 0,
                nutritionGrade: nil,
                novaGroup: nil,
                ecoScoreGrade: nil
            ),
            ingredientsProvenance: .api,
            capturedAt: .now
        )

        #expect(ProductCategoryResolver.marketCategory(for: water) == .unknown)
    }

    @Test
    func recommendationPlannerRecognizesFamilies() {
        #expect(ProductRecommendationPlanner.family(for: ProductDetailFixtures.jamProduct()) == .jam)
        #expect(ProductRecommendationPlanner.family(for: ProductDetailFixtures.flourProduct()) == .dryStaple)

        let cocoaSpread = NormalizedProduct(
            id: "spread",
            barcode: "555",
            name: "Hazelnut Cocoa Spread",
            brand: "Demo",
            imageURL: nil,
            ingredientText: "Sugar, Hazelnuts, Cocoa",
            ingredientTags: [],
            categoryTags: ["en:cocoa-and-hazelnuts-spreads"],
            additives: [],
            allergens: ["en:hazelnuts"],
            category: .food,
            source: .openFoodFacts,
            ingredientsProvenance: .api,
            capturedAt: .now
        )

        #expect(ProductRecommendationPlanner.family(for: cocoaSpread) == .cocoaSpread)
    }

    @Test
    func recommendationPlannerPrefersSubtypeMatches() {
        let currentSubtypes = ProductRecommendationPlanner.subtypeKeywords(for: ProductDetailFixtures.jamProduct())
        #expect(currentSubtypes.contains("fig"))

        let strawberryJam = NormalizedProduct(
            id: "strawberry-jam",
            barcode: "666",
            name: "Confiture de fraises",
            brand: "Demo",
            imageURL: nil,
            ingredientText: "Fraises, sucre",
            ingredientTags: [],
            categoryTags: ["en:jams"],
            additives: [],
            allergens: [],
            category: .food,
            source: .openFoodFacts,
            ingredientsProvenance: .api,
            capturedAt: .now
        )

        #expect(ProductRecommendationPlanner.subtypeOverlap(currentSubtypes: currentSubtypes, candidate: strawberryJam) == 0)
        #expect(ProductRecommendationPlanner.subtypeOverlap(currentSubtypes: currentSubtypes, candidate: ProductDetailFixtures.jamProduct()) > 0)
    }

    @Test
    func recommendationPlannerFiltersGenericCategoryLabels() {
        let labels = ProductRecommendationPlanner.specificCategoryLabels(for: ProductDetailFixtures.jamProduct())
        #expect(labels.contains("jams"))
        #expect(!labels.contains("plant based spreads"))
        #expect(ProductRecommendationPlanner.isGenericLocalRecommendationCategoryLabel("fruit and vegetable preserves"))
    }
}
