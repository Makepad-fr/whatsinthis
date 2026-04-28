//
//  DomainModels.swift
//  whatsinthis
//
//  Created by Codex on 28/04/2026.
//

import Foundation

enum ProductCategory: String, Codable, CaseIterable, Hashable, Identifiable {
    case food
    case beauty
    case unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .food:
            "Food"
        case .beauty:
            "Beauty"
        case .unknown:
            "Unknown"
        }
    }
}

enum ScanSource: String, Codable, Hashable {
    case openFoodFacts
    case openBeautyFacts
    case usda
    case ocr
    case cache

    var displayName: String {
        switch self {
        case .openFoodFacts:
            "Open Food Facts"
        case .openBeautyFacts:
            "Open Beauty Facts"
        case .usda:
            "USDA"
        case .ocr:
            "OCR"
        case .cache:
            "Cached"
        }
    }
}

enum IngredientProvenance: String, Codable, Hashable {
    case api
    case ocr
    case glossary
    case inferred

    var displayName: String {
        switch self {
        case .api:
            "Product metadata"
        case .ocr:
            "Label OCR"
        case .glossary:
            "Glossary"
        case .inferred:
            "Rule-based inference"
        }
    }
}

enum FlagSeverity: String, Codable, Hashable {
    case safe
    case caution
    case unknown
}

enum AnalysisMarker: String, Codable, Hashable, CaseIterable {
    case allergen
    case additive
    case processing
    case fragrance
    case preservative
    case surfactant
    case irritant
    case unknown

    var displayName: String {
        switch self {
        case .allergen:
            "Allergen"
        case .additive:
            "Additive"
        case .processing:
            "Processing clue"
        case .fragrance:
            "Fragrance"
        case .preservative:
            "Preservative"
        case .surfactant:
            "Surfactant"
        case .irritant:
            "Irritant marker"
        case .unknown:
            "Unknown"
        }
    }
}

struct AnalysisFlag: Codable, Hashable, Identifiable {
    let id: String
    let kind: AnalysisMarker
    let severity: FlagSeverity
    let reason: String

    init(kind: AnalysisMarker, severity: FlagSeverity, reason: String) {
        self.id = "\(kind.rawValue)-\(severity.rawValue)-\(reason)"
        self.kind = kind
        self.severity = severity
        self.reason = reason
    }
}

struct IngredientExplanation: Codable, Hashable {
    let summary: String
    let function: String
    let whyHighlighted: String
    let provenance: IngredientProvenance
}

struct IngredientToken: Codable, Hashable, Identifiable {
    let id: UUID
    let text: String
    let normalizedText: String
    let matchedTerm: String?
    let confidence: Double
    let explanation: IngredientExplanation?
    let flags: [AnalysisFlag]

    init(
        id: UUID = UUID(),
        text: String,
        normalizedText: String,
        matchedTerm: String?,
        confidence: Double,
        explanation: IngredientExplanation?,
        flags: [AnalysisFlag]
    ) {
        self.id = id
        self.text = text
        self.normalizedText = normalizedText
        self.matchedTerm = matchedTerm
        self.confidence = confidence
        self.explanation = explanation
        self.flags = flags
    }

    var severity: FlagSeverity {
        if flags.contains(where: { $0.severity == .caution }) {
            return .caution
        }
        if flags.contains(where: { $0.severity == .unknown }) {
            return .unknown
        }
        return .safe
    }

    var primaryFlag: AnalysisFlag? {
        flags.first(where: { $0.severity == .caution })
            ?? flags.first(where: { $0.severity == .unknown })
    }

    var statusTitle: String {
        switch primaryFlag?.kind {
        case .allergen:
            "Common allergen"
        case .additive:
            "Additive found"
        case .processing:
            "Worth noticing"
        case .fragrance:
            "Fragrance Ingredient"
        case .preservative:
            "Preservative"
        case .surfactant:
            "Cleansing Ingredient"
        case .irritant:
            "Irritation Marker"
        case .unknown:
            "Needs More Context"
        case nil:
            severity == .unknown ? "Needs More Context" : "Simple Ingredient"
        }
    }

    var statusBadge: String {
        switch severity {
        case .safe:
            "Simple"
        case .caution:
            "Check"
        case .unknown:
            "Unknown"
        }
    }

    var shortSummary: String {
        explanation?.summary ?? "No explanation is available yet."
    }

    var quickLookSummary: String {
        if let primaryFlag {
            switch primaryFlag.kind {
            case .allergen:
                return "\(text) matches a common allergen term."
            case .unknown:
                return "\(text) still needs better reference coverage."
            default:
                return primaryFlag.reason
            }
        }

        return shortSummary
    }

    var supportingSummary: String {
        if let explanation {
            return explanation.function
        }

        return "Tap for more context."
    }

    var confidenceLabel: String {
        switch confidence {
        case 0.85...:
            "Strong match"
        case 0.5...:
            "Estimated match"
        default:
            "Needs verification"
        }
    }

    var confidenceSummary: String {
        "\(confidenceLabel) from \(explanation?.provenance.displayName.lowercased() ?? IngredientProvenance.inferred.displayName.lowercased())."
    }
}

struct InsightSummary: Codable, Hashable {
    let headline: String
    let supportingText: String
    let disclaimer: String
}

struct HighlightCard: Codable, Hashable, Identifiable {
    enum Tint: String, Codable, Hashable {
        case positive
        case caution
        case neutral
    }

    let id: UUID
    let title: String
    let detail: String
    let systemImage: String
    let tint: Tint

    init(id: UUID = UUID(), title: String, detail: String, systemImage: String, tint: Tint) {
        self.id = id
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
        self.tint = tint
    }
}

struct NutritionSnapshot: Codable, Hashable {
    let energyKcalPer100g: Double?
    let sugarsPer100g: Double?
    let saturatedFatPer100g: Double?
    let fiberPer100g: Double?
    let proteinPer100g: Double?
    let saltPer100g: Double?
    let nutritionGrade: String?
    let novaGroup: Int?
    let ecoScoreGrade: String?

    var hasAnyValue: Bool {
        energyKcalPer100g != nil
            || sugarsPer100g != nil
            || saturatedFatPer100g != nil
            || fiberPer100g != nil
            || proteinPer100g != nil
            || saltPer100g != nil
            || nutritionGrade != nil
            || novaGroup != nil
            || ecoScoreGrade != nil
    }
}

struct NormalizedProduct: Codable, Hashable, Identifiable {
    let id: String
    let barcode: String?
    let name: String
    let brand: String?
    let imageURL: URL?
    let ingredientText: String
    let ingredientTags: [String]
    let categoryTags: [String]
    let additives: [String]
    let allergens: [String]
    let category: ProductCategory
    let source: ScanSource
    let nutrition: NutritionSnapshot?
    let ocrConfidence: Double?
    let ingredientsProvenance: IngredientProvenance
    let capturedAt: Date

    init(
        id: String,
        barcode: String?,
        name: String,
        brand: String?,
        imageURL: URL?,
        ingredientText: String,
        ingredientTags: [String],
        categoryTags: [String],
        additives: [String],
        allergens: [String],
        category: ProductCategory,
        source: ScanSource,
        nutrition: NutritionSnapshot? = nil,
        ocrConfidence: Double? = nil,
        ingredientsProvenance: IngredientProvenance,
        capturedAt: Date
    ) {
        self.id = id
        self.barcode = barcode
        self.name = name
        self.brand = brand
        self.imageURL = imageURL
        self.ingredientText = ingredientText
        self.ingredientTags = ingredientTags
        self.categoryTags = categoryTags
        self.additives = additives
        self.allergens = allergens
        self.category = category
        self.source = source
        self.nutrition = nutrition
        self.ocrConfidence = ocrConfidence
        self.ingredientsProvenance = ingredientsProvenance
        self.capturedAt = capturedAt
    }

    var subtitle: String {
        [brand, category.displayName].compactMap { $0 }.joined(separator: " • ")
    }

    var isOCRBacked: Bool {
        ingredientsProvenance == .ocr
    }
}

struct AnalyzedProduct: Codable, Hashable, Identifiable {
    let id: String
    let product: NormalizedProduct
    let ingredients: [IngredientToken]
    let highlightCards: [HighlightCard]
    let summary: InsightSummary
    let generatedAt: Date

    init(product: NormalizedProduct, ingredients: [IngredientToken], highlightCards: [HighlightCard], summary: InsightSummary, generatedAt: Date = .now) {
        self.id = product.id
        self.product = product
        self.ingredients = ingredients
        self.highlightCards = highlightCards
        self.summary = summary
        self.generatedAt = generatedAt
    }
}

struct IngredientGlossaryItem: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let aliases: [String]
    let category: ProductCategory
    let summary: String
    let function: String
    let caution: Bool
    let markers: [AnalysisMarker]
}

struct OCRResult: Codable, Hashable {
    let text: String
    let confidence: Double
    let lines: [String]
}

struct ProductLookupResult: Hashable {
    let product: NormalizedProduct?
    let message: String?
}

enum LookupStatus: Equatable {
    case idle
    case scanning
    case lookingUp(String)
    case needsOCR(String)
    case error(String)
}

struct RecentScanSummary: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let summary: String
    let barcode: String?
    let scannedAt: Date
    let source: ScanSource
}

extension NormalizedProduct {
    static func ocrPlaceholder(
        text: String,
        category: ProductCategory,
        barcode: String? = nil,
        name: String = "Scanned Ingredient Label",
        brand: String? = nil,
        imageURL: URL? = nil,
        source: ScanSource = .ocr
    ) -> NormalizedProduct {
        NormalizedProduct(
            id: barcode ?? UUID().uuidString,
            barcode: barcode,
            name: name,
            brand: brand,
            imageURL: imageURL,
            ingredientText: text,
            ingredientTags: [],
            categoryTags: [],
            additives: [],
            allergens: [],
            category: category,
            source: source,
            nutrition: nil,
            ingredientsProvenance: .ocr,
            capturedAt: .now
        )
    }
}

extension AnalyzedProduct {
    var cautionCount: Int {
        ingredients.filter { $0.severity == .caution }.count
    }

    var unknownCount: Int {
        ingredients.filter { $0.severity == .unknown }.count
    }

    var simpleCount: Int {
        ingredients.filter { $0.severity == .safe }.count
    }

    var featuredIngredients: [IngredientToken] {
        let caution = ingredients.filter { $0.severity == .caution }
        if !caution.isEmpty {
            return caution
        }

        let unknown = ingredients.filter { $0.severity == .unknown }
        if !unknown.isEmpty {
            return unknown
        }

        return Array(ingredients.prefix(3))
    }
}
