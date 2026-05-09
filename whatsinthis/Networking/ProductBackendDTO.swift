//
//  ProductBackendDTO.swift
//  whatsinthis
//
//  Created by Codex on 02/05/2026.
//

import Foundation

struct BackendProductLookupRequestDTO: Sendable, Hashable {
    let barcode: String
    let localeIdentifier: String
}

struct BackendSimilarProductsRequestDTO: Sendable, Hashable {
    let product: BackendProductDTO
    let limit: Int
}

struct BackendProductLookupResponseDTO: Sendable, Hashable {
    let product: BackendProductDTO?
    let message: String?
}

struct BackendNutritionDTO: Sendable, Hashable {
    let energyKcalPer100g: Double?
    let sugarsPer100g: Double?
    let saturatedFatPer100g: Double?
    let fiberPer100g: Double?
    let proteinPer100g: Double?
    let saltPer100g: Double?
    let nutritionGrade: String?
    let novaGroup: Int?
    let ecoScoreGrade: String?
}

enum BackendProductCategoryDTO: String, Sendable, Hashable {
    case food
    case beauty
    case unknown
}

enum BackendScanSourceDTO: String, Sendable, Hashable {
    case openFoodFacts
    case openBeautyFacts
    case usda
    case ocr
    case cache
}

enum BackendIngredientProvenanceDTO: String, Sendable, Hashable {
    case api
    case ocr
    case glossary
    case inferred
}

struct BackendProductDTO: Sendable, Hashable, Identifiable {
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
    let category: BackendProductCategoryDTO
    let source: BackendScanSourceDTO
    let nutrition: BackendNutritionDTO?
    let ocrConfidence: Double?
    let ingredientsProvenance: BackendIngredientProvenanceDTO
    let capturedAt: Date
}

protocol ProductBackendTransport {
    func lookupProduct(_ request: BackendProductLookupRequestDTO) async throws -> BackendProductLookupResponseDTO
    func similarProducts(_ request: BackendSimilarProductsRequestDTO) async throws -> [BackendProductDTO]
}

struct LocalProductBackendTransport: ProductBackendTransport {
    private let productService: ProductServicing

    init(productService: ProductServicing) {
        self.productService = productService
    }

    func lookupProduct(_ request: BackendProductLookupRequestDTO) async throws -> BackendProductLookupResponseDTO {
        let result = try await productService.lookupProduct(
            barcode: request.barcode,
            locale: Locale(identifier: request.localeIdentifier)
        )
        return BackendProductLookupResponseDTO(
            product: result.product?.backendDTO,
            message: result.message
        )
    }

    func similarProducts(_ request: BackendSimilarProductsRequestDTO) async throws -> [BackendProductDTO] {
        let products = try await productService.similarProducts(
            for: request.product.normalizedProduct,
            limit: request.limit
        )
        return products.map(\.backendDTO)
    }
}

extension ProductLookupRequest {
    var backendDTO: BackendProductLookupRequestDTO {
        BackendProductLookupRequestDTO(
            barcode: barcode,
            localeIdentifier: locale.identifier
        )
    }
}

extension SimilarProductsRequest {
    var backendDTO: BackendSimilarProductsRequestDTO {
        BackendSimilarProductsRequestDTO(
            product: product.backendDTO,
            limit: limit
        )
    }
}

extension ProductLookupResult {
    init(backendDTO: BackendProductLookupResponseDTO) {
        self.init(
            product: backendDTO.product?.normalizedProduct,
            message: backendDTO.message
        )
    }
}

extension NormalizedProduct {
    var backendDTO: BackendProductDTO {
        BackendProductDTO(
            id: id,
            barcode: barcode,
            name: name,
            brand: brand,
            imageURL: imageURL,
            ingredientText: ingredientText,
            ingredientTags: ingredientTags,
            categoryTags: categoryTags,
            additives: additives,
            allergens: allergens,
            category: .init(category),
            source: .init(source),
            nutrition: nutrition.map(BackendNutritionDTO.init),
            ocrConfidence: ocrConfidence,
            ingredientsProvenance: .init(ingredientsProvenance),
            capturedAt: capturedAt
        )
    }
}

extension BackendProductDTO {
    var normalizedProduct: NormalizedProduct {
        NormalizedProduct(
            id: id,
            barcode: barcode,
            name: name,
            brand: brand,
            imageURL: imageURL,
            ingredientText: ingredientText,
            ingredientTags: ingredientTags,
            categoryTags: categoryTags,
            additives: additives,
            allergens: allergens,
            category: category.productCategory,
            source: source.scanSource,
            nutrition: nutrition?.nutritionSnapshot,
            ocrConfidence: ocrConfidence,
            ingredientsProvenance: ingredientsProvenance.ingredientProvenance,
            capturedAt: capturedAt
        )
    }
}

extension BackendNutritionDTO {
    init(_ value: NutritionSnapshot) {
        self.init(
            energyKcalPer100g: value.energyKcalPer100g,
            sugarsPer100g: value.sugarsPer100g,
            saturatedFatPer100g: value.saturatedFatPer100g,
            fiberPer100g: value.fiberPer100g,
            proteinPer100g: value.proteinPer100g,
            saltPer100g: value.saltPer100g,
            nutritionGrade: value.nutritionGrade,
            novaGroup: value.novaGroup,
            ecoScoreGrade: value.ecoScoreGrade
        )
    }

    var nutritionSnapshot: NutritionSnapshot {
        NutritionSnapshot(
            energyKcalPer100g: energyKcalPer100g,
            sugarsPer100g: sugarsPer100g,
            saturatedFatPer100g: saturatedFatPer100g,
            fiberPer100g: fiberPer100g,
            proteinPer100g: proteinPer100g,
            saltPer100g: saltPer100g,
            nutritionGrade: nutritionGrade,
            novaGroup: novaGroup,
            ecoScoreGrade: ecoScoreGrade
        )
    }
}

extension BackendProductCategoryDTO {
    init(_ value: ProductCategory) {
        switch value {
        case .food: self = .food
        case .beauty: self = .beauty
        case .unknown: self = .unknown
        }
    }

    var productCategory: ProductCategory {
        switch self {
        case .food: .food
        case .beauty: .beauty
        case .unknown: .unknown
        }
    }
}

extension BackendScanSourceDTO {
    init(_ value: ScanSource) {
        switch value {
        case .openFoodFacts: self = .openFoodFacts
        case .openBeautyFacts: self = .openBeautyFacts
        case .usda: self = .usda
        case .ocr: self = .ocr
        case .cache: self = .cache
        }
    }

    var scanSource: ScanSource {
        switch self {
        case .openFoodFacts: .openFoodFacts
        case .openBeautyFacts: .openBeautyFacts
        case .usda: .usda
        case .ocr: .ocr
        case .cache: .cache
        }
    }
}

extension BackendIngredientProvenanceDTO {
    init(_ value: IngredientProvenance) {
        switch value {
        case .api: self = .api
        case .ocr: self = .ocr
        case .glossary: self = .glossary
        case .inferred: self = .inferred
        }
    }

    var ingredientProvenance: IngredientProvenance {
        switch self {
        case .api: .api
        case .ocr: .ocr
        case .glossary: .glossary
        case .inferred: .inferred
        }
    }
}
