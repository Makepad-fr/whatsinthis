//
//  BackendConfiguration.swift
//  whatsinthis
//
//  Created by Codex on 09/05/2026.
//

import Foundation

enum BackendConfiguration {
    static let unavailableMessage = "The product backend is not configured for this build."

    static func baseURL(bundle: Bundle = .main) -> URL? {
        let value = (bundle.object(forInfoDictionaryKey: "WhatsInThisBackendBaseURL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let value, !value.isEmpty, let url = URL(string: value) {
            return url
        }

        #if DEBUG
        return URL(string: "http://127.0.0.1:8080")!
        #else
        return nil
        #endif
    }
}

struct UnavailableProductBackend: ProductBackend {
    let message: String

    init(message: String = BackendConfiguration.unavailableMessage) {
        self.message = message
    }

    func lookupProduct(_ request: ProductLookupRequest) async throws -> ProductLookupResult {
        ProductLookupResult(product: nil, message: message)
    }

    func similarProducts(_ request: SimilarProductsRequest) async throws -> [NormalizedProduct] {
        throw SimilarProductsLookupError.unavailable
    }

    func glossaryItems() async throws -> [IngredientGlossaryItem] {
        throw BackendConfigurationError.missingBaseURL
    }
}

enum BackendConfigurationError: Error, LocalizedError, Sendable {
    case missingBaseURL

    var errorDescription: String? {
        BackendConfiguration.unavailableMessage
    }
}
