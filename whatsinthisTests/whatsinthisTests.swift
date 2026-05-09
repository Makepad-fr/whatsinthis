//
//  whatsinthisTests.swift
//  whatsinthisTests
//
//  Created by Idil Saglam on 28/04/2026.
//

import Foundation
import SwiftData
import Testing
@testable import whatsinthis

@MainActor
struct whatsinthisTests {
    @Test
    func analyzerFlagsFoodAllergensAndAdditives() {
        let analyzer = IngredientAnalyzer()
        analyzer.updateGlossary([
            IngredientGlossaryItem(
                id: "soy-lecithin",
                name: "Soy Lecithin",
                aliases: ["lecithin"],
                category: .food,
                summary: "Emulsifier",
                function: "Helps keep oil and water mixed.",
                caution: true,
                markers: [.additive, .allergen]
            ),
            IngredientGlossaryItem(
                id: "whey",
                name: "Whey",
                aliases: [],
                category: .food,
                summary: "Milk-derived ingredient",
                function: "Adds dairy solids or protein.",
                caution: true,
                markers: [.allergen]
            ),
        ])

        let product = NormalizedProduct(
            id: "123",
            barcode: "123",
            name: "Test Bar",
            brand: "Demo",
            imageURL: nil,
            ingredientText: "Sugar, Whey Powder, Soy Lecithin, Natural Flavor",
            ingredientTags: [],
            categoryTags: [],
            additives: ["en:e322"],
            allergens: ["en:milk", "en:soybeans"],
            category: .food,
            source: .openFoodFacts,
            ingredientsProvenance: .api,
            capturedAt: .now
        )

        let result = analyzer.analyze(product: product)

        #expect(result.highlightCards.contains(where: { $0.title == "Allergens" }))
        #expect(result.highlightCards.contains(where: { $0.title == "Additives" }))
        #expect(result.ingredients.contains(where: { $0.text.contains("Whey") && $0.flags.contains(where: { $0.kind == .allergen }) }))
        #expect(result.ingredients.contains(where: { $0.text.contains("Soy Lecithin") && $0.flags.contains(where: { $0.kind == .additive }) }))
    }

    @Test
    func analyzerInfersBeautyCategoryFromOCRText() {
        let analyzer = IngredientAnalyzer()
        let text = "Aqua, Glycerin, Parfum, Tocopherol, Cocamidopropyl Betaine"

        #expect(analyzer.inferCategory(from: text) == .beauty)
    }

    @Test
    func ocrPlaceholderKeepsOCRProvenance() {
        let placeholder = NormalizedProduct.ocrPlaceholder(
            text: "Sugar, Salt",
            category: .food,
            barcode: nil
        )

        #expect(placeholder.ingredientsProvenance == .ocr)
        #expect(placeholder.source == .ocr)
        #expect(placeholder.name == "Scanned Ingredient Label")
    }

    @Test
    func qrParserExtractsProductCodeFromGS1DigitalLink() {
        let payload = ScanPayloadParser.parse(
            rawValue: "https://id.gs1.org/01/09506000134352/21/ABC123",
            symbology: .qrCode
        )

        #expect(payload == .productCode("09506000134352"))
    }

    @Test
    func qrParserExtractsProductCodeFromQueryItem() {
        let payload = ScanPayloadParser.parse(
            rawValue: "https://example.com/product?barcode=5449000000996",
            symbology: .qrCode
        )

        #expect(payload == .productCode("5449000000996"))
    }

    @Test
    func qrParserMarksUnsupportedQRCode() {
        let payload = ScanPayloadParser.parse(
            rawValue: "https://example.com/landing-page",
            symbology: .qrCode
        )

        #expect(payload == .unsupportedQRCode("https://example.com/landing-page"))
    }

    @Test
    func singleWholeFoodIngredientDoesNotBecomeUnknown() {
        let analyzer = IngredientAnalyzer()
        analyzer.updateGlossary([])

        let product = NormalizedProduct(
            id: "radish",
            barcode: "12345678",
            name: "Radis",
            brand: "Demo",
            imageURL: nil,
            ingredientText: "Radis",
            ingredientTags: [],
            categoryTags: ["fr:radis"],
            additives: [],
            allergens: [],
            category: .food,
            source: .openFoodFacts,
            ingredientsProvenance: .api,
            capturedAt: .now
        )

        let result = analyzer.analyze(product: product)

        #expect(result.ingredients.count == 1)
        #expect(result.ingredients[0].flags.isEmpty)
        #expect(result.highlightCards.isEmpty)
        #expect(result.summary.headline == "Single ingredient recognized without caution markers.")
    }

    @Test
    func resolverFallsBackToSingleIngredientName() {
        let resolved = ProductPresentationResolver.resolvedName(
            primaryName: nil,
            secondaryName: nil,
            genericName: nil,
            ingredientText: "radis",
            categoryTags: []
        )

        #expect(resolved == "Radis")
    }

    @Test
    func featuredIngredientsPrioritizeCautionTokens() {
        let safeToken = IngredientToken(
            text: "Water",
            normalizedText: "water",
            matchedTerm: "Water",
            confidence: 0.95,
            explanation: IngredientExplanation(
                summary: "Water is a base ingredient.",
                function: "Acts as a carrier.",
                whyHighlighted: "Recognized in the glossary.",
                provenance: .glossary
            ),
            flags: []
        )

        let cautionToken = IngredientToken(
            text: "Fragrance",
            normalizedText: "fragrance",
            matchedTerm: "Fragrance",
            confidence: 0.9,
            explanation: IngredientExplanation(
                summary: "Used to scent the product.",
                function: "Adds fragrance.",
                whyHighlighted: "This ingredient is marked for extra context in the glossary.",
                provenance: .glossary
            ),
            flags: [
                AnalysisFlag(kind: .fragrance, severity: .caution, reason: "This ingredient is commonly used in fragrance contexts.")
            ]
        )

        let analyzed = AnalyzedProduct(
            product: NormalizedProduct.ocrPlaceholder(text: "Water, Fragrance", category: .beauty),
            ingredients: [safeToken, cautionToken],
            highlightCards: [],
            summary: InsightSummary(headline: "Test", supportingText: "Test", disclaimer: "Test")
        )

        #expect(analyzed.featuredIngredients.first?.text == "Fragrance")
    }

    @Test
    func confidenceSummaryMentionsSource() {
        let token = IngredientToken(
            text: "Radis",
            normalizedText: "radis",
            matchedTerm: nil,
            confidence: 0.55,
            explanation: IngredientExplanation(
                summary: "Radis looks like a straightforward food ingredient.",
                function: "This appears to be a simple whole-food or spice ingredient rather than an additive.",
                whyHighlighted: "No caution markers were detected.",
                provenance: .inferred
            ),
            flags: []
        )

        #expect(token.confidenceSummary == "Estimated match from rule-based inference.")
    }

    @Test
    func foodProductBuildsNutritionInsights() throws {
        let product = NormalizedProduct(
            id: "spread",
            barcode: "1",
            name: "Test Spread",
            brand: "Demo",
            imageURL: nil,
            ingredientText: "Sugar, Hazelnuts",
            ingredientTags: [],
            categoryTags: [],
            additives: [],
            allergens: [],
            category: .food,
            source: .openFoodFacts,
            nutrition: NutritionSnapshot(
                energyKcalPer100g: 544,
                sugarsPer100g: 51,
                saturatedFatPer100g: 5.7,
                fiberPer100g: 3.6,
                proteinPer100g: 8.1,
                saltPer100g: 0.12,
                nutritionGrade: "d",
                novaGroup: 4,
                ecoScoreGrade: nil
            ),
            ingredientsProvenance: .api,
            capturedAt: .now
        )

        let analyzed = AnalyzedProduct(
            product: product,
            ingredients: [],
            highlightCards: [],
            summary: InsightSummary(headline: "Test", supportingText: "Test", disclaimer: "Test")
        )

        let viewModel = ProductDetailViewModel(
            analyzedProduct: analyzed,
            imageRepository: ProductImageRepository(dataStore: try makeInMemoryDataStore())
        )

        #expect(viewModel.hasNutritionTab)
        #expect(viewModel.negativeNutritionInsights.map(\.title).contains("Sugar"))
        #expect(viewModel.negativeNutritionInsights.map(\.title).contains("Calories"))
        #expect(viewModel.positiveNutritionInsights.map(\.title).contains("Fiber"))
        #expect(viewModel.positiveNutritionInsights.map(\.title).contains("Salt"))
    }

    @Test
    func flourProductUsesFactualAllergenHeaderAndTakeaways() throws {
        let analyzer = IngredientAnalyzer()
        analyzer.updateGlossary([])

        let product = NormalizedProduct(
            id: "flour",
            barcode: "2",
            name: "Type 150 wholemeal wheat flour",
            brand: "Demo",
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

        let analyzed = analyzer.analyze(product: product)
        let viewModel = ProductDetailViewModel(
            analyzedProduct: analyzed,
            imageRepository: ProductImageRepository(dataStore: try makeInMemoryDataStore())
        )

        #expect(viewModel.headerStatus.title == "Contains wheat / gluten")
        #expect(viewModel.headerStatus.subtitle == "Common allergen. Expected for this product type.")
        #expect(viewModel.atAGlanceItems.map(\.text).contains("Check if avoiding gluten"))
        #expect(viewModel.atAGlanceItems.map(\.text).contains("Good fiber"))
        #expect(viewModel.atAGlanceItems.map(\.text).contains("Low sugar"))
        #expect(viewModel.atAGlanceItems.map(\.text).contains("Simple ingredient list"))
    }

    @Test
    func dryStapleCaloriesUseNeutralWorthNoticingCopy() throws {
        let product = NormalizedProduct(
            id: "flour-nutrition",
            barcode: "3",
            name: "Wholemeal flour",
            brand: "Demo",
            imageURL: nil,
            ingredientText: "Wholemeal wheat flour",
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

        let analyzed = AnalyzedProduct(
            product: product,
            ingredients: [],
            highlightCards: [],
            summary: InsightSummary(headline: "Test", supportingText: "Test", disclaimer: "Test")
        )

        let viewModel = ProductDetailViewModel(
            analyzedProduct: analyzed,
            imageRepository: ProductImageRepository(dataStore: try makeInMemoryDataStore())
        )

        #expect(
            viewModel.negativeNutritionInsights.first(where: { $0.title == "Calories" })?.subtitle
                == "Energy-dense because it is a dry staple ingredient. Not unusual for this product type."
        )
    }

    @Test
    func sugaryProductShowsDirectNutritionWarningsInAtAGlance() throws {
        let product = NormalizedProduct(
            id: "spread-warning",
            barcode: "4",
            name: "Chocolate Spread",
            brand: "Demo",
            imageURL: nil,
            ingredientText: "Sugar, Palm Oil, Hazelnuts",
            ingredientTags: [],
            categoryTags: ["en:spreads", "en:sweet-spreads"],
            additives: [],
            allergens: [],
            category: .food,
            source: .openFoodFacts,
            nutrition: NutritionSnapshot(
                energyKcalPer100g: 544,
                sugarsPer100g: 51,
                saturatedFatPer100g: 5.7,
                fiberPer100g: 3.6,
                proteinPer100g: 8.1,
                saltPer100g: 0.12,
                nutritionGrade: nil,
                novaGroup: nil,
                ecoScoreGrade: nil
            ),
            ingredientsProvenance: .api,
            capturedAt: .now
        )

        let analyzed = AnalyzedProduct(
            product: product,
            ingredients: [],
            highlightCards: [],
            summary: InsightSummary(headline: "Test", supportingText: "Test", disclaimer: "Test")
        )

        let viewModel = ProductDetailViewModel(
            analyzedProduct: analyzed,
            imageRepository: ProductImageRepository(dataStore: try makeInMemoryDataStore())
        )

        #expect(viewModel.atAGlanceItems.map(\.text).contains("High sugar"))
        #expect(viewModel.atAGlanceItems.map(\.text).contains("High sat. fat"))
        #expect(
            viewModel.negativeNutritionInsights.first(where: { $0.title == "Sugar" })?.subtitle
                == "High sugar for this type of product."
        )
    }

    @Test
    func jamProductDoesNotUseDrinkCopyAndDoesNotClaimNoConcerns() throws {
        let analyzer = IngredientAnalyzer()
        analyzer.updateGlossary([])

        let product = NormalizedProduct(
            id: "jam",
            barcode: "7",
            name: "Confiture de figues violettes",
            brand: "Demo",
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

        let analyzed = analyzer.analyze(product: product)
        let viewModel = ProductDetailViewModel(
            analyzedProduct: analyzed,
            imageRepository: ProductImageRepository(dataStore: try makeInMemoryDataStore())
        )

        #expect(viewModel.headerStatus.title == "Some ingredients need more context")
        #expect(viewModel.atAGlanceItems.map(\.text).contains("Some terms need more context"))
        #expect(!viewModel.atAGlanceItems.map(\.text).contains("No ingredient concerns found"))
        #expect(
            viewModel.negativeNutritionInsights.first(where: { $0.title == "Sugar" })?.subtitle
                == "High sugar for this type of product."
        )
    }

    @Test
    func frenchGlossaryTermsExplainCommonJamIngredients() {
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
                aliases: ["sucre"],
                category: .food,
                summary: "Sugar is a sweetener used for taste, texture, and preservation.",
                function: "It adds sweetness and can help balance acidity or support shelf life.",
                caution: false,
                markers: []
            ),
            IngredientGlossaryItem(
                id: "fruit-pectin",
                name: "Fruit Pectin",
                aliases: ["pectine de fruits", "gelifiant pectine de fruits"],
                category: .food,
                summary: "Fruit pectin is a gelling fiber commonly used in jams and fruit preserves.",
                function: "It helps fruit mixtures set into a spreadable texture.",
                caution: false,
                markers: []
            )
        ])

        let product = NormalizedProduct(
            id: "jam-2",
            barcode: "8",
            name: "Confiture de figues",
            brand: "Demo",
            imageURL: nil,
            ingredientText: "Figues violettes, sucre, gélifiant : pectine de fruits",
            ingredientTags: [],
            categoryTags: ["en:jams"],
            additives: [],
            allergens: [],
            category: .food,
            source: .openFoodFacts,
            ingredientsProvenance: .api,
            capturedAt: .now
        )

        let analyzed = analyzer.analyze(product: product)

        #expect(analyzed.ingredients.allSatisfy { $0.severity == .safe })
        #expect(analyzed.unknownCount == 0)
    }

    @Test
    func recognizedJamPromotesHighSugarToHeaderInsteadOfNoConcerns() throws {
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
            )
        ])

        let product = NormalizedProduct(
            id: "jam-3",
            barcode: "11",
            name: "Confiture de figues violettes",
            brand: "Demo",
            imageURL: nil,
            ingredientText: "Figues violettes, sucre, sucre roux de canne, jus de citrons concentré, gélifiant : pectine de fruits",
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

        let analyzed = analyzer.analyze(product: product)
        let viewModel = ProductDetailViewModel(
            analyzedProduct: analyzed,
            imageRepository: ProductImageRepository(dataStore: try makeInMemoryDataStore())
        )

        #expect(viewModel.unknownCount == 0)
        #expect(viewModel.headerStatus.title == "High sugar")
        #expect(viewModel.headerStatus.subtitle == "High sugar for this type of product.")
        #expect(!viewModel.atAGlanceItems.map(\.text).contains("No ingredient concerns found"))
        #expect(viewModel.atAGlanceItems.map(\.text).contains("High sugar"))
    }

    @Test
    func productDetailBuildsSwapIdeasFromBetterMatches() async throws {
        let analyzer = IngredientAnalyzer()
        analyzer.updateGlossary([])

        let current = NormalizedProduct(
            id: "nutella-like",
            barcode: "5",
            name: "Chocolate Hazelnut Spread",
            brand: "Demo",
            imageURL: nil,
            ingredientText: "Sugar, Palm Oil, Hazelnuts, Cocoa",
            ingredientTags: [],
            categoryTags: ["en:cocoa-and-hazelnuts-spreads", "en:sweet-spreads"],
            additives: ["en:e322"],
            allergens: ["en:hazelnuts"],
            category: .food,
            source: .openFoodFacts,
            nutrition: NutritionSnapshot(
                energyKcalPer100g: 540,
                sugarsPer100g: 56,
                saturatedFatPer100g: 10,
                fiberPer100g: 3,
                proteinPer100g: 6,
                saltPer100g: 0.1,
                nutritionGrade: nil,
                novaGroup: nil,
                ecoScoreGrade: nil
            ),
            ingredientsProvenance: .api,
            capturedAt: .now
        )

        let betterAlternative = NormalizedProduct(
            id: "better-spread",
            barcode: "6",
            name: "Hazelnut Cocoa Spread",
            brand: "Alt Brand",
            imageURL: nil,
            ingredientText: "Hazelnuts, Sugar, Cocoa",
            ingredientTags: [],
            categoryTags: ["en:cocoa-and-hazelnuts-spreads"],
            additives: [],
            allergens: ["en:hazelnuts"],
            category: .food,
            source: .openFoodFacts,
            nutrition: NutritionSnapshot(
                energyKcalPer100g: 500,
                sugarsPer100g: 42,
                saturatedFatPer100g: 5.5,
                fiberPer100g: 6,
                proteinPer100g: 8,
                saltPer100g: 0.05,
                nutritionGrade: nil,
                novaGroup: nil,
                ecoScoreGrade: nil
            ),
            ingredientsProvenance: .api,
            capturedAt: .now
        )

        let analyzed = analyzer.analyze(product: current)
        let viewModel = ProductDetailViewModel(
            analyzedProduct: analyzed,
            imageRepository: ProductImageRepository(dataStore: try makeInMemoryDataStore()),
            productBackend: RecommendationProductBackendStub(similarProductsResult: [betterAlternative]),
            ingredientAnalyzer: analyzer
        )

        await viewModel.loadSwapRecommendationsIfNeeded()

        #expect(viewModel.swapRecommendations.count == 1)
        #expect(viewModel.swapRecommendations.first?.title == "Hazelnut Cocoa Spread")
        #expect(viewModel.swapRecommendations.first?.reasons.map(\.text).contains(where: { $0.contains("less sugar") }) == true)
        #expect(viewModel.swapRecommendations.first?.reasons.map(\.text).contains(where: { $0.contains("less sat. fat") }) == true)
    }

    @Test
    func jamRecommendationsPreferSameFruitBeforeDifferentJamFlavor() async throws {
        let analyzer = IngredientAnalyzer()
        analyzer.updateGlossary([])

        let current = NormalizedProduct(
            id: "jam-current-strawberry",
            barcode: "19",
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
            nutrition: NutritionSnapshot(
                energyKcalPer100g: 245,
                sugarsPer100g: 60,
                saturatedFatPer100g: 0,
                fiberPer100g: 1.2,
                proteinPer100g: 0.4,
                saltPer100g: 0,
                nutritionGrade: nil,
                novaGroup: nil,
                ecoScoreGrade: nil
            ),
            ingredientsProvenance: .api,
            capturedAt: .now
        )

        let strawberryAlternative = NormalizedProduct(
            id: "jam-strawberry-alt",
            barcode: "20",
            name: "Confiture extra de fraises",
            brand: "Alt Brand",
            imageURL: nil,
            ingredientText: "Fraises, sucre",
            ingredientTags: [],
            categoryTags: ["en:jams"],
            additives: [],
            allergens: [],
            category: .food,
            source: .openFoodFacts,
            nutrition: NutritionSnapshot(
                energyKcalPer100g: 246,
                sugarsPer100g: 60,
                saturatedFatPer100g: 0,
                fiberPer100g: 1.2,
                proteinPer100g: 0.4,
                saltPer100g: 0,
                nutritionGrade: nil,
                novaGroup: nil,
                ecoScoreGrade: nil
            ),
            ingredientsProvenance: .api,
            capturedAt: .now
        )

        let apricotAlternative = NormalizedProduct(
            id: "jam-apricot-alt",
            barcode: "21",
            name: "Confiture d'abricots",
            brand: "Alt Brand",
            imageURL: nil,
            ingredientText: "Abricots, sucre",
            ingredientTags: [],
            categoryTags: ["en:jams"],
            additives: [],
            allergens: [],
            category: .food,
            source: .openFoodFacts,
            nutrition: NutritionSnapshot(
                energyKcalPer100g: 228,
                sugarsPer100g: 54,
                saturatedFatPer100g: 0,
                fiberPer100g: 1.5,
                proteinPer100g: 0.5,
                saltPer100g: 0,
                nutritionGrade: nil,
                novaGroup: nil,
                ecoScoreGrade: nil
            ),
            ingredientsProvenance: .api,
            capturedAt: .now
        )

        let analyzed = analyzer.analyze(product: current)
        let viewModel = ProductDetailViewModel(
            analyzedProduct: analyzed,
            imageRepository: ProductImageRepository(dataStore: try makeInMemoryDataStore()),
            productBackend: RecommendationProductBackendStub(similarProductsResult: [apricotAlternative, strawberryAlternative]),
            ingredientAnalyzer: analyzer
        )

        await viewModel.loadSwapRecommendationsIfNeeded()

        #expect(viewModel.swapSectionTitle == "Compare with similar products")
        #expect(viewModel.swapRecommendations.count == 1)
        #expect(viewModel.swapRecommendations.first?.title == "Confiture extra de fraises")
    }

    @Test
    func jamProductCanShowSwapIdeasForMeaningfullyLowerSugarAlternatives() async throws {
        let analyzer = IngredientAnalyzer()
        analyzer.updateGlossary([])

        let current = NormalizedProduct(
            id: "jam-current",
            barcode: "9",
            name: "Confiture de figues",
            brand: "Demo",
            imageURL: nil,
            ingredientText: "Figues, sucre",
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

        let betterAlternative = NormalizedProduct(
            id: "jam-better",
            barcode: "10",
            name: "Confiture extra de figues",
            brand: "Alt Brand",
            imageURL: nil,
            ingredientText: "Figues, sucre",
            ingredientTags: [],
            categoryTags: ["en:jams"],
            additives: [],
            allergens: [],
            category: .food,
            source: .openFoodFacts,
            nutrition: NutritionSnapshot(
                energyKcalPer100g: 228,
                sugarsPer100g: 55,
                saturatedFatPer100g: 0,
                fiberPer100g: 1.5,
                proteinPer100g: 0.6,
                saltPer100g: 0,
                nutritionGrade: nil,
                novaGroup: nil,
                ecoScoreGrade: nil
            ),
            ingredientsProvenance: .api,
            capturedAt: .now
        )

        let analyzed = analyzer.analyze(product: current)
        let viewModel = ProductDetailViewModel(
            analyzedProduct: analyzed,
            imageRepository: ProductImageRepository(dataStore: try makeInMemoryDataStore()),
            productBackend: RecommendationProductBackendStub(similarProductsResult: [betterAlternative]),
            ingredientAnalyzer: analyzer
        )

        await viewModel.loadSwapRecommendationsIfNeeded()

        #expect(viewModel.swapRecommendations.count == 1)
        #expect(viewModel.swapRecommendations.first?.reasons.map(\.text).contains(where: { $0.contains("less sugar") }) == true)
    }

    @Test
    func fallsBackToSimilarOptionsWhenNoBetterSwapExists() async throws {
        let analyzer = IngredientAnalyzer()
        analyzer.updateGlossary([])

        let current = NormalizedProduct(
            id: "jam-current-2",
            barcode: "12",
            name: "Confiture de figues",
            brand: "Demo",
            imageURL: nil,
            ingredientText: "Figues, sucre",
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

        let similarAlternative = NormalizedProduct(
            id: "jam-similar",
            barcode: "13",
            name: "Confiture de fruits rouges",
            brand: "Alt Brand",
            imageURL: nil,
            ingredientText: "Fruits, sucre",
            ingredientTags: [],
            categoryTags: ["en:jams"],
            additives: [],
            allergens: [],
            category: .food,
            source: .openFoodFacts,
            nutrition: NutritionSnapshot(
                energyKcalPer100g: 244,
                sugarsPer100g: 60,
                saturatedFatPer100g: 0,
                fiberPer100g: 1.1,
                proteinPer100g: 0.4,
                saltPer100g: 0,
                nutritionGrade: nil,
                novaGroup: nil,
                ecoScoreGrade: nil
            ),
            ingredientsProvenance: .api,
            capturedAt: .now
        )

        let analyzed = analyzer.analyze(product: current)
        let viewModel = ProductDetailViewModel(
            analyzedProduct: analyzed,
            imageRepository: ProductImageRepository(dataStore: try makeInMemoryDataStore()),
            productBackend: RecommendationProductBackendStub(similarProductsResult: [similarAlternative]),
            ingredientAnalyzer: analyzer
        )

        await viewModel.loadSwapRecommendationsIfNeeded()

        #expect(viewModel.swapSectionTitle == "Compare with similar products")
        #expect(viewModel.swapRecommendations.count == 1)
        #expect(viewModel.swapRecommendations.first?.presentation == .similar)
    }

    @Test
    func recommendationServiceUnavailableShowsManualCompareMessage() async throws {
        let analyzer = IngredientAnalyzer()
        analyzer.updateGlossary([])

        let current = NormalizedProduct(
            id: "jam-current-3",
            barcode: "14",
            name: "Confiture de figues",
            brand: "Demo",
            imageURL: nil,
            ingredientText: "Figues, sucre",
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

        let analyzed = analyzer.analyze(product: current)
        let viewModel = ProductDetailViewModel(
            analyzedProduct: analyzed,
            imageRepository: ProductImageRepository(dataStore: try makeInMemoryDataStore()),
            productBackend: RecommendationProductBackendStub(
                similarProductsResult: [],
                similarProductsError: SimilarProductsLookupError.serviceUnavailable
            ),
            ingredientAnalyzer: analyzer
        )

        await viewModel.loadSwapRecommendationsIfNeeded()

        #expect(viewModel.swapRecommendations.isEmpty)
        #expect(viewModel.swapSectionTitle == "Compare with similar products")
        #expect(viewModel.swapSectionEmptyMessage?.contains("temporarily unavailable") == true)
        #expect(viewModel.swapSectionEmptyMessage?.contains("compare manually") == true)
    }

    @Test
    func recommendationServiceUnavailableFallsBackToRecentCachedProducts() async throws {
        let analyzer = IngredientAnalyzer()
        analyzer.updateGlossary([])

        let dataStore = try makeInMemoryDataStore()
        let repository = ProductImageRepository(dataStore: dataStore)

        let current = NormalizedProduct(
            id: "jam-current-4",
            barcode: "15",
            name: "Confiture de figues",
            brand: "Demo",
            imageURL: nil,
            ingredientText: "Figues, sucre",
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

        let cachedAlternative = NormalizedProduct(
            id: "jam-cached",
            barcode: "16",
            name: "Confiture extra de figues",
            brand: "Alt Brand",
            imageURL: nil,
            ingredientText: "Figues, sucre",
            ingredientTags: [],
            categoryTags: ["en:jams"],
            additives: [],
            allergens: [],
            category: .food,
            source: .openFoodFacts,
            nutrition: NutritionSnapshot(
                energyKcalPer100g: 228,
                sugarsPer100g: 55,
                saturatedFatPer100g: 0,
                fiberPer100g: 1.5,
                proteinPer100g: 0.6,
                saltPer100g: 0,
                nutritionGrade: nil,
                novaGroup: nil,
                ecoScoreGrade: nil
            ),
            ingredientsProvenance: .api,
            capturedAt: .now
        )

        try dataStore.save(
            analyzedProduct: analyzer.analyze(product: cachedAlternative)
        )

        let analyzed = analyzer.analyze(product: current)
        let viewModel = ProductDetailViewModel(
            analyzedProduct: analyzed,
            imageRepository: repository,
            productBackend: RecommendationProductBackendStub(
                similarProductsResult: [],
                similarProductsError: SimilarProductsLookupError.serviceUnavailable
            ),
            ingredientAnalyzer: analyzer
        )

        await viewModel.loadSwapRecommendationsIfNeeded()

        #expect(viewModel.swapRecommendations.count == 1)
        #expect(viewModel.swapSectionTitle == "Compare with similar products")
        #expect(viewModel.swapRecommendations.first?.title == "Confiture extra de figues")
        #expect(viewModel.swapSectionEmptyMessage == nil)
    }

    @Test
    func localFallbackDoesNotUseUnrelatedCachedSpreadProducts() async throws {
        let analyzer = IngredientAnalyzer()
        analyzer.updateGlossary([])

        let dataStore = try makeInMemoryDataStore()
        let repository = ProductImageRepository(dataStore: dataStore)

        let current = NormalizedProduct(
            id: "jam-current-5",
            barcode: "17",
            name: "Confiture de figues",
            brand: "Demo",
            imageURL: nil,
            ingredientText: "Figues, sucre",
            ingredientTags: [],
            categoryTags: ["en:jams", "en:plant-based-spreads"],
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

        let unrelatedSpread = NormalizedProduct(
            id: "peanut-butter",
            barcode: "18",
            name: "Peanut Butter",
            brand: "Alt Brand",
            imageURL: nil,
            ingredientText: "Peanuts, salt",
            ingredientTags: [],
            categoryTags: ["en:plant-based-spreads", "en:spreads"],
            additives: [],
            allergens: ["en:peanuts"],
            category: .food,
            source: .openFoodFacts,
            nutrition: NutritionSnapshot(
                energyKcalPer100g: 600,
                sugarsPer100g: 6,
                saturatedFatPer100g: 8,
                fiberPer100g: 8,
                proteinPer100g: 26,
                saltPer100g: 0.8,
                nutritionGrade: nil,
                novaGroup: nil,
                ecoScoreGrade: nil
            ),
            ingredientsProvenance: .api,
            capturedAt: .now
        )

        try dataStore.save(
            analyzedProduct: analyzer.analyze(product: unrelatedSpread)
        )

        let analyzed = analyzer.analyze(product: current)
        let viewModel = ProductDetailViewModel(
            analyzedProduct: analyzed,
            imageRepository: repository,
            productBackend: RecommendationProductBackendStub(
                similarProductsResult: [],
                similarProductsError: SimilarProductsLookupError.serviceUnavailable
            ),
            ingredientAnalyzer: analyzer
        )

        await viewModel.loadSwapRecommendationsIfNeeded()

        #expect(viewModel.swapRecommendations.isEmpty)
        #expect(viewModel.swapSectionTitle == "Compare with similar products")
        #expect(viewModel.swapSectionEmptyMessage?.contains("temporarily unavailable") == true)
        #expect(viewModel.swapSectionEmptyMessage?.contains("jam or preserve") == true)
    }

    private func makeInMemoryDataStore() throws -> DataStore {
        let schema = Schema([
            CachedProductRecord.self,
            CachedImageRecord.self,
            IngredientGlossaryEntryRecord.self,
            ScanSnapshotRecord.self,
            UserPreferenceRecord.self,
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        return DataStore(modelContainer: container)
    }
}
