//
//  ProductBackendTests.swift
//  whatsinthisTests
//
//  Created by Codex on 01/05/2026.
//

import Foundation
import Testing
@testable import whatsinthis

struct ProductBackendTests {
    @Test
    func providerBackendMapsTransportDTOsIntoDomainModels() async throws {
        let lookupProduct = ProductDetailFixtures.jamProduct()
        let similarProduct = ProductDetailFixtures.flourProduct()
        let transport = ProductBackendTransportStub(
            lookupResult: BackendProductLookupResponseDTO(
                product: lookupProduct.backendDTO,
                message: "ok"
            ),
            similarProductsResult: [similarProduct.backendDTO]
        )
        let backend = ProviderProductBackend(transport: transport)

        let lookup = try await backend.lookupProduct(
            ProductLookupRequest(barcode: "111", locale: Locale(identifier: "fr_FR"))
        )
        let similarProducts = try await backend.similarProducts(
            SimilarProductsRequest(product: lookupProduct, limit: 3)
        )

        #expect(lookup.product?.id == lookupProduct.id)
        #expect(lookup.message == "ok")
        #expect(similarProducts.map(\.id) == [similarProduct.id])
    }
}

private struct ProductBackendTransportStub: ProductBackendTransport {
    let lookupResult: BackendProductLookupResponseDTO
    let similarProductsResult: [BackendProductDTO]

    func lookupProduct(_ request: BackendProductLookupRequestDTO) async throws -> BackendProductLookupResponseDTO {
        lookupResult
    }

    func similarProducts(_ request: BackendSimilarProductsRequestDTO) async throws -> [BackendProductDTO] {
        Array(similarProductsResult.prefix(request.limit))
    }
}
