//
//  CategoryInsightProviderTests.swift
//  whatsinthisTests
//
//  Created by Codex on 02/05/2026.
//

import Foundation
import Testing
@testable import whatsinthis

struct CategoryInsightProviderTests {
    @Test
    func jamInsightsAreDecisionFocused() {
        let context = makeContext(for: ProductDetailFixtures.analyzedJam())

        let header = CategoryInsightProvider.headerStatus(for: context)
        let takeaways = CategoryInsightProvider.takeaways(for: context).map(\.text)
        let compare = CategoryInsightProvider.comparisonItems(for: context).map(\.text)
        let positives = CategoryInsightProvider.positiveNutritionInsights(for: context)

        #expect(header.title == "High sugar, typical for jam.")
        #expect(header.subtitle == "Compare sugar and fruit content if choosing between jars.")
        #expect(takeaways.contains("59g sugar / 100g"))
        #expect(takeaways.contains("Contains fruit pectin"))
        #expect(compare == ["Sugar", "Fruit %", "Additives"])
        #expect(positives.isEmpty)
    }

    @Test
    func flourInsightsFocusOnGlutenAndFiber() {
        let context = makeContext(for: ProductDetailFixtures.analyzedFlour())

        let header = CategoryInsightProvider.headerStatus(for: context)
        let takeaways = CategoryInsightProvider.takeaways(for: context).map(\.text)
        let compare = CategoryInsightProvider.comparisonItems(for: context).map(\.text)

        #expect(header.title == "Contains wheat / gluten")
        #expect(takeaways.contains("Check if avoiding gluten"))
        #expect(takeaways.contains("Good fiber"))
        #expect(compare == ["Fiber", "Wholegrain", "Gluten"])
    }

    @Test
    func yogurtInsightsFocusOnSugarProteinAndFat() {
        let context = makeContext(for: ProductDetailFixtures.analyzedYogurt())

        let header = CategoryInsightProvider.headerStatus(for: context)
        let takeaways = CategoryInsightProvider.takeaways(for: context).map(\.text)
        let compare = CategoryInsightProvider.comparisonItems(for: context).map(\.text)

        #expect(header.title == "Contains milk")
        #expect(takeaways.contains("Check sugar"))
        #expect(takeaways.contains("Some sat. fat to notice"))
        #expect(compare == ["Sugar", "Protein", "Fat"])
    }

    @Test
    func ocrInsightsStayCalmAndTransparent() {
        let context = makeContext(for: ProductDetailFixtures.analyzedOCRFood())
        let header = CategoryInsightProvider.headerStatus(for: context)
        let takeaways = CategoryInsightProvider.takeaways(for: context).map(\.text)

        #expect(header.title == "Label explained")
        #expect(header.subtitle == "Review ingredient text if something looks wrong.")
        #expect(takeaways.contains("Review label text if something looks wrong"))
    }

    @Test
    func beautyInsightsHighlightSensitiveSkinMarkers() {
        let context = makeContext(for: ProductDetailFixtures.analyzedBeauty())

        let header = CategoryInsightProvider.headerStatus(for: context)
        let takeaways = CategoryInsightProvider.takeaways(for: context).map(\.text)
        let compare = CategoryInsightProvider.comparisonItems(for: context).map(\.text)

        #expect(header.title == "Check sensitive-skin markers")
        #expect(takeaways.contains("Fragrance ingredients found"))
        #expect(compare == ["Fragrance", "Alcohol", "Preservatives"])
    }

    @Test
    func lowSugarDrinkDoesNotUseHighSugarHeader() {
        let context = CategoryInsightProvider.Context(
            marketCategory: .sweetDrink,
            leadingAllergenText: nil,
            unknownCount: 0,
            cautionCount: 0,
            additiveCount: 0,
            ingredientCount: 1,
            hasFruitPectin: false,
            hasSweetenerIngredient: false,
            isWholegrain: false,
            isOCRBacked: false,
            beautyFragranceCount: 0,
            beautyPreservativeCount: 0,
            beautySurfactantCount: 0,
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
            )
        )

        let header = CategoryInsightProvider.headerStatus(for: context)
        #expect(header.title == "Drink to compare.")
        #expect(header.subtitle == "Compare sugar per 100 ml and sweeteners.")
    }

    private func makeContext(for analyzedProduct: AnalyzedProduct) -> CategoryInsightProvider.Context {
        let ingredients = analyzedProduct.ingredients
        let product = analyzedProduct.product
        let marketCategory = ProductCategoryResolver.marketCategory(for: product)

        return CategoryInsightProvider.Context(
            marketCategory: marketCategory,
            leadingAllergenText: leadingAllergenStatusText(for: analyzedProduct),
            unknownCount: analyzedProduct.unknownCount,
            cautionCount: analyzedProduct.cautionCount,
            additiveCount: ingredients.flatMap(\.flags).filter { $0.kind == .additive }.count,
            ingredientCount: ingredients.count,
            hasFruitPectin: ingredients.contains { token in
                let text = token.normalizedText
                return text.contains("pectine") || text.contains("pectin")
            },
            hasSweetenerIngredient: ingredients.contains { token in
                let text = token.normalizedText
                return text.contains("sweetener")
                    || text.contains("sucralose")
                    || text.contains("aspartame")
                    || text.contains("acesulfame")
                    || text.contains("stevia")
            },
            isWholegrain: ProductDetailFormatting.matchesAny(
                of: ["wholegrain", "whole grain", "wholemeal", "complet", "complete"],
                in: ProductDetailFormatting.normalized(
                    ([product.name] + ingredients.map(\.normalizedText)).joined(separator: " ")
                )
            ),
            isOCRBacked: product.isOCRBacked,
            beautyFragranceCount: ingredients.flatMap(\.flags).filter { $0.kind == .fragrance }.count,
            beautyPreservativeCount: ingredients.flatMap(\.flags).filter { $0.kind == .preservative }.count,
            beautySurfactantCount: ingredients.flatMap(\.flags).filter { $0.kind == .surfactant }.count,
            nutrition: product.nutrition
        )
    }

    private func leadingAllergenStatusText(for analyzedProduct: AnalyzedProduct) -> String? {
        let mentions = linkedAllergenMentions(for: analyzedProduct)
        guard !mentions.isEmpty else { return nil }
        if mentions.count == 1 {
            return "Contains \(mentions[0])"
        }
        return "Contains \(mentions[0]) and \(mentions[1])"
    }

    private func linkedAllergenMentions(for analyzedProduct: AnalyzedProduct) -> [String] {
        let ingredientTerms = analyzedProduct.ingredients
            .filter { $0.flags.contains(where: { $0.kind == .allergen }) }
            .map(\.normalizedText)
        let allergenTerms = analyzedProduct.product.allergens.map(ProductDetailFormatting.normalized)
        let haystack = ProductDetailFormatting.normalized(
            (ingredientTerms + allergenTerms)
                .joined(separator: " ")
        )

        var mentions: [String] = []
        if haystack.contains("wheat") || haystack.contains("gluten") {
            mentions.append("wheat / gluten")
        }
        if haystack.contains("milk") || haystack.contains("lait") {
            mentions.append("milk")
        }
        if haystack.contains("egg") || haystack.contains("oeuf") {
            mentions.append("egg")
        }
        if haystack.contains("soy") || haystack.contains("soja") {
            mentions.append("soy")
        }
        return mentions
    }
}
