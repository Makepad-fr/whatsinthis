//
//  ProductBackend.swift
//  whatsinthis
//
//  Created by Codex on 01/05/2026.
//

import Foundation

/// Request for resolving a scanned product into a normalized local model.
struct ProductLookupRequest: Sendable {
    let barcode: String
    let locale: Locale
}

/// Request for fetching comparable products for the result screen.
struct SimilarProductsRequest: Sendable {
    let product: NormalizedProduct
    let limit: Int
}

enum SimilarProductsLookupError: Error, Equatable, LocalizedError, Sendable {
    case serviceUnavailable
    case rateLimited
    case unavailable

    var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return "Similar products are temporarily unavailable from Open Food Facts right now."
        case .rateLimited:
            return "Similar product lookups are temporarily rate-limited."
        case .unavailable:
            return "Similar products could not be loaded right now."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .serviceUnavailable:
            return "Scan another similar product to compare manually."
        case .rateLimited:
            return "Try again in a moment, or scan another similar product to compare manually."
        case .unavailable:
            return "Scan another similar product to compare manually."
        }
    }
}

/// Stable app-facing boundary for backend-owned product data.
protocol ProductBackend {
    func lookupProduct(_ request: ProductLookupRequest) async throws -> ProductLookupResult
    func similarProducts(_ request: SimilarProductsRequest) async throws -> [NormalizedProduct]
    func glossaryItems() async throws -> [IngredientGlossaryItem]
}

/// Adapter that keeps backend transport details out of scanner and result UI.
struct RemoteProductBackend: ProductBackend {
    private let transport: ProductBackendTransport

    init(transport: ProductBackendTransport) {
        self.transport = transport
    }

    func lookupProduct(_ request: ProductLookupRequest) async throws -> ProductLookupResult {
        let response = try await transport.lookupProduct(request.backendDTO)
        return ProductLookupResult(backendDTO: response)
    }

    func similarProducts(_ request: SimilarProductsRequest) async throws -> [NormalizedProduct] {
        try await transport.similarProducts(request.backendDTO)
            .map(\.normalizedProduct)
    }

    func glossaryItems() async throws -> [IngredientGlossaryItem] {
        try await transport.glossaryItems()
    }
}
