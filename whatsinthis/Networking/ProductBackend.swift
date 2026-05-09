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

/// Stable app-facing boundary for product data.
///
/// The current app adapts Open Food Facts / Open Beauty Facts / USDA through
/// `ProviderProductBackend`. A future Go service can implement the same
/// contract without forcing scan or result UI code to know about provider-
/// specific networking details.
protocol ProductBackend {
    func lookupProduct(_ request: ProductLookupRequest) async throws -> ProductLookupResult
    func similarProducts(_ request: SimilarProductsRequest) async throws -> [NormalizedProduct]
}

/// Adapter that keeps the current provider-based implementation behind the
/// app-facing `ProductBackend` boundary.
struct ProviderProductBackend: ProductBackend {
    private let transport: ProductBackendTransport

    init(productService: ProductServicing) {
        self.transport = LocalProductBackendTransport(productService: productService)
    }

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
}
