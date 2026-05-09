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
    func remoteBackendMapsTransportDTOsIntoDomainModels() async throws {
        let lookupProduct = ProductDetailFixtures.jamProduct()
        let similarProduct = ProductDetailFixtures.flourProduct()
        let glossaryItem = IngredientGlossaryItem(
            id: "salt",
            name: "Salt",
            aliases: [],
            category: .food,
            summary: "A seasoning.",
            function: "Adds flavor.",
            caution: false,
            markers: []
        )
        let transport = ProductBackendTransportStub(
            lookupResult: BackendProductLookupResponseDTO(
                product: lookupProduct.backendDTO,
                message: "ok"
            ),
            similarProductsResult: [similarProduct.backendDTO],
            glossaryItemsResult: [glossaryItem]
        )
        let backend = RemoteProductBackend(transport: transport)

        let lookup = try await backend.lookupProduct(
            ProductLookupRequest(barcode: "111", locale: Locale(identifier: "fr_FR"))
        )
        let similarProducts = try await backend.similarProducts(
            SimilarProductsRequest(product: lookupProduct, limit: 3)
        )
        let glossaryItems = try await backend.glossaryItems()

        #expect(lookup.product?.id == lookupProduct.id)
        #expect(lookup.message == "ok")
        #expect(similarProducts.map(\.id) == [similarProduct.id])
        #expect(glossaryItems.map(\.id) == ["salt"])
    }

    @Test
    func httpTransportDecodesLookupResponse() async throws {
        let stub = Self.stubbedSession { request in
            #expect(request.url?.path == "/v1/products/lookup")
            let body = try #require(request.httpBody)
            let payload = try JSONDecoder().decode(BackendProductLookupRequestDTO.self, from: body)
            #expect(payload.barcode == "123")

            let data = Data("""
            {
              "product": {
                "id": "123",
                "barcode": "123",
                "name": "Backend Jam",
                "brand": "Makepad",
                "imageURL": "https://example.com/jam.png",
                "ingredientText": "Sugar, fruit",
                "ingredientTags": [],
                "categoryTags": ["en:jams"],
                "additives": [],
                "allergens": [],
                "category": "food",
                "source": "openFoodFacts",
                "nutrition": null,
                "ocrConfidence": null,
                "ingredientsProvenance": "api",
                "capturedAt": "2026-05-09T12:00:00Z"
              },
              "message": null
            }
            """.utf8)
            return (Self.response(for: request, statusCode: 200), data)
        }
        defer { BackendURLProtocolStub.unregister(stub.identifier) }

        let transport = HTTPProductBackendTransport(baseURL: stub.baseURL, session: stub.session)

        let response = try await transport.lookupProduct(
            BackendProductLookupRequestDTO(barcode: "123", localeIdentifier: "fr_FR")
        )

        #expect(response.product?.name == "Backend Jam")
        #expect(response.product?.capturedAt.timeIntervalSince1970 == 1_778_328_000)
    }

    @Test
    func httpTransportDecodesGlossaryResponse() async throws {
        let stub = Self.stubbedSession { request in
            #expect(request.url?.path == "/v1/glossary")
            #expect(request.httpMethod == "GET")

            let data = Data("""
            [
              {
                "id": "salt",
                "name": "Salt",
                "aliases": ["sodium chloride"],
                "category": "food",
                "summary": "A seasoning.",
                "function": "Adds flavor.",
                "caution": true,
                "markers": ["allergen", "additive"]
              }
            ]
            """.utf8)
            return (Self.response(for: request, statusCode: 200), data)
        }
        defer { BackendURLProtocolStub.unregister(stub.identifier) }

        let transport = HTTPProductBackendTransport(baseURL: stub.baseURL, session: stub.session)

        let response = try await transport.glossaryItems()

        #expect(response.map(\.id) == ["salt"])
        #expect(response.first?.category == .food)
        #expect(response.first?.markers == [.allergen, .additive])
    }

    @Test
    func httpTransportMapsRateLimit() async throws {
        let stub = Self.stubbedSession { request in
            (Self.response(for: request, statusCode: 429), Data(#"{"error":"rate limited"}"#.utf8))
        }
        defer { BackendURLProtocolStub.unregister(stub.identifier) }

        let transport = HTTPProductBackendTransport(baseURL: stub.baseURL, session: stub.session)

        do {
            _ = try await transport.similarProducts(
                BackendSimilarProductsRequestDTO(
                    product: ProductDetailFixtures.jamProduct().backendDTO,
                    limit: 3
                )
            )
            #expect(Bool(false))
        } catch let error as SimilarProductsLookupError {
            #expect(error == .rateLimited)
        } catch {
            #expect(Bool(false))
        }
    }

    @Test
    func httpTransportUsesBackendErrorForLookupRateLimit() async throws {
        let stub = Self.stubbedSession { request in
            (Self.response(for: request, statusCode: 429), Data(#"{"error":"lookup rate limited"}"#.utf8))
        }
        defer { BackendURLProtocolStub.unregister(stub.identifier) }

        let transport = HTTPProductBackendTransport(baseURL: stub.baseURL, session: stub.session)

        do {
            _ = try await transport.lookupProduct(
                BackendProductLookupRequestDTO(barcode: "123", localeIdentifier: "fr_FR")
            )
            #expect(Bool(false))
        } catch let error as BackendHTTPError {
            #expect(error.statusCode == 429)
            #expect(error.message == "lookup rate limited")
        } catch {
            #expect(Bool(false))
        }
    }

    private static func stubbedSession(
        handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> StubbedBackendSession {
        let identifier = UUID().uuidString.lowercased()
        BackendURLProtocolStub.register(handler, for: identifier)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [BackendURLProtocolStub.self]
        return StubbedBackendSession(
            identifier: identifier,
            baseURL: URL(string: "https://\(identifier).backend.example")!,
            session: URLSession(configuration: configuration)
        )
    }

    private static func response(for request: URLRequest, statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
    }
}

private struct StubbedBackendSession {
    let identifier: String
    let baseURL: URL
    let session: URLSession
}

private struct ProductBackendTransportStub: ProductBackendTransport {
    let lookupResult: BackendProductLookupResponseDTO
    let similarProductsResult: [BackendProductDTO]
    let glossaryItemsResult: [IngredientGlossaryItem]

    func lookupProduct(_ request: BackendProductLookupRequestDTO) async throws -> BackendProductLookupResponseDTO {
        lookupResult
    }

    func similarProducts(_ request: BackendSimilarProductsRequestDTO) async throws -> [BackendProductDTO] {
        Array(similarProductsResult.prefix(request.limit))
    }

    func glossaryItems() async throws -> [IngredientGlossaryItem] {
        glossaryItemsResult
    }
}

private final class BackendURLProtocolStub: URLProtocol {
    private typealias RequestHandler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

    private static let lock = NSLock()
    nonisolated(unsafe) private static var requestHandlers: [String: RequestHandler] = [:]

    static func register(_ handler: @escaping RequestHandler, for identifier: String) {
        lock.lock()
        defer { lock.unlock() }

        requestHandlers[identifier] = handler
    }

    static func unregister(_ identifier: String) {
        lock.lock()
        defer { lock.unlock() }

        requestHandlers[identifier] = nil
    }

    override class func canInit(with request: URLRequest) -> Bool {
        guard let host = request.url?.host else {
            return false
        }
        return hasRequestHandler(for: host)
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let host = request.url?.host, let requestHandler = Self.requestHandler(for: host) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try requestHandler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    private static func requestHandler(for host: String) -> RequestHandler? {
        let identifier = identifier(for: host)

        lock.lock()
        defer { lock.unlock() }

        return requestHandlers[identifier]
    }

    private static func hasRequestHandler(for host: String) -> Bool {
        let identifier = identifier(for: host)

        lock.lock()
        defer { lock.unlock() }

        return requestHandlers[identifier] != nil
    }

    private static func identifier(for host: String) -> String {
        host.split(separator: ".").first.map(String.init) ?? host
    }
}
