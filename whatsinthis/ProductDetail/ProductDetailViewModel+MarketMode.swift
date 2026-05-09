//
//  ProductDetailViewModel+MarketMode.swift
//  whatsinthis
//
//  Created by Codex on 28/04/2026.
//

import Foundation

extension ProductDetailViewModel {
    var headerMetadata: String {
        [product.brand, marketCategoryDisplayName]
            .compactMap { value in
                guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                return value
            }
            .joined(separator: " • ")
    }

    var headerStatus: HeaderStatus {
        headerStatus(from: CategoryInsightProvider.headerStatus(for: categoryInsightContext))
    }

    var atAGlanceItems: [Takeaway] {
        Array(
            CategoryInsightProvider.takeaways(for: categoryInsightContext)
                .prefix(4)
                .map(takeaway(from:))
        )
    }

    var summaryChips: [SummaryChip] {
        Array(
            CategoryInsightProvider.summaryChips(for: categoryInsightContext)
                .prefix(4)
                .map(summaryChip(from:))
        )
    }

    var comparisonCriteria: [ComparisonCriterion] {
        CategoryInsightProvider.comparisonItems(for: categoryInsightContext)
            .map(comparisonCriterion(from:))
    }

    var canLoadSwapRecommendations: Bool {
        product.category == .food
            && !product.isOCRBacked
            && nutrition?.hasAnyValue == true
            && productBackend != nil
            && ingredientAnalyzer != nil
    }

    var showsSwapSection: Bool {
        canLoadSwapRecommendations && (isLoadingSwapRecommendations || hasLoadedSwapRecommendations)
    }

    var swapSectionEmptyMessage: String? {
        guard showsSwapSection, !isLoadingSwapRecommendations, swapRecommendations.isEmpty else { return nil }
        return swapSectionStatusMessage ?? "No clearly better or comparable product was found in current database matches."
    }

    var nutritionMetrics: [NutritionMetric] {
        CategoryInsightProvider.nutritionMetrics(for: categoryInsightContext)
            .map(nutritionMetric(from:))
    }

    var negativeNutritionInsights: [NutritionInsight] {
        CategoryInsightProvider.negativeNutritionInsights(for: categoryInsightContext)
            .map(nutritionInsight(from:))
    }

    var positiveNutritionInsights: [NutritionInsight] {
        CategoryInsightProvider.positiveNutritionInsights(for: categoryInsightContext)
            .map(nutritionInsight(from:))
    }

    var additiveCount: Int {
        ingredients.flatMap(\.flags).filter { $0.kind == .additive }.count
    }

    var comparisonAdditiveCount: Int {
        max(product.additives.count, additiveCount)
    }

    var leadingAllergenStatusText: String? {
        let allergens = linkedAllergenMentions
        guard !allergens.isEmpty else { return nil }

        if allergens.count == 1 {
            return "Contains \(allergens[0])"
        }

        return "Contains \(allergens[0]) and \(allergens[1])"
    }

    var linkedAllergenMentions: [String] {
        var values: [String] = []
        for token in ingredients where token.flags.contains(where: { $0.kind == .allergen }) {
            for allergen in allergenMentions(for: token) where !values.contains(allergen) {
                values.append(allergen)
            }
        }
        return values
    }

    var marketCategory: ProductMarketCategory {
        ProductCategoryResolver.marketCategory(for: product)
    }

    var recommendationFamily: ProductRecommendationFamily {
        ProductRecommendationPlanner.family(for: product)
    }

    var recommendationFamilyLabel: String {
        ProductRecommendationPlanner.familyLabel(for: recommendationFamily)
    }

    var marketCategoryDisplayName: String {
        ProductCategoryResolver.displayName(for: product, marketCategory: marketCategory)
    }

    var containsFruitPectin: Bool {
        ingredients.contains { token in
            let text = token.normalizedText
            return text.contains("pectine") || text.contains("pectin")
        }
    }

    var containsSweetenerIngredient: Bool {
        ingredients.contains { token in
            let text = token.normalizedText
            return text.contains("sweetener")
                || text.contains("sucralose")
                || text.contains("aspartame")
                || text.contains("acesulfame")
                || text.contains("stevia")
        }
    }

    var isWholegrainProduct: Bool {
        let context = ProductDetailFormatting.normalized(
            ([product.name] + ingredients.map(\.normalizedText)).joined(separator: " ")
        )
        return ProductDetailFormatting.matchesAny(
            of: ["wholegrain", "whole grain", "wholemeal", "complet", "complete"],
            in: context
        )
    }

    func beautyMarkerCount(_ marker: AnalysisMarker) -> Int {
        ingredients.flatMap(\.flags).filter { $0.kind == marker }.count
    }

    private var categoryInsightContext: CategoryInsightProvider.Context {
        CategoryInsightProvider.Context(
            marketCategory: marketCategory,
            leadingAllergenText: leadingAllergenStatusText,
            unknownCount: unknownCount,
            cautionCount: cautionCount,
            additiveCount: additiveCount,
            ingredientCount: ingredients.count,
            hasFruitPectin: containsFruitPectin,
            hasSweetenerIngredient: containsSweetenerIngredient,
            isWholegrain: isWholegrainProduct,
            isOCRBacked: product.isOCRBacked,
            beautyFragranceCount: beautyMarkerCount(.fragrance),
            beautyPreservativeCount: beautyMarkerCount(.preservative),
            beautySurfactantCount: beautyMarkerCount(.surfactant),
            nutrition: nutrition
        )
    }

    private func headerStatus(from value: CategoryInsightProvider.HeaderStatus) -> HeaderStatus {
        HeaderStatus(
            title: value.title,
            subtitle: value.subtitle,
            severity: value.severity
        )
    }

    private func takeaway(from value: CategoryInsightProvider.DisplayItem) -> Takeaway {
        Takeaway(
            text: value.text,
            severity: value.severity,
            systemImage: value.systemImage
        )
    }

    private func summaryChip(from value: CategoryInsightProvider.DisplayItem) -> SummaryChip {
        SummaryChip(
            text: value.text,
            severity: value.severity,
            systemImage: value.systemImage
        )
    }

    private func comparisonCriterion(from value: CategoryInsightProvider.ComparisonItem) -> ComparisonCriterion {
        ComparisonCriterion(
            text: value.text,
            systemImage: value.systemImage
        )
    }

    private func nutritionMetric(from value: CategoryInsightProvider.NutritionMetric) -> NutritionMetric {
        NutritionMetric(
            title: value.title,
            valueText: value.valueText,
            severity: value.severity,
            systemImage: value.systemImage
        )
    }

    private func nutritionInsight(from value: CategoryInsightProvider.NutritionInsight) -> NutritionInsight {
        NutritionInsight(
            title: value.title,
            subtitle: value.subtitle,
            valueText: value.valueText,
            systemImage: value.systemImage,
            severity: value.severity
        )
    }
}
