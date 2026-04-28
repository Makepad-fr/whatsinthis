//
//  ProductDetailViewModel.swift
//  whatsinthis
//
//  Created by Codex on 28/04/2026.
//

import Combine
import Foundation

@MainActor
final class ProductDetailViewModel: ObservableObject {
    struct HeaderStatus {
        let title: String
        let subtitle: String
        let severity: FlagSeverity
    }

    struct Takeaway: Identifiable, Hashable {
        let id = UUID()
        let text: String
        let severity: FlagSeverity
        let systemImage: String
    }

    struct SummaryChip: Identifiable, Hashable {
        let id = UUID()
        let text: String
        let severity: FlagSeverity
        let systemImage: String
    }

    struct ComparisonCriterion: Identifiable, Hashable {
        let id = UUID()
        let text: String
        let systemImage: String
    }

    struct NutritionMetric: Identifiable, Hashable {
        let id = UUID()
        let title: String
        let valueText: String
        let severity: FlagSeverity
        let systemImage: String
    }

    struct NutritionInsight: Identifiable, Hashable {
        let id = UUID()
        let title: String
        let subtitle: String
        let valueText: String
        let systemImage: String
        let severity: FlagSeverity
    }

    struct IngredientRow: Identifiable, Hashable {
        let id: UUID
        let token: IngredientToken
        let position: Int
        let notice: String?
        let compactRole: String
        let whatItIs: String
        let whyItMatters: String?
        let usedFor: String?
        let severity: FlagSeverity
    }

    struct SourceConfidenceItem: Identifiable, Hashable {
        let id = UUID()
        let title: String
        let detail: String
        let systemImage: String
    }

    struct SwapReason: Identifiable, Hashable {
        let id = UUID()
        let text: String
        let systemImage: String
        let severity: FlagSeverity
    }

    struct SwapRecommendation: Identifiable, Hashable {
        enum Presentation: Hashable {
            case recommended
            case similar
        }

        let id: String
        let analyzedProduct: AnalyzedProduct
        let title: String
        let subtitle: String?
        let summary: String
        let reasons: [SwapReason]
        let presentation: Presentation

        init(
            analyzedProduct: AnalyzedProduct,
            title: String,
            subtitle: String?,
            summary: String,
            reasons: [SwapReason],
            presentation: Presentation
        ) {
            self.id = analyzedProduct.id
            self.analyzedProduct = analyzedProduct
            self.title = title
            self.subtitle = subtitle
            self.summary = summary
            self.reasons = reasons
            self.presentation = presentation
        }
    }

    private enum MarketCategory {
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

    private enum RecommendationFamily: Hashable {
        case jam
        case cocoaSpread
        case yogurt
        case biscuit
        case cereal
        case soda
        case dryStaple
        case unknown
    }

    private enum LocalFallbackResult {
        case loaded
        case unavailable(cachedCount: Int, comparableCount: Int)
    }

    private struct ScoredRecommendationCandidate {
        let product: NormalizedProduct
        let subtypeOverlap: Int
        let nutritionDistance: Int
        let additiveDistance: Int
    }

    @Published private(set) var analyzedProduct: AnalyzedProduct
    @Published private(set) var imageData: Data?
    @Published private(set) var swapRecommendations: [SwapRecommendation] = []
    @Published private(set) var isLoadingSwapRecommendations = false
    @Published private(set) var swapSectionTitle = "Compare with similar products"
    @Published private(set) var swapSectionStatusMessage: String?

    private let imageRepository: ProductImageRepository
    private let productService: ProductServicing?
    private let ingredientAnalyzer: IngredientAnalyzer?
    private var hasLoadedImage = false
    private var hasLoadedSwapRecommendations = false

    init(
        analyzedProduct: AnalyzedProduct,
        imageRepository: ProductImageRepository,
        productService: ProductServicing? = nil,
        ingredientAnalyzer: IngredientAnalyzer? = nil
    ) {
        self.analyzedProduct = analyzedProduct
        self.imageRepository = imageRepository
        self.productService = productService
        self.ingredientAnalyzer = ingredientAnalyzer
    }

    var product: NormalizedProduct { analyzedProduct.product }
    var ingredients: [IngredientToken] { analyzedProduct.ingredients }
    var summary: InsightSummary { analyzedProduct.summary }
    var cautionCount: Int { analyzedProduct.cautionCount }
    var unknownCount: Int { analyzedProduct.unknownCount }
    var nutrition: NutritionSnapshot? { product.nutrition }
    var hasNutritionTab: Bool {
        product.category == .food && nutrition?.hasAnyValue == true
    }

    var headerMetadata: String {
        [product.brand, marketCategoryDisplayName]
            .compactMap { value in
                guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                return value
            }
            .joined(separator: " • ")
    }

    var headerStatus: HeaderStatus {
        if product.category == .beauty {
            return beautyHeaderStatus
        }

        if let allergenText = leadingAllergenStatusText {
            let subtitle: String
            if allergenText == "Contains wheat / gluten", marketCategory == .dryStaple {
                subtitle = "Common allergen. Expected for this product type."
            } else {
                subtitle = "Common allergen. Check if avoiding it."
            }

            return HeaderStatus(
                title: allergenText,
                subtitle: subtitle,
                severity: .caution
            )
        }

        if let marketStatus = marketHeaderStatus {
            return marketStatus
        }

        if additiveCount > 0 {
            return HeaderStatus(
                title: "Additives found",
                subtitle: "Compare additives if you are choosing between similar products.",
                severity: .caution
            )
        }

        if unknownCount > 0 {
            return HeaderStatus(
                title: "Label explained",
                subtitle: "Check the highlighted items before deciding.",
                severity: .unknown
            )
        }

        if product.isOCRBacked {
            return HeaderStatus(
                title: "Label explained",
                subtitle: "Review ingredient text if something looks wrong.",
                severity: .unknown
            )
        }

        return HeaderStatus(
            title: "Label explained",
            subtitle: "Check the highlighted items before buying.",
            severity: .safe
        )
    }

    var atAGlanceItems: [Takeaway] {
        Array(uniqueTakeaways(categoryAwareTakeaways()).prefix(4))
    }

    var summaryChips: [SummaryChip] {
        Array(categoryAwareSummaryChips().prefix(4))
    }

    var comparisonCriteria: [ComparisonCriterion] {
        comparisonCriteriaTexts.map { text in
            ComparisonCriterion(text: text, systemImage: comparisonSymbol(for: text))
        }
    }

    var sourceConfidenceItems: [SourceConfidenceItem] {
        var items: [SourceConfidenceItem] = [
            SourceConfidenceItem(
                title: "Source",
                detail: sourceSummaryText,
                systemImage: "checklist"
            )
        ]

        items.append(
            SourceConfidenceItem(
                title: "Ingredients",
                detail: ingredientsSourceText,
                systemImage: "list.bullet.rectangle"
            )
        )

        if let nutritionSourceText {
            items.append(
                SourceConfidenceItem(
                    title: "Nutrition",
                    detail: nutritionSourceText,
                    systemImage: "chart.bar"
                )
            )
        }

        if let ocrConfidenceText {
            items.append(
                SourceConfidenceItem(
                    title: "OCR confidence",
                    detail: ocrConfidenceText,
                    systemImage: "text.viewfinder"
                )
            )
        }

        if let reviewNote = sourceReviewNote {
            items.append(
                SourceConfidenceItem(
                    title: "Review note",
                    detail: reviewNote,
                    systemImage: "info.circle"
                )
            )
        }

        return items
    }

    var showsSwapSection: Bool {
        canLoadSwapRecommendations && (isLoadingSwapRecommendations || hasLoadedSwapRecommendations)
    }

    var swapSectionEmptyMessage: String? {
        guard showsSwapSection, !isLoadingSwapRecommendations, swapRecommendations.isEmpty else { return nil }
        return swapSectionStatusMessage ?? "No clearly better or comparable product was found in current database matches."
    }

    var nutritionMetrics: [NutritionMetric] {
        guard let nutrition else { return [] }

        var metrics: [NutritionMetric] = []

        if let calories = nutrition.energyKcalPer100g {
            metrics.append(
                NutritionMetric(
                    title: "Calories",
                    valueText: Self.formattedValue(calories, unit: "Cal", decimals: 0),
                    severity: caloriesMetricSeverity(for: calories),
                    systemImage: "flame.fill"
                )
            )
        }

        if let sugar = nutrition.sugarsPer100g {
            metrics.append(
                NutritionMetric(
                    title: "Sugar",
                    valueText: Self.formattedValue(sugar, unit: "g"),
                    severity: sugarMetricSeverity(for: sugar),
                    systemImage: "cube.box.fill"
                )
            )
        }

        if let saturatedFat = nutrition.saturatedFatPer100g {
            metrics.append(
                NutritionMetric(
                    title: "Sat. fat",
                    valueText: Self.formattedValue(saturatedFat, unit: "g"),
                    severity: saturatedFatMetricSeverity(for: saturatedFat),
                    systemImage: "drop.fill"
                )
            )
        }

        if let salt = nutrition.saltPer100g {
            metrics.append(
                NutritionMetric(
                    title: "Salt",
                    valueText: Self.formattedValue(salt, unit: "g"),
                    severity: saltMetricSeverity(for: salt),
                    systemImage: "takeoutbag.and.cup.and.straw.fill"
                )
            )
        }

        if let fiber = nutrition.fiberPer100g {
            metrics.append(
                NutritionMetric(
                    title: "Fiber",
                    valueText: Self.formattedValue(fiber, unit: "g"),
                    severity: fiberMetricSeverity(for: fiber),
                    systemImage: "leaf.fill"
                )
            )
        }

        if let protein = nutrition.proteinPer100g {
            metrics.append(
                NutritionMetric(
                    title: "Protein",
                    valueText: Self.formattedValue(protein, unit: "g"),
                    severity: proteinMetricSeverity(for: protein),
                    systemImage: "bolt.heart.fill"
                )
            )
        }

        return metrics
    }

    var negativeNutritionInsights: [NutritionInsight] {
        guard let nutrition else { return [] }

        return [
            caloriesInsight(for: nutrition.energyKcalPer100g),
            sugarInsight(for: nutrition.sugarsPer100g),
            saturatedFatInsight(for: nutrition.saturatedFatPer100g),
            saltInsight(for: nutrition.saltPer100g),
        ]
        .compactMap { $0 }
    }

    var positiveNutritionInsights: [NutritionInsight] {
        guard let nutrition else { return [] }

        var insights: [NutritionInsight] = []

        if marketCategory == .dryStaple || marketCategory == .cereal, let fiber = nutrition.fiberPer100g, fiber >= 3 {
            insights.append(
                NutritionInsight(
                    title: "Fiber",
                    subtitle: fiber >= 6 ? "Good fiber for this type of product." : "Useful fiber for this category.",
                    valueText: Self.formattedValue(fiber, unit: "g"),
                    systemImage: "leaf.fill",
                    severity: .safe
                )
            )
        }

        if marketCategory == .yogurtOrDairy || marketCategory == .readyMeal, let protein = nutrition.proteinPer100g, protein >= 5 {
            insights.append(
                NutritionInsight(
                    title: "Protein",
                    subtitle: protein >= 10 ? "Strong protein level for this category." : "Useful protein for this category.",
                    valueText: Self.formattedValue(protein, unit: "g"),
                    systemImage: "bolt.heart.fill",
                    severity: .safe
                )
            )
        }

        if marketCategory == .cereal || marketCategory == .yogurtOrDairy, let sugar = nutrition.sugarsPer100g, sugar <= 5 {
            insights.append(
                NutritionInsight(
                    title: "Sugar",
                    subtitle: "Low sugar for this category.",
                    valueText: Self.formattedValue(sugar, unit: "g"),
                    systemImage: "cube.box.fill",
                    severity: .safe
                )
            )
        }

        return insights
    }

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

    func loadImageIfNeeded() async {
        guard !hasLoadedImage else { return }
        hasLoadedImage = true

        let cacheKey = analyzedProduct.product.barcode ?? analyzedProduct.id
        imageData = await imageRepository.loadImageData(for: cacheKey, remoteURL: analyzedProduct.product.imageURL)
    }

    func loadSwapRecommendationsIfNeeded() async {
        guard !hasLoadedSwapRecommendations else { return }
        hasLoadedSwapRecommendations = true

        guard
            product.category == .food,
            !product.isOCRBacked,
            let nutrition,
            nutrition.hasAnyValue,
            let productService,
            let ingredientAnalyzer
        else {
            return
        }

        isLoadingSwapRecommendations = true
        defer { isLoadingSwapRecommendations = false }
        swapSectionStatusMessage = nil

        do {
            let candidates = prioritizedRecommendationCandidates(
                try await productService.similarProducts(for: product, limit: 6)
            )
            let recommendations = candidates.compactMap { candidate in
                buildSwapRecommendation(for: candidate, using: ingredientAnalyzer)
            }

            if !recommendations.isEmpty {
                swapSectionTitle = "Compare with similar products"
                swapRecommendations = Array(recommendations.prefix(3))
            } else {
                let similarOptions = candidates.compactMap { candidate in
                    buildSimilarOption(for: candidate, using: ingredientAnalyzer)
                }
                if !similarOptions.isEmpty {
                    swapSectionTitle = "Compare with similar products"
                    swapRecommendations = Array(similarOptions.prefix(3))
                } else {
                    switch await applyLocalFallbackRecommendations(using: ingredientAnalyzer) {
                    case .loaded:
                        break
                    case .unavailable:
                        swapSectionTitle = "Compare with similar products"
                        swapRecommendations = []
                    }
                }
            }
        } catch let error as SimilarProductsLookupError {
            switch await applyLocalFallbackRecommendations(using: ingredientAnalyzer) {
            case .loaded:
                break
            case .unavailable(let cachedCount, let comparableCount):
                swapSectionTitle = "Compare with similar products"
                swapRecommendations = []
                swapSectionStatusMessage = localFallbackFailureMessage(
                    for: error,
                    cachedCount: cachedCount,
                    comparableCount: comparableCount
                )
            }
        } catch {
            switch await applyLocalFallbackRecommendations(using: ingredientAnalyzer) {
            case .loaded:
                break
            case .unavailable(let cachedCount, let comparableCount):
                swapSectionTitle = "Compare with similar products"
                swapRecommendations = []
                if comparableCount == 0 {
                    swapSectionStatusMessage = "Similar products could not be loaded right now, and there are no comparable \(recommendationFamilyLabel) products in your recent scans yet."
                } else {
                    swapSectionStatusMessage = "Similar products could not be loaded right now. Scan another similar product to compare manually."
                }
            }
        }
    }

    func makeDetailViewModel(for analyzedProduct: AnalyzedProduct) -> ProductDetailViewModel {
        ProductDetailViewModel(
            analyzedProduct: analyzedProduct,
            imageRepository: imageRepository,
            productService: productService,
            ingredientAnalyzer: ingredientAnalyzer
        )
    }

    private var additiveCount: Int {
        ingredients.flatMap(\.flags).filter { $0.kind == .additive }.count
    }

    private var comparisonAdditiveCount: Int {
        max(product.additives.count, additiveCount)
    }

    private var leadingAllergenStatusText: String? {
        let allergens = linkedAllergenMentions
        guard !allergens.isEmpty else { return nil }

        if allergens.count == 1 {
            return "Contains \(allergens[0])"
        }

        return "Contains \(allergens[0]) and \(allergens[1])"
    }

    private var leadingAllergenTakeaway: Takeaway? {
        let allergens = linkedAllergenMentions
        guard let first = allergens.first else { return nil }

        let text: String
        if first == "wheat / gluten" {
            text = "Check if avoiding gluten"
        } else {
            text = "Check if avoiding \(first)"
        }

        return Takeaway(
            text: text,
            severity: .caution,
            systemImage: "exclamationmark.circle.fill"
        )
    }

    private var linkedAllergenMentions: [String] {
        var values: [String] = []
        for token in ingredients where token.flags.contains(where: { $0.kind == .allergen }) {
            for allergen in allergenMentions(for: token) where !values.contains(allergen) {
                values.append(allergen)
            }
        }
        return values
    }

    private var simpleIngredientListTakeaway: Takeaway? {
        guard unknownCount == 0 else { return nil }

        if ingredients.count == 1 {
            return Takeaway(
                text: "Simple ingredient list",
                severity: .safe,
                systemImage: "checkmark.circle.fill"
            )
        }

        if ingredients.count <= 4 && cautionCount <= 1 {
            return Takeaway(
                text: "Simple ingredient list",
                severity: .safe,
                systemImage: "checkmark.circle.fill"
            )
        }

        return nil
    }

    private var primaryNutritionHeaderStatus: HeaderStatus? {
        guard let insight = negativeNutritionInsights.first(where: { $0.severity == .caution }) else {
            return nil
        }

        let title: String
        switch insight.title {
        case "Sugar":
            title = "High sugar"
        case "Sat. fat":
            title = "High saturated fat"
        case "Salt":
            title = "High salt"
        case "Calories":
            title = "Energy-dense"
        default:
            title = insight.title
        }

        return HeaderStatus(
            title: title,
            subtitle: insight.subtitle,
            severity: insight.severity
        )
    }

    private var primaryNutritionTakeaway: Takeaway? {
        nutritionWarningTakeaways.first(where: { $0.severity == .caution })
    }

    private var nutritionWarningTakeaways: [Takeaway] {
        guard let nutrition else { return [] }

        var items: [Takeaway] = []

        if let sugarTakeaway = sugarTakeaway(for: nutrition.sugarsPer100g) {
            items.append(sugarTakeaway)
        }

        if let saturatedFatTakeaway = saturatedFatTakeaway(for: nutrition.saturatedFatPer100g) {
            items.append(saturatedFatTakeaway)
        }

        if items.count < 2, let saltTakeaway = saltTakeaway(for: nutrition.saltPer100g) {
            items.append(saltTakeaway)
        }

        return items
    }

    private var ocrConfidenceLabel: String? {
        guard product.isOCRBacked, let ocrConfidence = product.ocrConfidence else { return nil }

        switch ocrConfidence {
        case 0.85...:
            return "High"
        case 0.6...:
            return "Medium"
        default:
            return "Low"
        }
    }

    private var canLoadSwapRecommendations: Bool {
        product.category == .food &&
        !product.isOCRBacked &&
        nutrition?.hasAnyValue == true &&
        productService != nil &&
        ingredientAnalyzer != nil
    }

    private var marketCategory: MarketCategory {
        marketCategory(for: product)
    }

    private var recommendationFamily: RecommendationFamily {
        recommendationFamily(for: product)
    }

    private var recommendationFamilyLabel: String {
        switch recommendationFamily {
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

    private var marketCategoryDisplayName: String {
        switch marketCategory {
        case .jam:
            return "Jam"
        case .dryStaple:
            let text = normalized(product.name)
            if matchesAny(of: ["flour", "farine"], in: text) {
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

    private var beautyHeaderStatus: HeaderStatus {
        if beautyMarkerCount(.fragrance) > 0 {
            return HeaderStatus(
                title: "Check sensitive-skin markers",
                subtitle: "Fragrance ingredients are listed in the formula.",
                severity: .caution
            )
        }

        if beautyMarkerCount(.preservative) > 0 || beautyMarkerCount(.surfactant) > 0 {
            return HeaderStatus(
                title: "Check sensitive-skin markers",
                subtitle: "Look for preservatives, alcohol, fragrance, or silicones before deciding.",
                severity: .unknown
            )
        }

        if product.isOCRBacked {
            return HeaderStatus(
                title: "Label explained",
                subtitle: "Review ingredient text if something looks wrong.",
                severity: .unknown
            )
        }

        return HeaderStatus(
            title: "Check sensitive-skin markers",
            subtitle: "Look for fragrance allergens, alcohol, preservatives, and silicones.",
            severity: .unknown
        )
    }

    private var marketHeaderStatus: HeaderStatus? {
        switch marketCategory {
        case .jam:
            return HeaderStatus(
                title: jamHeadline,
                subtitle: "Compare sugar and fruit content if choosing between jars.",
                severity: sugarMetricSeverity(for: nutrition?.sugarsPer100g ?? 0) == .caution ? .caution : .unknown
            )
        case .dryStaple:
            return HeaderStatus(
                title: "Energy-dense dry staple.",
                subtitle: leadingAllergenStatusText == nil ? "Check mainly if avoiding wheat or gluten." : "Common allergen. Expected for this product type.",
                severity: leadingAllergenStatusText == nil ? .unknown : .caution
            )
        case .yogurtOrDairy:
            return HeaderStatus(
                title: "Check sugar and protein.",
                subtitle: "Plain yogurts are usually easier to compare.",
                severity: nutrition?.sugarsPer100g ?? 0 >= 10 ? .caution : .unknown
            )
        case .cereal:
            return HeaderStatus(
                title: "Compare sugar and fiber first.",
                subtitle: "Higher fiber and lower sugar usually make cereals easier to choose.",
                severity: nutrition?.sugarsPer100g ?? 0 >= 15 ? .caution : .unknown
            )
        case .sweetDrink:
            return HeaderStatus(
                title: "High sugar drink.",
                subtitle: "Compare sugar per 100 ml and sweeteners.",
                severity: .caution
            )
        case .biscuitsOrSweets:
            return HeaderStatus(
                title: "Sweet snack.",
                subtitle: "Compare sugar, saturated fat, and additives.",
                severity: (nutrition?.sugarsPer100g ?? 0) >= 22.5 || (nutrition?.saturatedFatPer100g ?? 0) >= 5 ? .caution : .unknown
            )
        case .sauceOrCondiment:
            return HeaderStatus(
                title: "Check salt and sugar.",
                subtitle: "Small portions can still add up.",
                severity: max(nutrition?.saltPer100g ?? 0, nutrition?.sugarsPer100g ?? 0) > 0.6 ? .caution : .unknown
            )
        case .readyMeal:
            return HeaderStatus(
                title: "Check salt, sat. fat, and protein.",
                subtitle: "Ready meals vary a lot by nutrition balance.",
                severity: (nutrition?.saltPer100g ?? 0) >= 0.6 || (nutrition?.saturatedFatPer100g ?? 0) >= 3 ? .caution : .unknown
            )
        case .beauty, .unknown:
            return nil
        }
    }

    private var jamHeadline: String {
        if let sugar = nutrition?.sugarsPer100g, sugar >= 22.5 {
            return "High sugar, typical for jam."
        }

        if let sugar = nutrition?.sugarsPer100g, sugar > 0 {
            return "Sweet preserve."
        }

        return "Jam or fruit preserve."
    }

    private var comparisonCriteriaTexts: [String] {
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

    private func comparisonSymbol(for text: String) -> String {
        switch normalized(text) {
        case "sugar":
            return "cube.box.fill"
        case "fruit %":
            return "leaf.fill"
        case "additives":
            return "sparkles.rectangle.stack.fill"
        case "fiber":
            return "leaf"
        case "wholegrain":
            return "circle.grid.2x2.fill"
        case "gluten":
            return "exclamationmark.circle.fill"
        case "protein":
            return "bolt.heart.fill"
        case "fat", "sat. fat":
            return "drop.fill"
        case "sweeteners":
            return "sparkles"
        case "salt":
            return "takeoutbag.and.cup.and.straw.fill"
        case "fragrance":
            return "sparkles"
        case "alcohol":
            return "drop.triangle"
        case "preservatives":
            return "shield.lefthalf.filled"
        default:
            return "slider.horizontal.3"
        }
    }

    private func categoryAwareTakeaways() -> [Takeaway] {
        var items: [Takeaway] = []

        switch marketCategory {
        case .jam:
            if let sugar = nutrition?.sugarsPer100g {
                items.append(
                    Takeaway(
                        text: "\(Self.formattedValue(sugar, unit: "g")) sugar / 100g",
                        severity: sugar >= 22.5 ? .caution : .unknown,
                        systemImage: "cube.box.fill"
                    )
                )
            }
            if containsFruitPectin {
                items.append(
                    Takeaway(
                        text: "Contains fruit pectin",
                        severity: .safe,
                        systemImage: "leaf.fill"
                    )
                )
            }
            if let simpleIngredientListTakeaway {
                items.append(simpleIngredientListTakeaway)
            }
            if let noSaltOrFatConcernTakeaway {
                items.append(noSaltOrFatConcernTakeaway)
            }
        case .dryStaple:
            if let allergenTakeaway = leadingAllergenTakeaway {
                items.append(allergenTakeaway)
            }
            if let fiberTakeaway = meaningfulFiberTakeaway {
                items.append(fiberTakeaway)
            }
            items.append(
                Takeaway(
                    text: "Dry staple",
                    severity: .unknown,
                    systemImage: "shippingbox.fill"
                )
            )
            if let simpleIngredientListTakeaway {
                items.append(simpleIngredientListTakeaway)
            }
        case .yogurtOrDairy:
            if let sugarTakeaway = sugarTakeaway(for: nutrition?.sugarsPer100g) {
                items.append(sugarTakeaway)
            }
            if let proteinTakeaway = proteinTakeaway {
                items.append(proteinTakeaway)
            }
            if let saturatedFatTakeaway = saturatedFatTakeaway(for: nutrition?.saturatedFatPer100g) {
                items.append(saturatedFatTakeaway)
            }
            if additiveCount > 0 {
                items.append(Takeaway(text: "Additives found", severity: .caution, systemImage: "sparkles.rectangle.stack.fill"))
            }
        case .cereal:
            if let sugarTakeaway = sugarTakeaway(for: nutrition?.sugarsPer100g) {
                items.append(sugarTakeaway)
            }
            if let fiberTakeaway = meaningfulFiberTakeaway {
                items.append(fiberTakeaway)
            }
            if additiveCount > 0 {
                items.append(Takeaway(text: "Additives found", severity: .caution, systemImage: "sparkles.rectangle.stack.fill"))
            }
        case .sweetDrink:
            if let sugarTakeaway = sugarTakeaway(for: nutrition?.sugarsPer100g) {
                items.append(sugarTakeaway)
            }
            if containsSweetenerIngredient {
                items.append(Takeaway(text: "Sweeteners listed", severity: .unknown, systemImage: "sparkles"))
            }
            if additiveCount > 0 {
                items.append(Takeaway(text: "Additives found", severity: .caution, systemImage: "sparkles.rectangle.stack.fill"))
            }
        case .biscuitsOrSweets:
            if let sugarTakeaway = sugarTakeaway(for: nutrition?.sugarsPer100g) {
                items.append(sugarTakeaway)
            }
            if let saturatedFatTakeaway = saturatedFatTakeaway(for: nutrition?.saturatedFatPer100g) {
                items.append(saturatedFatTakeaway)
            }
            if additiveCount > 0 {
                items.append(Takeaway(text: "Additives found", severity: .caution, systemImage: "sparkles.rectangle.stack.fill"))
            }
        case .sauceOrCondiment:
            if let saltTakeaway = saltTakeaway(for: nutrition?.saltPer100g) {
                items.append(saltTakeaway)
            }
            if let sugarTakeaway = sugarTakeaway(for: nutrition?.sugarsPer100g) {
                items.append(sugarTakeaway)
            }
            if additiveCount > 0 {
                items.append(Takeaway(text: "Additives found", severity: .caution, systemImage: "sparkles.rectangle.stack.fill"))
            }
        case .readyMeal:
            if let saltTakeaway = saltTakeaway(for: nutrition?.saltPer100g) {
                items.append(saltTakeaway)
            }
            if let saturatedFatTakeaway = saturatedFatTakeaway(for: nutrition?.saturatedFatPer100g) {
                items.append(saturatedFatTakeaway)
            }
            if let proteinTakeaway = proteinTakeaway {
                items.append(proteinTakeaway)
            }
        case .beauty:
            if beautyMarkerCount(.fragrance) > 0 {
                items.append(Takeaway(text: "Fragrance ingredients found", severity: .caution, systemImage: "sparkles"))
            }
            if beautyMarkerCount(.preservative) > 0 {
                items.append(Takeaway(text: "Preservatives listed", severity: .unknown, systemImage: "shield.lefthalf.filled"))
            }
            if beautyMarkerCount(.surfactant) > 0 {
                items.append(Takeaway(text: "Cleansing ingredients found", severity: .unknown, systemImage: "drop.fill"))
            }
        case .unknown:
            if let allergenTakeaway = leadingAllergenTakeaway {
                items.append(allergenTakeaway)
            }
            if additiveCount > 0 {
                items.append(Takeaway(text: "Additives found", severity: .caution, systemImage: "sparkles.rectangle.stack.fill"))
            }
            if unknownCount > 0 {
                items.append(Takeaway(text: "Some terms need more context", severity: .unknown, systemImage: "questionmark.circle.fill"))
            }
            if items.isEmpty {
                items.append(Takeaway(text: "Label explained", severity: .safe, systemImage: "checkmark.circle.fill"))
            }
        }

        if items.count < 3, product.isOCRBacked {
            items.append(Takeaway(text: "Review label text if something looks wrong", severity: .unknown, systemImage: "text.viewfinder"))
        }

        return items
    }

    private func categoryAwareSummaryChips() -> [SummaryChip] {
        var chips: [SummaryChip] = [
            SummaryChip(
                text: ingredientCountLabel,
                severity: .unknown,
                systemImage: "list.bullet"
            )
        ]

        switch marketCategory {
        case .jam:
            if let sugar = nutrition?.sugarsPer100g {
                chips.append(
                    SummaryChip(
                        text: "\(Self.formattedValue(sugar, unit: "g")) sugar / 100g",
                        severity: sugar >= 22.5 ? .caution : .unknown,
                        systemImage: "cube.box.fill"
                    )
                )
            }
            if containsFruitPectin {
                chips.append(
                    SummaryChip(
                        text: "Fruit pectin",
                        severity: .safe,
                        systemImage: "leaf.fill"
                    )
                )
            }
        case .dryStaple:
            if let fiber = nutrition?.fiberPer100g, fiber >= 3 {
                chips.append(
                    SummaryChip(
                        text: "\(Self.formattedValue(fiber, unit: "g")) fiber",
                        severity: .safe,
                        systemImage: "leaf.fill"
                    )
                )
            }
            if isWholegrainProduct {
                chips.append(
                    SummaryChip(
                        text: "Wholegrain",
                        severity: .safe,
                        systemImage: "circle.grid.2x2.fill"
                    )
                )
            }
        case .yogurtOrDairy:
            if let sugar = nutrition?.sugarsPer100g {
                chips.append(SummaryChip(text: "\(Self.formattedValue(sugar, unit: "g")) sugar", severity: sugarMetricSeverity(for: sugar), systemImage: "cube.box.fill"))
            }
            if let protein = nutrition?.proteinPer100g {
                chips.append(SummaryChip(text: "\(Self.formattedValue(protein, unit: "g")) protein", severity: proteinMetricSeverity(for: protein), systemImage: "bolt.heart.fill"))
            }
        case .cereal:
            if let sugar = nutrition?.sugarsPer100g {
                chips.append(SummaryChip(text: "\(Self.formattedValue(sugar, unit: "g")) sugar", severity: sugarMetricSeverity(for: sugar), systemImage: "cube.box.fill"))
            }
            if let fiber = nutrition?.fiberPer100g {
                chips.append(SummaryChip(text: "\(Self.formattedValue(fiber, unit: "g")) fiber", severity: fiberMetricSeverity(for: fiber), systemImage: "leaf.fill"))
            }
        case .sweetDrink:
            if let sugar = nutrition?.sugarsPer100g {
                chips.append(SummaryChip(text: "\(Self.formattedValue(sugar, unit: "g")) sugar", severity: sugarMetricSeverity(for: sugar), systemImage: "cube.box.fill"))
            }
        case .biscuitsOrSweets:
            if let sugar = nutrition?.sugarsPer100g {
                chips.append(SummaryChip(text: "\(Self.formattedValue(sugar, unit: "g")) sugar", severity: sugarMetricSeverity(for: sugar), systemImage: "cube.box.fill"))
            }
            if let saturatedFat = nutrition?.saturatedFatPer100g {
                chips.append(SummaryChip(text: "\(Self.formattedValue(saturatedFat, unit: "g")) sat. fat", severity: saturatedFatMetricSeverity(for: saturatedFat), systemImage: "drop.fill"))
            }
        case .sauceOrCondiment:
            if let salt = nutrition?.saltPer100g {
                chips.append(SummaryChip(text: "\(Self.formattedValue(salt, unit: "g")) salt", severity: saltMetricSeverity(for: salt), systemImage: "takeoutbag.and.cup.and.straw.fill"))
            }
            if let sugar = nutrition?.sugarsPer100g {
                chips.append(SummaryChip(text: "\(Self.formattedValue(sugar, unit: "g")) sugar", severity: sugarMetricSeverity(for: sugar), systemImage: "cube.box.fill"))
            }
        case .readyMeal:
            if let salt = nutrition?.saltPer100g {
                chips.append(SummaryChip(text: "\(Self.formattedValue(salt, unit: "g")) salt", severity: saltMetricSeverity(for: salt), systemImage: "takeoutbag.and.cup.and.straw.fill"))
            }
            if let protein = nutrition?.proteinPer100g {
                chips.append(SummaryChip(text: "\(Self.formattedValue(protein, unit: "g")) protein", severity: proteinMetricSeverity(for: protein), systemImage: "bolt.heart.fill"))
            }
        case .beauty:
            if beautyMarkerCount(.fragrance) > 0 {
                chips.append(SummaryChip(text: "Fragrance", severity: .caution, systemImage: "sparkles"))
            }
            if beautyMarkerCount(.preservative) > 0 {
                chips.append(SummaryChip(text: "Preservatives", severity: .unknown, systemImage: "shield.lefthalf.filled"))
            }
        case .unknown:
            if cautionCount > 0 {
                chips.append(SummaryChip(text: "\(cautionCount) to check", severity: .caution, systemImage: "exclamationmark.circle.fill"))
            } else if unknownCount > 0 {
                chips.append(SummaryChip(text: unknownCount == 1 ? "1 item needs context" : "\(unknownCount) items need context", severity: .unknown, systemImage: "questionmark.circle.fill"))
            }
        }

        return chips
    }

    private func marketCategory(for candidate: NormalizedProduct) -> MarketCategory {
        if candidate.category == .beauty {
            return .beauty
        }

        let contextText = normalized(
            ([candidate.name] + candidate.categoryTags + [candidate.ingredientText])
                .joined(separator: " ")
        )

        if matchesAny(of: ["flour", "farine", "wholemeal", "whole wheat", "semolina", "semoule", "rice", "oat", "oats", "lentil", "quinoa", "couscous", "dry pasta", "pasta", "farina"], in: contextText) {
            return .dryStaple
        }

        if matchesAny(of: ["jam", "jams", "confiture", "marmalade", "jelly", "preserve", "preserves", "fruit spread", "sweet spread", "pate a tartiner"], in: contextText) {
            return .jam
        }

        if matchesAny(of: ["soda", "cola", "soft drink", "soft-drinks", "energy drink", "beverage", "drink", "boisson"], in: contextText) {
            return .sweetDrink
        }

        if matchesAny(of: ["yogurt", "yoghurt", "yaourt", "dairy", "milk", "fromage blanc"], in: contextText) {
            return .yogurtOrDairy
        }

        if matchesAny(of: ["cereal", "cereals", "granola", "muesli", "breakfast cereal"], in: contextText) {
            return .cereal
        }

        if matchesAny(of: ["biscuit", "biscuits", "cookie", "cookies", "chocolate", "candy", "confectionery", "sweet", "dessert"], in: contextText) {
            return .biscuitsOrSweets
        }

        if matchesAny(of: ["sauce", "ketchup", "mustard", "mayo", "mayonnaise", "condiment", "vinaigrette", "dressing"], in: contextText) {
            return .sauceOrCondiment
        }

        if matchesAny(of: ["ready meal", "prepared meal", "frozen meal", "pizza", "lasagna", "lasagne", "meal"], in: contextText) {
            return .readyMeal
        }

        return .unknown
    }

    private func recommendationFamily(for candidate: NormalizedProduct) -> RecommendationFamily {
        let contextText = normalized(
            ([candidate.name] + candidate.categoryTags + [candidate.ingredientText])
                .joined(separator: " ")
        )

        if matchesAny(of: ["confiture", "jam", "jams", "marmalade", "jelly", "preserve", "preserves", "fruit spread"], in: contextText) {
            return .jam
        }

        if matchesAny(of: ["hazelnut spread", "chocolate spread", "cocoa and hazelnut", "pate a tartiner", "pâte à tartiner", "sweet spread"], in: contextText) {
            return .cocoaSpread
        }

        if matchesAny(of: ["yogurt", "yoghurt", "yaourt"], in: contextText) {
            return .yogurt
        }

        if matchesAny(of: ["biscuit", "biscuits", "cookie", "cookies", "cracker"], in: contextText) {
            return .biscuit
        }

        if matchesAny(of: ["cereal", "cereals", "granola", "muesli"], in: contextText) {
            return .cereal
        }

        if matchesAny(of: ["soda", "cola", "soft drink", "soft drinks", "beverage", "boisson"], in: contextText) {
            return .soda
        }

        if marketCategory(for: candidate) == .dryStaple {
            return .dryStaple
        }

        return .unknown
    }

    private func caloriesInsight(for value: Double?) -> NutritionInsight? {
        guard let value else { return nil }

        switch marketCategory {
        case .dryStaple where value >= 250:
            return NutritionInsight(
                title: "Calories",
                subtitle: "Energy-dense because it is a dry staple ingredient. Not unusual for this product type.",
                valueText: Self.formattedValue(value, unit: "Cal", decimals: 0),
                systemImage: "flame.fill",
                severity: .unknown
            )
        case .readyMeal where value >= 220:
            return NutritionInsight(
                title: "Calories",
                subtitle: "Check the calories alongside salt, saturated fat, and protein.",
                valueText: Self.formattedValue(value, unit: "Cal", decimals: 0),
                systemImage: "flame.fill",
                severity: .caution
            )
        case .biscuitsOrSweets where value >= 400, .jam where value >= 400:
            return NutritionInsight(
                title: "Calories",
                subtitle: "Energy-dense for this type of product.",
                valueText: Self.formattedValue(value, unit: "Cal", decimals: 0),
                systemImage: "flame.fill",
                severity: .unknown
            )
        default:
            guard value >= 400 else { return nil }
            return NutritionInsight(
                title: "Calories",
                subtitle: "Energy-dense product.",
                valueText: Self.formattedValue(value, unit: "Cal", decimals: 0),
                systemImage: "flame.fill",
                severity: .unknown
            )
        }
    }

    private func sugarInsight(for value: Double?) -> NutritionInsight? {
        guard let value else { return nil }

        switch marketCategory {
        case .sweetDrink where value >= 5:
            return NutritionInsight(
                title: "Sugar",
                subtitle: "High sugar drink.",
                valueText: Self.formattedValue(value, unit: "g"),
                systemImage: "cube.box.fill",
                severity: .caution
            )
        case .jam where value >= 22.5:
            return NutritionInsight(
                title: "Sugar",
                subtitle: "Typical for jam, but useful to compare between similar jars.",
                valueText: Self.formattedValue(value, unit: "g"),
                systemImage: "cube.box.fill",
                severity: .caution
            )
        case .biscuitsOrSweets where value >= 22.5:
            return NutritionInsight(
                title: "Sugar",
                subtitle: "High sugar for this type of product.",
                valueText: Self.formattedValue(value, unit: "g"),
                systemImage: "cube.box.fill",
                severity: .caution
            )
        case .biscuitsOrSweets where value >= 10, .jam where value >= 10:
            return NutritionInsight(
                title: "Sugar",
                subtitle: "Sugary product.",
                valueText: Self.formattedValue(value, unit: "g"),
                systemImage: "cube.box.fill",
                severity: .unknown
            )
        case .yogurtOrDairy where value >= 10:
            return NutritionInsight(
                title: "Sugar",
                subtitle: "Sweetened dairy product. Check sugar.",
                valueText: Self.formattedValue(value, unit: "g"),
                systemImage: "cube.box.fill",
                severity: .caution
            )
        case .cereal where value >= 15:
            return NutritionInsight(
                title: "Sugar",
                subtitle: "Compare sugar first for breakfast cereals.",
                valueText: Self.formattedValue(value, unit: "g"),
                systemImage: "cube.box.fill",
                severity: .caution
            )
        case .sauceOrCondiment where value >= 10:
            return NutritionInsight(
                title: "Sugar",
                subtitle: "Check sugar for sauces and condiments.",
                valueText: Self.formattedValue(value, unit: "g"),
                systemImage: "cube.box.fill",
                severity: .caution
            )
        default:
            if value >= 22.5 {
                return NutritionInsight(
                    title: "Sugar",
                    subtitle: "High sugar.",
                    valueText: Self.formattedValue(value, unit: "g"),
                    systemImage: "cube.box.fill",
                    severity: .caution
                )
            }

            if value >= 10 {
                return NutritionInsight(
                    title: "Sugar",
                    subtitle: "Some sugar to notice.",
                    valueText: Self.formattedValue(value, unit: "g"),
                    systemImage: "cube.box.fill",
                    severity: .unknown
                )
            }

            return nil
        }
    }

    private func saturatedFatInsight(for value: Double?) -> NutritionInsight? {
        guard let value else { return nil }

        switch marketCategory {
        case .biscuitsOrSweets where value >= 5:
            return NutritionInsight(
                title: "Sat. fat",
                subtitle: "High saturated fat for this type of product.",
                valueText: Self.formattedValue(value, unit: "g"),
                systemImage: "drop.fill",
                severity: .caution
            )
        case .biscuitsOrSweets where value >= 1.5:
            return NutritionInsight(
                title: "Sat. fat",
                subtitle: "Some saturated fat to notice.",
                valueText: Self.formattedValue(value, unit: "g"),
                systemImage: "drop.fill",
                severity: .unknown
            )
        case .yogurtOrDairy where value >= 5:
            return NutritionInsight(
                title: "Sat. fat",
                subtitle: "High saturated fat for a dairy product.",
                valueText: Self.formattedValue(value, unit: "g"),
                systemImage: "drop.fill",
                severity: .caution
            )
        case .yogurtOrDairy where value >= 1.5:
            return NutritionInsight(
                title: "Sat. fat",
                subtitle: "Check saturated fat for a dairy product.",
                valueText: Self.formattedValue(value, unit: "g"),
                systemImage: "drop.fill",
                severity: .unknown
            )
        case .readyMeal where value >= 3:
            return NutritionInsight(
                title: "Sat. fat",
                subtitle: "Check saturated fat for this ready meal.",
                valueText: Self.formattedValue(value, unit: "g"),
                systemImage: "drop.fill",
                severity: .caution
            )
        default:
            if value >= 5 {
                return NutritionInsight(
                    title: "Sat. fat",
                    subtitle: "High saturated fat.",
                    valueText: Self.formattedValue(value, unit: "g"),
                    systemImage: "drop.fill",
                    severity: .caution
                )
            }

            if value >= 1.5 {
                return NutritionInsight(
                    title: "Sat. fat",
                    subtitle: "Some saturated fat to notice.",
                    valueText: Self.formattedValue(value, unit: "g"),
                    systemImage: "drop.fill",
                    severity: .unknown
                )
            }

            return nil
        }
    }

    private func saltInsight(for value: Double?) -> NutritionInsight? {
        guard let value else { return nil }

        if marketCategory == .jam || marketCategory == .dryStaple {
            return nil
        }

        if value >= 1.5 {
            return NutritionInsight(
                title: "Salt",
                subtitle: "High salt.",
                valueText: Self.formattedValue(value, unit: "g"),
                systemImage: "takeoutbag.and.cup.and.straw.fill",
                severity: .caution
            )
        }

        if marketCategory == .sauceOrCondiment && value >= 0.6 {
            return NutritionInsight(
                title: "Salt",
                subtitle: "Check salt and portion size.",
                valueText: Self.formattedValue(value, unit: "g"),
                systemImage: "takeoutbag.and.cup.and.straw.fill",
                severity: .caution
            )
        }

        if value >= 0.3, marketCategory == .readyMeal || marketCategory == .sauceOrCondiment {
            return NutritionInsight(
                title: "Salt",
                subtitle: "Some salt to notice.",
                valueText: Self.formattedValue(value, unit: "g"),
                systemImage: "takeoutbag.and.cup.and.straw.fill",
                severity: .unknown
            )
        }

        return nil
    }

    private func caloriesMetricSeverity(for value: Double) -> FlagSeverity {
        switch marketCategory {
        case .dryStaple:
            return .unknown
        case .readyMeal:
            return value >= 220 ? .caution : .unknown
        case .biscuitsOrSweets:
            return value >= 400 ? .caution : .unknown
        default:
            return .unknown
        }
    }

    private func sugarMetricSeverity(for value: Double) -> FlagSeverity {
        switch marketCategory {
        case .sweetDrink:
            if value >= 5 { return .caution }
        case .jam, .biscuitsOrSweets:
            if value >= 22.5 { return .caution }
            if value >= 10 { return .unknown }
            return .unknown
        case .cereal:
            if value >= 15 { return .caution }
            if value <= 8 { return .safe }
            return .unknown
        case .yogurtOrDairy:
            if value >= 10 { return .caution }
            if value <= 5 { return .safe }
            return .unknown
        case .sauceOrCondiment:
            if value >= 10 { return .caution }
            return .unknown
        default:
            if value >= 10 { return .caution }
        }

        if value <= 5 {
            return .safe
        }

        return .unknown
    }

    private func saturatedFatMetricSeverity(for value: Double) -> FlagSeverity {
        switch marketCategory {
        case .jam, .dryStaple, .sweetDrink:
            return .unknown
        case .yogurtOrDairy:
            if value >= 5 { return .caution }
            if value <= 1.5 { return .safe }
            return .unknown
        case .readyMeal:
            if value >= 3 { return .caution }
            if value <= 1.5 { return .unknown }
            return .unknown
        default:
            if value >= 5 { return .caution }
            if value >= 1.5 { return .unknown }
            return .safe
        }
    }

    private func saltMetricSeverity(for value: Double) -> FlagSeverity {
        switch marketCategory {
        case .jam, .dryStaple, .yogurtOrDairy, .biscuitsOrSweets:
            return .unknown
        case .readyMeal, .sauceOrCondiment:
            if value >= 1.5 { return .caution }
            if value >= 0.3 { return .unknown }
            return .safe
        default:
            if value >= 1.5 { return .caution }
            if value >= 0.3 { return .unknown }
            return .unknown
        }
    }

    private func fiberMetricSeverity(for value: Double) -> FlagSeverity {
        switch marketCategory {
        case .dryStaple, .cereal:
            if value >= 6 { return .safe }
            if value >= 3 { return .safe }
            return .unknown
        default:
            return .unknown
        }
    }

    private func proteinMetricSeverity(for value: Double) -> FlagSeverity {
        switch marketCategory {
        case .yogurtOrDairy, .readyMeal:
            if value >= 10 { return .safe }
            if value >= 5 { return .safe }
            return .unknown
        case .dryStaple:
            return value >= 10 ? .safe : .unknown
        default:
            return .unknown
        }
    }

    private func ingredientNotice(for token: IngredientToken, allergens: [String]) -> String? {
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

    private func sugarTakeaway(for value: Double?) -> Takeaway? {
        guard let value else { return nil }

        switch marketCategory {
        case .sweetDrink where value >= 5:
            return Takeaway(text: "High sugar drink", severity: .caution, systemImage: "cube.box.fill")
        case .jam where value >= 22.5:
            return Takeaway(text: "High sugar", severity: .caution, systemImage: "cube.box.fill")
        case .biscuitsOrSweets where value >= 22.5:
            return Takeaway(text: "High sugar", severity: .caution, systemImage: "cube.box.fill")
        case .biscuitsOrSweets where value >= 10, .jam where value >= 10:
            return Takeaway(text: "Sugary product", severity: .unknown, systemImage: "cube.box.fill")
        case .yogurtOrDairy where value >= 10:
            return Takeaway(text: "Check sugar", severity: .caution, systemImage: "cube.box.fill")
        case .cereal where value >= 15:
            return Takeaway(text: "Compare sugar first", severity: .caution, systemImage: "cube.box.fill")
        case .sauceOrCondiment where value >= 10:
            return Takeaway(text: "Check sugar", severity: .caution, systemImage: "cube.box.fill")
        default:
            if value >= 22.5 {
                return Takeaway(text: "High sugar", severity: .caution, systemImage: "cube.box.fill")
            }

            if value >= 10 {
                return Takeaway(text: "Some sugar to notice", severity: .unknown, systemImage: "cube.box.fill")
            }

            return nil
        }
    }

    private func saturatedFatTakeaway(for value: Double?) -> Takeaway? {
        guard let value else { return nil }

        if marketCategory == .jam || marketCategory == .dryStaple || marketCategory == .sweetDrink {
            return nil
        }

        if value >= 5 {
            return Takeaway(text: "High sat. fat", severity: .caution, systemImage: "drop.fill")
        }

        if value >= 1.5 {
            return Takeaway(text: "Some sat. fat to notice", severity: .unknown, systemImage: "drop.fill")
        }

        return nil
    }

    private func saltTakeaway(for value: Double?) -> Takeaway? {
        guard let value else { return nil }

        if marketCategory == .jam || marketCategory == .dryStaple {
            return nil
        }

        if value >= 1.5 {
            return Takeaway(text: "High salt", severity: .caution, systemImage: "takeoutbag.and.cup.and.straw.fill")
        }

        if value >= 0.3 {
            return Takeaway(text: "Some salt to notice", severity: .unknown, systemImage: "takeoutbag.and.cup.and.straw.fill")
        }

        return nil
    }

    private func buildSwapRecommendation(
        for candidate: NormalizedProduct,
        using ingredientAnalyzer: IngredientAnalyzer
    ) -> SwapRecommendation? {
        let analyzedCandidate = ingredientAnalyzer.analyze(product: candidate)
        let comparison = comparisonReasons(for: analyzedCandidate)
        guard comparison.score > 0, !comparison.reasons.isEmpty else {
            return nil
        }

        return SwapRecommendation(
            analyzedProduct: analyzedCandidate,
            title: analyzedCandidate.product.name,
            subtitle: analyzedCandidate.product.brand,
            summary: comparison.summary,
            reasons: comparison.reasons,
            presentation: .recommended
        )
    }

    private func buildSimilarOption(
        for candidate: NormalizedProduct,
        using ingredientAnalyzer: IngredientAnalyzer
    ) -> SwapRecommendation? {
        let analyzedCandidate = ingredientAnalyzer.analyze(product: candidate)
        let reasons = comparisonSnapshotReasons(for: analyzedCandidate)
        guard !reasons.isEmpty else { return nil }

        return SwapRecommendation(
            analyzedProduct: analyzedCandidate,
            title: analyzedCandidate.product.name,
            subtitle: analyzedCandidate.product.brand,
            summary: "Same category. Compare the listed nutrition and ingredients before deciding.",
            reasons: reasons,
            presentation: .similar
        )
    }

    private func applyLocalFallbackRecommendations(using ingredientAnalyzer: IngredientAnalyzer) async -> LocalFallbackResult {
        let cachedProducts = await imageRepository.recentCachedProducts(limit: 24)
        let localCandidates = prioritizedRecommendationCandidates(
            comparableCachedProducts(from: cachedProducts)
        )

#if DEBUG
        print("[WIT Similar] local-fallback cached=\(cachedProducts.count) comparable=\(localCandidates.count)")
#endif

        let swapIdeas = localCandidates.compactMap { candidate in
            buildSwapRecommendation(for: candidate, using: ingredientAnalyzer)
        }

        if !swapIdeas.isEmpty {
#if DEBUG
            print("[WIT Similar] local-fallback swap-ideas=\(swapIdeas.count)")
#endif
            swapSectionTitle = "Compare with similar products"
            swapRecommendations = Array(swapIdeas.prefix(3))
            swapSectionStatusMessage = nil
            return .loaded
        }

        let similarOptions = localCandidates.compactMap { candidate in
            buildSimilarOption(for: candidate, using: ingredientAnalyzer)
        }

        if !similarOptions.isEmpty {
#if DEBUG
            print("[WIT Similar] local-fallback similar-options=\(similarOptions.count)")
#endif
            swapSectionTitle = "Compare with similar products"
            swapRecommendations = Array(similarOptions.prefix(3))
            swapSectionStatusMessage = nil
            return .loaded
        }

        return .unavailable(cachedCount: cachedProducts.count, comparableCount: localCandidates.count)
    }

    private func prioritizedRecommendationCandidates(_ candidates: [NormalizedProduct]) -> [NormalizedProduct] {
        let currentSubtypes = recommendationSubtypeKeywords(for: product)
        let scoredCandidates = candidates.map { candidate in
            ScoredRecommendationCandidate(
                product: candidate,
                subtypeOverlap: recommendationSubtypeOverlap(currentSubtypes: currentSubtypes, candidate: candidate),
                nutritionDistance: nutritionDistanceScore(for: candidate),
                additiveDistance: additiveDistanceScore(for: candidate)
            )
        }

        let filteredCandidates: [ScoredRecommendationCandidate]
        if !currentSubtypes.isEmpty,
           scoredCandidates.contains(where: { $0.subtypeOverlap > 0 }) {
            filteredCandidates = scoredCandidates.filter { $0.subtypeOverlap > 0 }
        } else {
            filteredCandidates = scoredCandidates
        }

        return filteredCandidates
            .sorted { lhs, rhs in
                if lhs.subtypeOverlap != rhs.subtypeOverlap {
                    return lhs.subtypeOverlap > rhs.subtypeOverlap
                }
                if lhs.nutritionDistance != rhs.nutritionDistance {
                    return lhs.nutritionDistance < rhs.nutritionDistance
                }
                if lhs.additiveDistance != rhs.additiveDistance {
                    return lhs.additiveDistance < rhs.additiveDistance
                }
                return normalized(lhs.product.name) < normalized(rhs.product.name)
            }
            .map(\.product)
    }

    private func localFallbackFailureMessage(
        for error: SimilarProductsLookupError,
        cachedCount: Int,
        comparableCount: Int
    ) -> String {
        if comparableCount == 0 {
            if cachedCount == 0 {
                return "\(error.errorDescription ?? "Similar products could not be loaded right now.") You do not have any recent scans saved locally yet."
            }

            return "\(error.errorDescription ?? "Similar products could not be loaded right now.") There are no comparable \(recommendationFamilyLabel) products in your recent scans yet."
        }

        return [error.errorDescription, error.recoverySuggestion]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    private func recommendationSubtypeKeywords(for candidate: NormalizedProduct) -> Set<String> {
        let family = recommendationFamily(for: candidate)
        guard family != .unknown else { return [] }

        let context = normalized(
            ([candidate.name] + candidate.categoryTags + [candidate.ingredientText])
                .joined(separator: " ")
        )

        switch family {
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

    private func matchedSubtypeKeywords(in context: String, groups: [(String, [String])]) -> Set<String> {
        Set(
            groups.compactMap { canonical, aliases in
                aliases.contains(where: context.contains) ? canonical : nil
            }
        )
    }

    private func recommendationSubtypeOverlap(currentSubtypes: Set<String>, candidate: NormalizedProduct) -> Int {
        guard !currentSubtypes.isEmpty else { return 0 }
        return currentSubtypes.intersection(recommendationSubtypeKeywords(for: candidate)).count
    }

    private func nutritionDistanceScore(for candidate: NormalizedProduct) -> Int {
        guard let currentNutrition = product.nutrition, let candidateNutrition = candidate.nutrition else {
            return Int.max / 2
        }

        var score = 0
        var comparisons = 0

        func addDistance(_ lhs: Double?, _ rhs: Double?, scale: Double) {
            guard let lhs, let rhs else { return }
            comparisons += 1
            score += Int(abs(lhs - rhs) * scale)
        }

        addDistance(currentNutrition.sugarsPer100g, candidateNutrition.sugarsPer100g, scale: 10)
        addDistance(currentNutrition.saturatedFatPer100g, candidateNutrition.saturatedFatPer100g, scale: 15)
        addDistance(currentNutrition.energyKcalPer100g, candidateNutrition.energyKcalPer100g, scale: 0.5)
        addDistance(currentNutrition.saltPer100g, candidateNutrition.saltPer100g, scale: 100)
        addDistance(currentNutrition.fiberPer100g, candidateNutrition.fiberPer100g, scale: 10)

        guard comparisons > 0 else { return Int.max / 2 }
        return score
    }

    private func additiveDistanceScore(for candidate: NormalizedProduct) -> Int {
        abs(candidate.additives.count - comparisonAdditiveCount)
    }

    private func comparableCachedProducts(from cachedProducts: [AnalyzedProduct]) -> [NormalizedProduct] {
        let currentBarcode = normalized(product.barcode ?? "")
        let currentName = normalized(product.name)
        let currentFamily = recommendationFamily
        let currentCategoryLabels = Set(specificNormalizedCategoryLabels(for: product))
        var seen: Set<String> = []

        return cachedProducts
            .map(\.product)
            .filter { candidate in
                guard candidate.category == .food else { return false }
                guard candidate.nutrition?.hasAnyValue == true else { return false }
                guard !candidate.isOCRBacked else { return false }

                let candidateBarcode = normalized(candidate.barcode ?? "")
                let candidateName = normalized(candidate.name)
                guard candidate.id != product.id else { return false }
                guard currentBarcode.isEmpty || candidateBarcode != currentBarcode else { return false }
                guard candidateName != currentName else { return false }

                let dedupeKey = [candidateBarcode, candidate.id, candidateName].first(where: { !$0.isEmpty }) ?? candidate.id
                guard seen.insert(dedupeKey).inserted else { return false }

                let candidateFamily = recommendationFamily(for: candidate)
                if currentFamily != .unknown {
                    return candidateFamily == currentFamily
                }

                if candidateFamily != .unknown {
                    return false
                }

                let candidateLabels = Set(specificNormalizedCategoryLabels(for: candidate))
                guard !currentCategoryLabels.isEmpty, !candidateLabels.isEmpty else { return false }
                return !currentCategoryLabels.isDisjoint(with: candidateLabels)
            }
    }

    private func specificNormalizedCategoryLabels(for candidate: NormalizedProduct) -> [String] {
        candidate.categoryTags
            .compactMap { tag in
                let rawValue = tag.split(separator: ":").last.map(String.init) ?? tag
                let humanized = rawValue.replacingOccurrences(of: "-", with: " ")
                let normalizedValue = normalized(humanized)
                return normalizedValue.isEmpty ? nil : normalizedValue
            }
            .filter { !isGenericLocalRecommendationCategoryLabel($0) }
    }

    private func isGenericLocalRecommendationCategoryLabel(_ label: String) -> Bool {
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

    private func comparisonReasons(for candidate: AnalyzedProduct) -> (score: Int, summary: String, reasons: [SwapReason]) {
        guard let currentNutrition = product.nutrition, let candidateNutrition = candidate.product.nutrition else {
            return (0, "", [])
        }

        var reasons: [SwapReason] = []
        var score = 0
        var penalty = 0

        if let currentSugar = currentNutrition.sugarsPer100g, let candidateSugar = candidateNutrition.sugarsPer100g {
            let delta = currentSugar - candidateSugar
            if delta >= 5 {
                reasons.append(
                    SwapReason(
                        text: "\(Self.formattedValue(delta, unit: "g")) less sugar",
                        systemImage: "cube.box.fill",
                        severity: .safe
                    )
                )
                score += 4
            } else if delta >= 3, currentSugar >= 20 {
                reasons.append(
                    SwapReason(
                        text: "\(Self.formattedValue(delta, unit: "g")) less sugar",
                        systemImage: "cube.box.fill",
                        severity: .safe
                    )
                )
                score += 2
            } else if delta <= -5 {
                penalty += 4
            }
        }

        if let currentSatFat = currentNutrition.saturatedFatPer100g, let candidateSatFat = candidateNutrition.saturatedFatPer100g {
            let delta = currentSatFat - candidateSatFat
            if delta >= 1.5 {
                reasons.append(
                    SwapReason(
                        text: "\(Self.formattedValue(delta, unit: "g")) less sat. fat",
                        systemImage: "drop.fill",
                        severity: .safe
                    )
                )
                score += 3
            } else if delta >= 1, currentSatFat >= 3 {
                reasons.append(
                    SwapReason(
                        text: "\(Self.formattedValue(delta, unit: "g")) less sat. fat",
                        systemImage: "drop.fill",
                        severity: .safe
                    )
                )
                score += 2
            } else if delta <= -1.5 {
                penalty += 3
            }
        }

        let candidateAdditives = max(
            candidate.product.additives.count,
            candidate.ingredients.flatMap(\.flags).filter { $0.kind == .additive }.count
        )
        let additiveDelta = comparisonAdditiveCount - candidateAdditives
        if additiveDelta >= 1 {
            reasons.append(
                SwapReason(
                    text: additiveDelta == 1 ? "Fewer additives" : "\(additiveDelta) fewer additives",
                    systemImage: "sparkles.rectangle.stack.fill",
                    severity: .safe
                )
            )
            score += 2
        } else if additiveDelta <= -2 {
            penalty += 2
        }

        if let currentFiber = currentNutrition.fiberPer100g, let candidateFiber = candidateNutrition.fiberPer100g {
            let delta = candidateFiber - currentFiber
            if delta >= 2 {
                reasons.append(
                    SwapReason(
                        text: "\(Self.formattedValue(delta, unit: "g")) more fiber",
                        systemImage: "leaf.fill",
                        severity: .safe
                    )
                )
                score += 1
            }
        }

        if let currentSalt = currentNutrition.saltPer100g, let candidateSalt = candidateNutrition.saltPer100g {
            let delta = currentSalt - candidateSalt
            if delta >= 0.3, reasons.count < 3 {
                reasons.append(
                    SwapReason(
                        text: "\(Self.formattedValue(delta, unit: "g")) less salt",
                        systemImage: "takeoutbag.and.cup.and.straw.fill",
                        severity: .safe
                    )
                )
                score += 1
            } else if delta <= -0.3 {
                penalty += 1
            }
        }

        guard score > penalty else {
            return (0, "", [])
        }

        let reasonTexts = reasons.prefix(2).map { $0.text.lowercased() }
        let summary: String
        if reasonTexts.count >= 2 {
            summary = "Same category · \(reasonTexts[0]) and \(reasonTexts[1])."
        } else if let first = reasonTexts.first {
            summary = "Same category · \(first)."
        } else {
            summary = ""
        }

        return (score - penalty, summary, Array(reasons.prefix(3)))
    }

    private func comparisonSnapshotReasons(for candidate: AnalyzedProduct) -> [SwapReason] {
        guard let nutrition = candidate.product.nutrition else { return [] }

        var reasons: [SwapReason] = []

        if let sugar = nutrition.sugarsPer100g {
            reasons.append(
                SwapReason(
                    text: "\(Self.formattedValue(sugar, unit: "g")) sugar",
                    systemImage: "cube.box.fill",
                    severity: sugar >= 22.5 ? .caution : .unknown
                )
            )
        }

        if let saturatedFat = nutrition.saturatedFatPer100g {
            reasons.append(
                SwapReason(
                    text: "\(Self.formattedValue(saturatedFat, unit: "g")) sat. fat",
                    systemImage: "drop.fill",
                    severity: saturatedFat >= 5 ? .caution : .unknown
                )
            )
        }

        let candidateAdditives = max(
            candidate.product.additives.count,
            candidate.ingredients.flatMap(\.flags).filter { $0.kind == .additive }.count
        )
        reasons.append(
            SwapReason(
                text: candidateAdditives == 0 ? "No additive flags" : (candidateAdditives == 1 ? "1 additive flag" : "\(candidateAdditives) additive flags"),
                systemImage: "sparkles.rectangle.stack.fill",
                severity: candidateAdditives == 0 ? .safe : .unknown
            )
        )

        return Array(reasons.prefix(3))
    }

    private var meaningfulFiberTakeaway: Takeaway? {
        guard let fiber = nutrition?.fiberPer100g, fiber >= 3 else { return nil }

        switch marketCategory {
        case .dryStaple, .cereal:
            return Takeaway(
                text: fiber >= 6 ? "Good fiber" : "Useful fiber",
                severity: .safe,
                systemImage: "leaf.fill"
            )
        default:
            return nil
        }
    }

    private var proteinTakeaway: Takeaway? {
        guard let protein = nutrition?.proteinPer100g else { return nil }

        switch marketCategory {
        case .yogurtOrDairy, .readyMeal:
            if protein >= 10 {
                return Takeaway(text: "Strong protein", severity: .safe, systemImage: "bolt.heart.fill")
            }
            if protein >= 5 {
                return Takeaway(text: "Protein amount", severity: .unknown, systemImage: "bolt.heart.fill")
            }
            return nil
        default:
            return nil
        }
    }

    private var containsFruitPectin: Bool {
        ingredients.contains { token in
            let text = token.normalizedText
            return text.contains("pectine") || text.contains("pectin")
        }
    }

    private var noSaltOrFatConcernTakeaway: Takeaway? {
        guard marketCategory == .jam else { return nil }
        let lowSalt = (nutrition?.saltPer100g ?? 0) <= 0.3
        let lowSatFat = (nutrition?.saturatedFatPer100g ?? 0) <= 1.5
        guard lowSalt && lowSatFat else { return nil }

        return Takeaway(
            text: "No salt/fat concern",
            severity: .safe,
            systemImage: "checkmark.circle.fill"
        )
    }

    private var containsSweetenerIngredient: Bool {
        ingredients.contains { token in
            let text = token.normalizedText
            return text.contains("sweetener") || text.contains("sucralose") || text.contains("aspartame") || text.contains("acesulfame") || text.contains("stevia")
        }
    }

    private var isWholegrainProduct: Bool {
        let context = normalized(([product.name] + ingredients.map(\.normalizedText)).joined(separator: " "))
        return matchesAny(of: ["wholegrain", "whole grain", "wholemeal", "complet", "complete"], in: context)
    }

    private var sourceSummaryText: String {
        switch product.source {
        case .openFoodFacts:
            return "Open Food Facts"
        case .openBeautyFacts:
            return "Open Beauty Facts"
        case .usda:
            return "USDA"
        case .ocr:
            return "Label photo"
        case .cache:
            return "Recent scan cache"
        }
    }

    private var ingredientsSourceText: String {
        switch product.ingredientsProvenance {
        case .api:
            return "Product database"
        case .ocr:
            return "Label photo"
        case .glossary:
            return "Offline glossary match"
        case .inferred:
            return "Rule-based ingredient match"
        }
    }

    private var nutritionSourceText: String? {
        guard nutrition?.hasAnyValue == true else { return nil }

        switch product.source {
        case .openFoodFacts, .openBeautyFacts, .usda:
            return "Product database"
        case .ocr:
            return "Matched product record when available"
        case .cache:
            return "Saved product record"
        }
    }

    private var ocrConfidenceText: String? {
        guard product.isOCRBacked else { return nil }
        return ocrConfidenceLabel.map { "\($0). Review the label if something looks off." } ?? "Review the label if something looks off."
    }

    private var sourceReviewNote: String? {
        if product.source == .usda {
            return "Ingredients may be limited in the USDA fallback record."
        }

        if product.isOCRBacked {
            return "Some words may be wrong. Check the label if something looks unusual."
        }

        return nil
    }

    private func compactWhatItIs(for token: IngredientToken) -> String {
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

    private func compactRoleLabel(for token: IngredientToken, position: Int) -> String {
        let normalizedToken = token.normalizedText

        if normalizedToken.contains("pectine") || normalizedToken.contains("pectin") {
            return "gelling agent"
        }

        if matchesAny(of: ["jus de citron", "lemon juice", "citric"], in: normalizedToken) {
            return "acidity"
        }

        if matchesAny(of: ["sucre", "sugar", "sirop", "syrup", "miel", "honey"], in: normalizedToken) {
            return "sweetener"
        }

        if matchesAny(of: ["farine", "flour"], in: normalizedToken) {
            return isWholegrainProduct ? "wholegrain flour" : "flour"
        }

        if position == 0, matchesAny(of: ["fig", "figue", "fraise", "strawberry", "fruit", "framboise", "raspberry", "abricot", "apricot"], in: normalizedToken) {
            return "fruit base"
        }

        if let function = token.explanation?.function {
            let loweredFunction = normalized(function)
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

    private func normalizedRoleLabel(_ value: String) -> String {
        let cleaned = value
            .replacingOccurrences(of: ".", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = cleaned.first else { return "ingredient" }
        return first.lowercased() + cleaned.dropFirst()
    }

    private func compactWhyItMatters(for token: IngredientToken, allergens: [String]) -> String? {
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

    private func compactRole(for token: IngredientToken, position: Int) -> String? {
        let function = token.supportingSummary

        if function == "Tap for more context." {
            return position == 0 ? primaryIngredientLabel : nil
        }

        if function.contains("Ingredient details were inferred from the label text")
            || function.contains("No trusted match was available")
            || function.contains("deterministic keyword rules")
        {
            return position == 0 ? primaryIngredientLabel : nil
        }

        if function.contains("simple whole-food or spice ingredient") {
            return position == 0 ? primaryIngredientLabel : "Simple food ingredient."
        }

        return function
    }

    private var primaryIngredientLabel: String {
        ingredients.count == 1 ? "Main ingredient." : "Primary ingredient."
    }

    private func heuristicSummary(for normalizedToken: String) -> String? {
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

    private func allergenMentions(for token: IngredientToken) -> [String] {
        guard token.flags.contains(where: { $0.kind == .allergen }) else { return [] }

        let haystack = normalized(
            ([token.normalizedText] + product.allergens.map(normalized))
                .joined(separator: " ")
        )

        var values: [String] = []

        if haystack.contains("wheat") || haystack.contains("gluten") {
            values.append("wheat / gluten")
        }

        if matchesAny(of: ["milk", "lactose", "whey"], in: haystack) {
            values.append("milk")
        }

        if haystack.contains("soy") {
            values.append("soy")
        }

        if haystack.contains("peanut") {
            values.append("peanut")
        }

        if matchesAny(of: ["almond", "cashew", "hazelnut", "walnut", "tree nut"], in: haystack) {
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

        if matchesAny(of: ["sulfites", "sulphites"], in: haystack) {
            values.append("sulfites")
        }

        if values.isEmpty {
            values.append("common allergen")
        }

        return values
    }

    private func beautyMarkerCount(_ marker: AnalysisMarker) -> Int {
        ingredients.flatMap(\.flags).filter { $0.kind == marker }.count
    }

    private func uniqueTakeaways(_ items: [Takeaway]) -> [Takeaway] {
        var seen: Set<String> = []
        return items.filter { item in
            let inserted = seen.insert(item.text).inserted
            return inserted
        }
    }

    private func matchesAny(of candidates: [String], in text: String) -> Bool {
        candidates.contains(where: text.contains)
    }

    private func normalized(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    private static func formattedValue(_ value: Double, unit: String, decimals: Int = 1) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = decimals == 0 ? 0 : (value.rounded() == value ? 0 : 1)
        formatter.maximumFractionDigits = decimals
        let number = formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(decimals)f", value)
        return "\(number)\(unit)"
    }
}
