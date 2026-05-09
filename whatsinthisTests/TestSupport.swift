//
//  TestSupport.swift
//  whatsinthisTests
//
//  Created by Codex on 01/05/2026.
//

import Foundation
import SwiftData
@testable import whatsinthis

enum TestSupport {
    static func makeInMemoryDataStore() throws -> DataStore {
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

    static func makeImageRepository() throws -> ProductImageRepository {
        ProductImageRepository(dataStore: try makeInMemoryDataStore())
    }
}

struct RecommendationProductBackendStub: ProductBackend {
    let similarProductsResult: [NormalizedProduct]
    let similarProductsError: (any Error & Sendable)?
    let lookupResult: ProductLookupResult

    init(
        similarProductsResult: [NormalizedProduct],
        similarProductsError: (any Error & Sendable)? = nil,
        lookupResult: ProductLookupResult = ProductLookupResult(product: nil, message: nil)
    ) {
        self.similarProductsResult = similarProductsResult
        self.similarProductsError = similarProductsError
        self.lookupResult = lookupResult
    }

    func lookupProduct(_ request: ProductLookupRequest) async throws -> ProductLookupResult {
        lookupResult
    }

    func similarProducts(_ request: SimilarProductsRequest) async throws -> [NormalizedProduct] {
        if let similarProductsError {
            throw similarProductsError
        }
        return Array(similarProductsResult.prefix(request.limit))
    }

    func glossaryItems() async throws -> [IngredientGlossaryItem] {
        []
    }
}
