//
//  CategoryInsightProvider.swift
//  whatsinthis
//
//  Created by Codex on 02/05/2026.
//

import Foundation

struct CategoryInsightProvider {
    struct Context: Hashable {
        let marketCategory: ProductMarketCategory
        let leadingAllergenText: String?
        let unknownCount: Int
        let cautionCount: Int
        let additiveCount: Int
        let ingredientCount: Int
        let hasFruitPectin: Bool
        let hasSweetenerIngredient: Bool
        let isWholegrain: Bool
        let isOCRBacked: Bool
        let beautyFragranceCount: Int
        let beautyPreservativeCount: Int
        let beautySurfactantCount: Int
        let nutrition: NutritionSnapshot?
    }

    struct DisplayItem: Hashable {
        let text: String
        let severity: FlagSeverity
        let systemImage: String
    }

    struct HeaderStatus: Hashable {
        let title: String
        let subtitle: String
        let severity: FlagSeverity
    }

    struct ComparisonItem: Hashable {
        let text: String
        let systemImage: String
    }

    struct NutritionMetric: Hashable {
        let title: String
        let valueText: String
        let severity: FlagSeverity
        let systemImage: String
    }

    struct NutritionInsight: Hashable {
        let title: String
        let subtitle: String
        let valueText: String
        let systemImage: String
        let severity: FlagSeverity
    }

    static func headerStatus(for context: Context) -> HeaderStatus {
        if context.marketCategory == .beauty {
            return beautyHeaderStatus(for: context)
        }

        if let allergenText = context.leadingAllergenText {
            return HeaderStatus(
                title: allergenText,
                subtitle: allergenText == "Contains wheat / gluten" && context.marketCategory == .dryStaple
                    ? "Common allergen. Expected for this product type."
                    : "Common allergen. Check if avoiding it.",
                severity: .caution
            )
        }

        if let marketStatus = marketHeaderStatus(for: context) {
            return marketStatus
        }

        if context.additiveCount > 0 {
            return HeaderStatus(
                title: "Additives found",
                subtitle: "Compare additives if you are choosing between similar products.",
                severity: .caution
            )
        }

        if context.unknownCount > 0 {
            return HeaderStatus(
                title: "Label explained",
                subtitle: "Check the highlighted items before deciding.",
                severity: .unknown
            )
        }

        if context.isOCRBacked {
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

    static func comparisonItems(for context: Context) -> [ComparisonItem] {
        ProductCategoryResolver.comparisonCriteria(for: context.marketCategory).map { text in
            ComparisonItem(text: text, systemImage: comparisonSymbol(for: text))
        }
    }

    static func takeaways(for context: Context) -> [DisplayItem] {
        var items: [DisplayItem] = []

        switch context.marketCategory {
        case .jam:
            if let sugar = context.nutrition?.sugarsPer100g {
                items.append(DisplayItem(
                    text: "\(ProductDetailFormatting.formattedValue(sugar, unit: "g")) sugar / 100g",
                    severity: sugar >= 22.5 ? .caution : .unknown,
                    systemImage: "cube.box.fill"
                ))
            }
            if context.hasFruitPectin {
                items.append(DisplayItem(text: "Contains fruit pectin", severity: .safe, systemImage: "leaf.fill"))
            }
            if let simple = simpleIngredientListTakeaway(for: context) {
                items.append(simple)
            }
            if let noConcern = noSaltOrFatConcernTakeaway(for: context) {
                items.append(noConcern)
            }
        case .dryStaple:
            if let allergen = leadingAllergenTakeaway(for: context.leadingAllergenText) {
                items.append(allergen)
            }
            if let fiber = meaningfulFiberTakeaway(for: context) {
                items.append(fiber)
            }
            items.append(DisplayItem(text: "Dry staple", severity: .unknown, systemImage: "shippingbox.fill"))
            if let simple = simpleIngredientListTakeaway(for: context) {
                items.append(simple)
            }
        case .yogurtOrDairy:
            if let sugar = sugarTakeaway(for: context.nutrition?.sugarsPer100g, category: context.marketCategory) {
                items.append(sugar)
            }
            if let protein = proteinTakeaway(for: context) {
                items.append(protein)
            }
            if let saturatedFat = saturatedFatTakeaway(for: context.nutrition?.saturatedFatPer100g, category: context.marketCategory) {
                items.append(saturatedFat)
            }
            if context.additiveCount > 0 {
                items.append(DisplayItem(text: "Additives found", severity: .caution, systemImage: "sparkles.rectangle.stack.fill"))
            }
        case .cereal:
            if let sugar = sugarTakeaway(for: context.nutrition?.sugarsPer100g, category: context.marketCategory) {
                items.append(sugar)
            }
            if let fiber = meaningfulFiberTakeaway(for: context) {
                items.append(fiber)
            }
            if context.additiveCount > 0 {
                items.append(DisplayItem(text: "Additives found", severity: .caution, systemImage: "sparkles.rectangle.stack.fill"))
            }
        case .sweetDrink:
            if let sugar = sugarTakeaway(for: context.nutrition?.sugarsPer100g, category: context.marketCategory) {
                items.append(sugar)
            }
            if context.hasSweetenerIngredient {
                items.append(DisplayItem(text: "Sweeteners listed", severity: .unknown, systemImage: "sparkles"))
            }
            if context.additiveCount > 0 {
                items.append(DisplayItem(text: "Additives found", severity: .caution, systemImage: "sparkles.rectangle.stack.fill"))
            }
        case .biscuitsOrSweets:
            if let sugar = sugarTakeaway(for: context.nutrition?.sugarsPer100g, category: context.marketCategory) {
                items.append(sugar)
            }
            if let saturatedFat = saturatedFatTakeaway(for: context.nutrition?.saturatedFatPer100g, category: context.marketCategory) {
                items.append(saturatedFat)
            }
            if context.additiveCount > 0 {
                items.append(DisplayItem(text: "Additives found", severity: .caution, systemImage: "sparkles.rectangle.stack.fill"))
            }
        case .sauceOrCondiment:
            if let salt = saltTakeaway(for: context.nutrition?.saltPer100g, category: context.marketCategory) {
                items.append(salt)
            }
            if let sugar = sugarTakeaway(for: context.nutrition?.sugarsPer100g, category: context.marketCategory) {
                items.append(sugar)
            }
            if context.additiveCount > 0 {
                items.append(DisplayItem(text: "Additives found", severity: .caution, systemImage: "sparkles.rectangle.stack.fill"))
            }
        case .readyMeal:
            if let salt = saltTakeaway(for: context.nutrition?.saltPer100g, category: context.marketCategory) {
                items.append(salt)
            }
            if let saturatedFat = saturatedFatTakeaway(for: context.nutrition?.saturatedFatPer100g, category: context.marketCategory) {
                items.append(saturatedFat)
            }
            if let protein = proteinTakeaway(for: context) {
                items.append(protein)
            }
        case .beauty:
            if context.beautyFragranceCount > 0 {
                items.append(DisplayItem(text: "Fragrance ingredients found", severity: .caution, systemImage: "sparkles"))
            }
            if context.beautyPreservativeCount > 0 {
                items.append(DisplayItem(text: "Preservatives listed", severity: .unknown, systemImage: "shield.lefthalf.filled"))
            }
            if context.beautySurfactantCount > 0 {
                items.append(DisplayItem(text: "Cleansing ingredients found", severity: .unknown, systemImage: "drop.fill"))
            }
        case .unknown:
            if let allergen = leadingAllergenTakeaway(for: context.leadingAllergenText) {
                items.append(allergen)
            }
            if context.additiveCount > 0 {
                items.append(DisplayItem(text: "Additives found", severity: .caution, systemImage: "sparkles.rectangle.stack.fill"))
            }
            if context.unknownCount > 0 {
                items.append(DisplayItem(text: "Some terms need more context", severity: .unknown, systemImage: "questionmark.circle.fill"))
            }
            if items.isEmpty {
                items.append(DisplayItem(text: "Label explained", severity: .safe, systemImage: "checkmark.circle.fill"))
            }
        }

        if items.count < 3, context.isOCRBacked {
            items.append(DisplayItem(text: "Review label text if something looks wrong", severity: .unknown, systemImage: "text.viewfinder"))
        }

        return unique(items)
    }

    static func summaryChips(for context: Context) -> [DisplayItem] {
        var chips: [DisplayItem] = [
            DisplayItem(
                text: context.ingredientCount == 1 ? "1 item" : "\(context.ingredientCount) items",
                severity: .unknown,
                systemImage: "list.bullet"
            )
        ]

        switch context.marketCategory {
        case .jam:
            if let sugar = context.nutrition?.sugarsPer100g {
                chips.append(DisplayItem(
                    text: "\(ProductDetailFormatting.formattedValue(sugar, unit: "g")) sugar / 100g",
                    severity: sugarMetricSeverity(for: sugar, category: context.marketCategory),
                    systemImage: "cube.box.fill"
                ))
            }
            if context.hasFruitPectin {
                chips.append(DisplayItem(text: "Fruit pectin", severity: .safe, systemImage: "leaf.fill"))
            }
        case .dryStaple:
            if let fiber = context.nutrition?.fiberPer100g, fiber >= 3 {
                chips.append(DisplayItem(
                    text: "\(ProductDetailFormatting.formattedValue(fiber, unit: "g")) fiber",
                    severity: .safe,
                    systemImage: "leaf.fill"
                ))
            }
            if context.isWholegrain {
                chips.append(DisplayItem(text: "Wholegrain", severity: .safe, systemImage: "circle.grid.2x2.fill"))
            }
        case .yogurtOrDairy:
            if let sugar = context.nutrition?.sugarsPer100g {
                chips.append(DisplayItem(text: "\(ProductDetailFormatting.formattedValue(sugar, unit: "g")) sugar", severity: sugarMetricSeverity(for: sugar, category: context.marketCategory), systemImage: "cube.box.fill"))
            }
            if let protein = context.nutrition?.proteinPer100g {
                chips.append(DisplayItem(text: "\(ProductDetailFormatting.formattedValue(protein, unit: "g")) protein", severity: proteinMetricSeverity(for: protein, category: context.marketCategory), systemImage: "bolt.heart.fill"))
            }
        case .cereal:
            if let sugar = context.nutrition?.sugarsPer100g {
                chips.append(DisplayItem(text: "\(ProductDetailFormatting.formattedValue(sugar, unit: "g")) sugar", severity: sugarMetricSeverity(for: sugar, category: context.marketCategory), systemImage: "cube.box.fill"))
            }
            if let fiber = context.nutrition?.fiberPer100g {
                chips.append(DisplayItem(text: "\(ProductDetailFormatting.formattedValue(fiber, unit: "g")) fiber", severity: fiberMetricSeverity(for: fiber, category: context.marketCategory), systemImage: "leaf.fill"))
            }
        case .sweetDrink:
            if let sugar = context.nutrition?.sugarsPer100g {
                chips.append(DisplayItem(text: "\(ProductDetailFormatting.formattedValue(sugar, unit: "g")) sugar", severity: sugarMetricSeverity(for: sugar, category: context.marketCategory), systemImage: "cube.box.fill"))
            }
        case .biscuitsOrSweets:
            if let sugar = context.nutrition?.sugarsPer100g {
                chips.append(DisplayItem(text: "\(ProductDetailFormatting.formattedValue(sugar, unit: "g")) sugar", severity: sugarMetricSeverity(for: sugar, category: context.marketCategory), systemImage: "cube.box.fill"))
            }
            if let saturatedFat = context.nutrition?.saturatedFatPer100g {
                chips.append(DisplayItem(text: "\(ProductDetailFormatting.formattedValue(saturatedFat, unit: "g")) sat. fat", severity: saturatedFatMetricSeverity(for: saturatedFat, category: context.marketCategory), systemImage: "drop.fill"))
            }
        case .sauceOrCondiment:
            if let salt = context.nutrition?.saltPer100g {
                chips.append(DisplayItem(text: "\(ProductDetailFormatting.formattedValue(salt, unit: "g")) salt", severity: saltMetricSeverity(for: salt, category: context.marketCategory), systemImage: "takeoutbag.and.cup.and.straw.fill"))
            }
            if let sugar = context.nutrition?.sugarsPer100g {
                chips.append(DisplayItem(text: "\(ProductDetailFormatting.formattedValue(sugar, unit: "g")) sugar", severity: sugarMetricSeverity(for: sugar, category: context.marketCategory), systemImage: "cube.box.fill"))
            }
        case .readyMeal:
            if let salt = context.nutrition?.saltPer100g {
                chips.append(DisplayItem(text: "\(ProductDetailFormatting.formattedValue(salt, unit: "g")) salt", severity: saltMetricSeverity(for: salt, category: context.marketCategory), systemImage: "takeoutbag.and.cup.and.straw.fill"))
            }
            if let protein = context.nutrition?.proteinPer100g {
                chips.append(DisplayItem(text: "\(ProductDetailFormatting.formattedValue(protein, unit: "g")) protein", severity: proteinMetricSeverity(for: protein, category: context.marketCategory), systemImage: "bolt.heart.fill"))
            }
        case .beauty:
            if context.beautyFragranceCount > 0 {
                chips.append(DisplayItem(text: "Fragrance", severity: .caution, systemImage: "sparkles"))
            }
            if context.beautyPreservativeCount > 0 {
                chips.append(DisplayItem(text: "Preservatives", severity: .unknown, systemImage: "shield.lefthalf.filled"))
            }
        case .unknown:
            if context.cautionCount > 0 {
                chips.append(DisplayItem(text: "\(context.cautionCount) to check", severity: .caution, systemImage: "exclamationmark.circle.fill"))
            } else if context.unknownCount > 0 {
                let label = context.unknownCount == 1 ? "1 item needs context" : "\(context.unknownCount) items need context"
                chips.append(DisplayItem(text: label, severity: .unknown, systemImage: "questionmark.circle.fill"))
            }
        }

        return chips
    }

    static func nutritionMetrics(for context: Context) -> [NutritionMetric] {
        guard let nutrition = context.nutrition else { return [] }

        var metrics: [NutritionMetric] = []

        if let calories = nutrition.energyKcalPer100g {
            metrics.append(
                NutritionMetric(
                    title: "Calories",
                    valueText: ProductDetailFormatting.formattedValue(calories, unit: "Cal", decimals: 0),
                    severity: caloriesMetricSeverity(for: calories, category: context.marketCategory),
                    systemImage: "flame.fill"
                )
            )
        }
        if let sugar = nutrition.sugarsPer100g {
            metrics.append(
                NutritionMetric(
                    title: "Sugar",
                    valueText: ProductDetailFormatting.formattedValue(sugar, unit: "g"),
                    severity: sugarMetricSeverity(for: sugar, category: context.marketCategory),
                    systemImage: "cube.box.fill"
                )
            )
        }
        if let saturatedFat = nutrition.saturatedFatPer100g {
            metrics.append(
                NutritionMetric(
                    title: "Sat. fat",
                    valueText: ProductDetailFormatting.formattedValue(saturatedFat, unit: "g"),
                    severity: saturatedFatMetricSeverity(for: saturatedFat, category: context.marketCategory),
                    systemImage: "drop.fill"
                )
            )
        }
        if let salt = nutrition.saltPer100g {
            metrics.append(
                NutritionMetric(
                    title: "Salt",
                    valueText: ProductDetailFormatting.formattedValue(salt, unit: "g"),
                    severity: saltMetricSeverity(for: salt, category: context.marketCategory),
                    systemImage: "takeoutbag.and.cup.and.straw.fill"
                )
            )
        }
        if let fiber = nutrition.fiberPer100g {
            metrics.append(
                NutritionMetric(
                    title: "Fiber",
                    valueText: ProductDetailFormatting.formattedValue(fiber, unit: "g"),
                    severity: fiberMetricSeverity(for: fiber, category: context.marketCategory),
                    systemImage: "leaf.fill"
                )
            )
        }
        if let protein = nutrition.proteinPer100g {
            metrics.append(
                NutritionMetric(
                    title: "Protein",
                    valueText: ProductDetailFormatting.formattedValue(protein, unit: "g"),
                    severity: proteinMetricSeverity(for: protein, category: context.marketCategory),
                    systemImage: "bolt.heart.fill"
                )
            )
        }

        return metrics
    }

    static func negativeNutritionInsights(for context: Context) -> [NutritionInsight] {
        guard let nutrition = context.nutrition else { return [] }

        return [
            caloriesInsight(for: nutrition.energyKcalPer100g, category: context.marketCategory),
            sugarInsight(for: nutrition.sugarsPer100g, category: context.marketCategory),
            saturatedFatInsight(for: nutrition.saturatedFatPer100g, category: context.marketCategory),
            saltInsight(for: nutrition.saltPer100g, category: context.marketCategory)
        ].compactMap { $0 }
    }

    static func positiveNutritionInsights(for context: Context) -> [NutritionInsight] {
        guard let nutrition = context.nutrition else { return [] }

        var insights: [NutritionInsight] = []
        if (context.marketCategory == .dryStaple || context.marketCategory == .cereal),
           let fiber = nutrition.fiberPer100g,
           fiber >= 3 {
            insights.append(
                NutritionInsight(
                    title: "Fiber",
                    subtitle: fiber >= 6 ? "Good fiber for this type of product." : "Useful fiber for this category.",
                    valueText: ProductDetailFormatting.formattedValue(fiber, unit: "g"),
                    systemImage: "leaf.fill",
                    severity: .safe
                )
            )
        }

        if (context.marketCategory == .yogurtOrDairy || context.marketCategory == .readyMeal),
           let protein = nutrition.proteinPer100g,
           protein >= 5 {
            insights.append(
                NutritionInsight(
                    title: "Protein",
                    subtitle: protein >= 10 ? "Strong protein level for this category." : "Useful protein for this category.",
                    valueText: ProductDetailFormatting.formattedValue(protein, unit: "g"),
                    systemImage: "bolt.heart.fill",
                    severity: .safe
                )
            )
        }

        if (context.marketCategory == .cereal || context.marketCategory == .yogurtOrDairy),
           let sugar = nutrition.sugarsPer100g,
           sugar <= 5 {
            insights.append(
                NutritionInsight(
                    title: "Sugar",
                    subtitle: "Low sugar for this category.",
                    valueText: ProductDetailFormatting.formattedValue(sugar, unit: "g"),
                    systemImage: "cube.box.fill",
                    severity: .safe
                )
            )
        }

        return insights
    }

    private static func beautyHeaderStatus(for context: Context) -> HeaderStatus {
        if context.beautyFragranceCount > 0 {
            return HeaderStatus(
                title: "Check sensitive-skin markers",
                subtitle: "Fragrance ingredients are listed in the formula.",
                severity: .caution
            )
        }

        if context.beautyPreservativeCount > 0 || context.beautySurfactantCount > 0 {
            return HeaderStatus(
                title: "Check sensitive-skin markers",
                subtitle: "Look for preservatives, alcohol, fragrance, or silicones before deciding.",
                severity: .unknown
            )
        }

        if context.isOCRBacked {
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

    private static func marketHeaderStatus(for context: Context) -> HeaderStatus? {
        switch context.marketCategory {
        case .jam:
            return HeaderStatus(
                title: jamHeadline(for: context),
                subtitle: "Compare sugar and fruit content if choosing between jars.",
                severity: sugarMetricSeverity(for: context.nutrition?.sugarsPer100g ?? 0, category: context.marketCategory) == .caution ? .caution : .unknown
            )
        case .dryStaple:
            return HeaderStatus(
                title: "Energy-dense dry staple.",
                subtitle: context.leadingAllergenText == nil ? "Check mainly if avoiding wheat or gluten." : "Common allergen. Expected for this product type.",
                severity: context.leadingAllergenText == nil ? .unknown : .caution
            )
        case .yogurtOrDairy:
            return HeaderStatus(
                title: "Check sugar and protein.",
                subtitle: "Plain yogurts are usually easier to compare.",
                severity: (context.nutrition?.sugarsPer100g ?? 0) >= 10 ? .caution : .unknown
            )
        case .cereal:
            return HeaderStatus(
                title: "Compare sugar and fiber first.",
                subtitle: "Higher fiber and lower sugar usually make cereals easier to choose.",
                severity: (context.nutrition?.sugarsPer100g ?? 0) >= 15 ? .caution : .unknown
            )
        case .sweetDrink:
            if let sugar = context.nutrition?.sugarsPer100g, sugar >= 5 {
                return HeaderStatus(
                    title: "High sugar drink.",
                    subtitle: "Compare sugar per 100 ml and sweeteners.",
                    severity: .caution
                )
            }

            if context.hasSweetenerIngredient {
                return HeaderStatus(
                    title: "Sweetened drink.",
                    subtitle: "Compare sugar per 100 ml and sweeteners.",
                    severity: .unknown
                )
            }

            return HeaderStatus(
                title: "Drink to compare.",
                subtitle: "Compare sugar per 100 ml and sweeteners.",
                severity: .unknown
            )
        case .biscuitsOrSweets:
            return HeaderStatus(
                title: "Sweet snack.",
                subtitle: "Compare sugar, saturated fat, and additives.",
                severity: (context.nutrition?.sugarsPer100g ?? 0) >= 22.5 || (context.nutrition?.saturatedFatPer100g ?? 0) >= 5 ? .caution : .unknown
            )
        case .sauceOrCondiment:
            return HeaderStatus(
                title: "Check salt and sugar.",
                subtitle: "Small portions can still add up.",
                severity: max(context.nutrition?.saltPer100g ?? 0, context.nutrition?.sugarsPer100g ?? 0) > 0.6 ? .caution : .unknown
            )
        case .readyMeal:
            return HeaderStatus(
                title: "Check salt, sat. fat, and protein.",
                subtitle: "Ready meals vary a lot by nutrition balance.",
                severity: (context.nutrition?.saltPer100g ?? 0) >= 0.6 || (context.nutrition?.saturatedFatPer100g ?? 0) >= 3 ? .caution : .unknown
            )
        case .beauty, .unknown:
            return nil
        }
    }

    private static func jamHeadline(for context: Context) -> String {
        if let sugar = context.nutrition?.sugarsPer100g, sugar >= 22.5 {
            return "High sugar, typical for jam."
        }
        if let sugar = context.nutrition?.sugarsPer100g, sugar > 0 {
            return "Sweet preserve."
        }
        return "Jam or fruit preserve."
    }

    private static func comparisonSymbol(for text: String) -> String {
        switch ProductDetailFormatting.normalized(text) {
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

    private static func leadingAllergenTakeaway(for leadingAllergenText: String?) -> DisplayItem? {
        guard let value = leadingAllergenValue(from: leadingAllergenText) else { return nil }
        let text = value == "wheat / gluten" ? "Check if avoiding gluten" : "Check if avoiding \(value)"
        return DisplayItem(text: text, severity: .caution, systemImage: "exclamationmark.circle.fill")
    }

    private static func leadingAllergenValue(from leadingAllergenText: String?) -> String? {
        guard let leadingAllergenText else { return nil }
        let prefix = "Contains "
        guard leadingAllergenText.hasPrefix(prefix) else { return nil }
        return String(leadingAllergenText.dropFirst(prefix.count))
    }

    private static func simpleIngredientListTakeaway(for context: Context) -> DisplayItem? {
        guard context.unknownCount == 0 else { return nil }
        if context.ingredientCount == 1 {
            return DisplayItem(text: "Simple ingredient list", severity: .safe, systemImage: "checkmark.circle.fill")
        }
        if context.ingredientCount <= 4 && context.cautionCount <= 1 {
            return DisplayItem(text: "Simple ingredient list", severity: .safe, systemImage: "checkmark.circle.fill")
        }
        return nil
    }

    private static func noSaltOrFatConcernTakeaway(for context: Context) -> DisplayItem? {
        guard context.marketCategory == .jam else { return nil }
        let lowSalt = (context.nutrition?.saltPer100g ?? 0) <= 0.3
        let lowSatFat = (context.nutrition?.saturatedFatPer100g ?? 0) <= 1.5
        guard lowSalt && lowSatFat else { return nil }
        return DisplayItem(text: "No salt/fat concern", severity: .safe, systemImage: "checkmark.circle.fill")
    }

    private static func meaningfulFiberTakeaway(for context: Context) -> DisplayItem? {
        guard let fiber = context.nutrition?.fiberPer100g, fiber >= 3 else { return nil }
        switch context.marketCategory {
        case .dryStaple, .cereal:
            return DisplayItem(text: fiber >= 6 ? "Good fiber" : "Useful fiber", severity: .safe, systemImage: "leaf.fill")
        default:
            return nil
        }
    }

    private static func proteinTakeaway(for context: Context) -> DisplayItem? {
        guard let protein = context.nutrition?.proteinPer100g else { return nil }
        switch context.marketCategory {
        case .yogurtOrDairy, .readyMeal:
            if protein >= 10 {
                return DisplayItem(text: "Strong protein", severity: .safe, systemImage: "bolt.heart.fill")
            }
            if protein >= 5 {
                return DisplayItem(text: "Protein amount", severity: .unknown, systemImage: "bolt.heart.fill")
            }
            return nil
        default:
            return nil
        }
    }

    private static func sugarTakeaway(for value: Double?, category: ProductMarketCategory) -> DisplayItem? {
        guard let value else { return nil }
        switch category {
        case .sweetDrink where value >= 5:
            return DisplayItem(text: "High sugar drink", severity: .caution, systemImage: "cube.box.fill")
        case .jam where value >= 22.5, .biscuitsOrSweets where value >= 22.5:
            return DisplayItem(text: "High sugar", severity: .caution, systemImage: "cube.box.fill")
        case .jam where value >= 10, .biscuitsOrSweets where value >= 10:
            return DisplayItem(text: "Sugary product", severity: .unknown, systemImage: "cube.box.fill")
        case .yogurtOrDairy where value >= 10:
            return DisplayItem(text: "Check sugar", severity: .caution, systemImage: "cube.box.fill")
        case .cereal where value >= 15:
            return DisplayItem(text: "Compare sugar first", severity: .caution, systemImage: "cube.box.fill")
        case .sauceOrCondiment where value >= 10:
            return DisplayItem(text: "Check sugar", severity: .caution, systemImage: "cube.box.fill")
        default:
            if value >= 22.5 {
                return DisplayItem(text: "High sugar", severity: .caution, systemImage: "cube.box.fill")
            }
            if value >= 10 {
                return DisplayItem(text: "Some sugar to notice", severity: .unknown, systemImage: "cube.box.fill")
            }
            return nil
        }
    }

    private static func saturatedFatTakeaway(for value: Double?, category: ProductMarketCategory) -> DisplayItem? {
        guard let value else { return nil }
        if category == .jam || category == .dryStaple || category == .sweetDrink {
            return nil
        }
        if value >= 5 {
            return DisplayItem(text: "High sat. fat", severity: .caution, systemImage: "drop.fill")
        }
        if value >= 1.5 {
            return DisplayItem(text: "Some sat. fat to notice", severity: .unknown, systemImage: "drop.fill")
        }
        return nil
    }

    private static func saltTakeaway(for value: Double?, category: ProductMarketCategory) -> DisplayItem? {
        guard let value else { return nil }
        if category == .jam || category == .dryStaple {
            return nil
        }
        if value >= 1.5 {
            return DisplayItem(text: "High salt", severity: .caution, systemImage: "takeoutbag.and.cup.and.straw.fill")
        }
        if value >= 0.3 {
            return DisplayItem(text: "Some salt to notice", severity: .unknown, systemImage: "takeoutbag.and.cup.and.straw.fill")
        }
        return nil
    }

    private static func caloriesInsight(for value: Double?, category: ProductMarketCategory) -> NutritionInsight? {
        guard let value else { return nil }
        switch category {
        case .dryStaple where value >= 250:
            return NutritionInsight(title: "Calories", subtitle: "Energy-dense because it is a dry staple ingredient. Not unusual for this product type.", valueText: ProductDetailFormatting.formattedValue(value, unit: "Cal", decimals: 0), systemImage: "flame.fill", severity: .unknown)
        case .readyMeal where value >= 220:
            return NutritionInsight(title: "Calories", subtitle: "Check the calories alongside salt, saturated fat, and protein.", valueText: ProductDetailFormatting.formattedValue(value, unit: "Cal", decimals: 0), systemImage: "flame.fill", severity: .caution)
        case .biscuitsOrSweets where value >= 400, .jam where value >= 400:
            return NutritionInsight(title: "Calories", subtitle: "Energy-dense for this type of product.", valueText: ProductDetailFormatting.formattedValue(value, unit: "Cal", decimals: 0), systemImage: "flame.fill", severity: .unknown)
        default:
            guard value >= 400 else { return nil }
            return NutritionInsight(title: "Calories", subtitle: "Energy-dense product.", valueText: ProductDetailFormatting.formattedValue(value, unit: "Cal", decimals: 0), systemImage: "flame.fill", severity: .unknown)
        }
    }

    private static func sugarInsight(for value: Double?, category: ProductMarketCategory) -> NutritionInsight? {
        guard let value else { return nil }
        switch category {
        case .sweetDrink where value >= 5:
            return NutritionInsight(title: "Sugar", subtitle: "High sugar drink.", valueText: ProductDetailFormatting.formattedValue(value, unit: "g"), systemImage: "cube.box.fill", severity: .caution)
        case .jam where value >= 22.5:
            return NutritionInsight(title: "Sugar", subtitle: "Typical for jam, but useful to compare between similar jars.", valueText: ProductDetailFormatting.formattedValue(value, unit: "g"), systemImage: "cube.box.fill", severity: .caution)
        case .biscuitsOrSweets where value >= 22.5:
            return NutritionInsight(title: "Sugar", subtitle: "High sugar for this type of product.", valueText: ProductDetailFormatting.formattedValue(value, unit: "g"), systemImage: "cube.box.fill", severity: .caution)
        case .jam where value >= 10, .biscuitsOrSweets where value >= 10:
            return NutritionInsight(title: "Sugar", subtitle: "Sugary product.", valueText: ProductDetailFormatting.formattedValue(value, unit: "g"), systemImage: "cube.box.fill", severity: .unknown)
        case .yogurtOrDairy where value >= 10:
            return NutritionInsight(title: "Sugar", subtitle: "Sweetened dairy product. Check sugar.", valueText: ProductDetailFormatting.formattedValue(value, unit: "g"), systemImage: "cube.box.fill", severity: .caution)
        case .cereal where value >= 15:
            return NutritionInsight(title: "Sugar", subtitle: "Compare sugar first for breakfast cereals.", valueText: ProductDetailFormatting.formattedValue(value, unit: "g"), systemImage: "cube.box.fill", severity: .caution)
        case .sauceOrCondiment where value >= 10:
            return NutritionInsight(title: "Sugar", subtitle: "Check sugar for sauces and condiments.", valueText: ProductDetailFormatting.formattedValue(value, unit: "g"), systemImage: "cube.box.fill", severity: .caution)
        default:
            if value >= 22.5 {
                return NutritionInsight(title: "Sugar", subtitle: "High sugar.", valueText: ProductDetailFormatting.formattedValue(value, unit: "g"), systemImage: "cube.box.fill", severity: .caution)
            }
            if value >= 10 {
                return NutritionInsight(title: "Sugar", subtitle: "Some sugar to notice.", valueText: ProductDetailFormatting.formattedValue(value, unit: "g"), systemImage: "cube.box.fill", severity: .unknown)
            }
            return nil
        }
    }

    private static func saturatedFatInsight(for value: Double?, category: ProductMarketCategory) -> NutritionInsight? {
        guard let value else { return nil }
        switch category {
        case .biscuitsOrSweets where value >= 5:
            return NutritionInsight(title: "Sat. fat", subtitle: "High saturated fat for this type of product.", valueText: ProductDetailFormatting.formattedValue(value, unit: "g"), systemImage: "drop.fill", severity: .caution)
        case .biscuitsOrSweets where value >= 1.5:
            return NutritionInsight(title: "Sat. fat", subtitle: "Some saturated fat to notice.", valueText: ProductDetailFormatting.formattedValue(value, unit: "g"), systemImage: "drop.fill", severity: .unknown)
        case .yogurtOrDairy where value >= 5:
            return NutritionInsight(title: "Sat. fat", subtitle: "High saturated fat for a dairy product.", valueText: ProductDetailFormatting.formattedValue(value, unit: "g"), systemImage: "drop.fill", severity: .caution)
        case .yogurtOrDairy where value >= 1.5:
            return NutritionInsight(title: "Sat. fat", subtitle: "Check saturated fat for a dairy product.", valueText: ProductDetailFormatting.formattedValue(value, unit: "g"), systemImage: "drop.fill", severity: .unknown)
        case .readyMeal where value >= 3:
            return NutritionInsight(title: "Sat. fat", subtitle: "Check saturated fat for this ready meal.", valueText: ProductDetailFormatting.formattedValue(value, unit: "g"), systemImage: "drop.fill", severity: .caution)
        default:
            if value >= 5 {
                return NutritionInsight(title: "Sat. fat", subtitle: "High saturated fat.", valueText: ProductDetailFormatting.formattedValue(value, unit: "g"), systemImage: "drop.fill", severity: .caution)
            }
            if value >= 1.5 {
                return NutritionInsight(title: "Sat. fat", subtitle: "Some saturated fat to notice.", valueText: ProductDetailFormatting.formattedValue(value, unit: "g"), systemImage: "drop.fill", severity: .unknown)
            }
            return nil
        }
    }

    private static func saltInsight(for value: Double?, category: ProductMarketCategory) -> NutritionInsight? {
        guard let value else { return nil }
        if category == .jam || category == .dryStaple {
            return nil
        }
        if value >= 1.5 {
            return NutritionInsight(title: "Salt", subtitle: "High salt.", valueText: ProductDetailFormatting.formattedValue(value, unit: "g"), systemImage: "takeoutbag.and.cup.and.straw.fill", severity: .caution)
        }
        if category == .sauceOrCondiment && value >= 0.6 {
            return NutritionInsight(title: "Salt", subtitle: "Check salt and portion size.", valueText: ProductDetailFormatting.formattedValue(value, unit: "g"), systemImage: "takeoutbag.and.cup.and.straw.fill", severity: .caution)
        }
        if (category == .readyMeal || category == .sauceOrCondiment), value >= 0.3 {
            return NutritionInsight(title: "Salt", subtitle: "Some salt to notice.", valueText: ProductDetailFormatting.formattedValue(value, unit: "g"), systemImage: "takeoutbag.and.cup.and.straw.fill", severity: .unknown)
        }
        return nil
    }

    private static func caloriesMetricSeverity(for value: Double, category: ProductMarketCategory) -> FlagSeverity {
        switch category {
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

    private static func sugarMetricSeverity(for value: Double, category: ProductMarketCategory) -> FlagSeverity {
        switch category {
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
        if value <= 5 { return .safe }
        return .unknown
    }

    private static func saturatedFatMetricSeverity(for value: Double, category: ProductMarketCategory) -> FlagSeverity {
        switch category {
        case .jam, .dryStaple, .sweetDrink:
            return .unknown
        case .yogurtOrDairy:
            if value >= 5 { return .caution }
            if value <= 1.5 { return .safe }
            return .unknown
        case .readyMeal:
            if value >= 3 { return .caution }
            return .unknown
        default:
            if value >= 5 { return .caution }
            if value >= 1.5 { return .unknown }
            return .safe
        }
    }

    private static func saltMetricSeverity(for value: Double, category: ProductMarketCategory) -> FlagSeverity {
        switch category {
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

    private static func fiberMetricSeverity(for value: Double, category: ProductMarketCategory) -> FlagSeverity {
        switch category {
        case .dryStaple, .cereal:
            if value >= 3 { return .safe }
            return .unknown
        default:
            return .unknown
        }
    }

    private static func proteinMetricSeverity(for value: Double, category: ProductMarketCategory) -> FlagSeverity {
        switch category {
        case .yogurtOrDairy, .readyMeal:
            if value >= 5 { return .safe }
            return .unknown
        case .dryStaple:
            return value >= 10 ? .safe : .unknown
        default:
            return .unknown
        }
    }

    private static func unique(_ items: [DisplayItem]) -> [DisplayItem] {
        var seen: Set<String> = []
        return items.filter { seen.insert($0.text).inserted }
    }
}
