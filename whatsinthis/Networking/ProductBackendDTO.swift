//
//  ProductBackendDTO.swift
//  whatsinthis
//
//  Created by Codex on 02/05/2026.
//

import Foundation

struct BackendProductLookupRequestDTO: Codable, Sendable, Hashable {
    let barcode: String
    let localeIdentifier: String
}

struct BackendSimilarProductsRequestDTO: Codable, Sendable, Hashable {
    let product: BackendProductDTO
    let limit: Int
}

struct BackendProductLookupResponseDTO: Codable, Sendable, Hashable {
    let product: BackendProductDTO?
    let message: String?
}

struct BackendNutritionDTO: Codable, Sendable, Hashable {
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

enum BackendProductCategoryDTO: String, Codable, Sendable, Hashable {
    case food
    case beauty
    case unknown
}

enum BackendScanSourceDTO: String, Codable, Sendable, Hashable {
    case openFoodFacts
    case openBeautyFacts
    case usda
    case ocr
    case cache
}

enum BackendIngredientProvenanceDTO: String, Codable, Sendable, Hashable {
    case api
    case ocr
    case glossary
    case inferred
}

struct BackendProductDTO: Codable, Sendable, Hashable, Identifiable {
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
    func glossaryItems() async throws -> [IngredientGlossaryItem]
}

struct BackendHTTPError: Error, LocalizedError, Sendable {
    let statusCode: Int
    let message: String

    var errorDescription: String? {
        "Backend request failed with HTTP \(statusCode): \(message)"
    }
}

struct HTTPProductBackendTransport: ProductBackendTransport {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func lookupProduct(_ request: BackendProductLookupRequestDTO) async throws -> BackendProductLookupResponseDTO {
        try await post(pathComponents: ["v1", "products", "lookup"], body: request)
    }

    func similarProducts(_ request: BackendSimilarProductsRequestDTO) async throws -> [BackendProductDTO] {
        try await post(pathComponents: ["v1", "products", "similar"], body: request, endpoint: .similarProducts)
    }

    func glossaryItems() async throws -> [IngredientGlossaryItem] {
        var request = URLRequest(url: endpoint(pathComponents: ["v1", "glossary"]))
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data, endpoint: .glossary)
        return try Self.decoder.decode([IngredientGlossaryItem].self, from: data)
    }

    private func post<Request: Encodable, Response: Decodable>(
        pathComponents: [String],
        body: Request,
        endpoint endpointKind: BackendEndpoint = .lookup
    ) async throws -> Response {
        var request = URLRequest(url: endpoint(pathComponents: pathComponents))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try Self.encoder.encode(body)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data, endpoint: endpointKind)
        return try Self.decoder.decode(Response.self, from: data)
    }

    private func endpoint(pathComponents: [String]) -> URL {
        pathComponents.reduce(baseURL) { url, component in
            url.appendingPathComponent(component)
        }
    }

    private func validate(response: URLResponse, data: Data, endpoint: BackendEndpoint) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            switch (endpoint, httpResponse.statusCode) {
            case (.similarProducts, 429):
                throw SimilarProductsLookupError.rateLimited
            case (.similarProducts, 503):
                throw SimilarProductsLookupError.serviceUnavailable
            default:
                let message = (try? Self.decoder.decode(BackendErrorResponse.self, from: data))?.error
                    ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                throw BackendHTTPError(statusCode: httpResponse.statusCode, message: message)
            }
        }
    }

    private enum BackendEndpoint {
        case lookup
        case similarProducts
        case glossary
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            try container.encode(formatter.string(from: date))
        }
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let timestamp = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: timestamp)
            }
            let value = try container.decode(String.self)
            for options: ISO8601DateFormatter.Options in [
                [.withInternetDateTime, .withFractionalSeconds],
                [.withInternetDateTime],
            ] {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = options
                if let date = formatter.date(from: value) {
                    return date
                }
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid backend date: \(value)")
        }
        return decoder
    }
}

private struct BackendErrorResponse: Decodable {
    let error: String
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
