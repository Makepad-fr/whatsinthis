//
//  ProductService.swift
//  whatsinthis
//
//  Created by Codex on 28/04/2026.
//

import Foundation

enum SimilarProductsLookupError: Error, LocalizedError, Sendable {
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

protocol ProductServicing {
    func lookupProduct(barcode: String, locale: Locale) async throws -> ProductLookupResult
    func lookupFoodOFF(barcode: String) async throws -> NormalizedProduct?
    func lookupBeautyOBF(barcode: String) async throws -> NormalizedProduct?
    func lookupUSDA(barcode: String) async throws -> NormalizedProduct?
    func similarProducts(for product: NormalizedProduct, limit: Int) async throws -> [NormalizedProduct]
}

final class ProductService: ProductServicing {
    private enum LookupResolution {
        case matched(ProductLookupResult)
        case noMatch
        case sourceFailure
    }

    private struct RecommendationSearchTarget: Hashable {
        let slug: String
        let debugLabel: String

        var cacheKey: String { slug }
        var searchValue: String { debugLabel }
    }

    private struct HTTPStatusError: LocalizedError {
        let code: Int

        var errorDescription: String? {
            "HTTP \(code)"
        }
    }

    private struct SourceAttempt {
        let product: NormalizedProduct?
        let succeeded: Bool
    }

    struct Configuration: Sendable {
        let usdaAPIKey: String?
        let userAgent: String

        static func live(bundle: Bundle = .main) -> Configuration {
            let key = bundle.object(forInfoDictionaryKey: "USDAAPIKey") as? String
            let normalizedKey = key?.trimmingCharacters(in: .whitespacesAndNewlines)
            return Configuration(
                usdaAPIKey: normalizedKey?.isEmpty == true ? nil : normalizedKey,
                userAgent: "WhatsInThis/1.0 (iOS)"
            )
        }
    }

    private let configuration: Configuration
    private let session: URLSession
    private let searchSession: URLSession
    private var recommendationCache: [String: [NormalizedProduct]] = [:]
    private var recommendationFailureDates: [String: Date] = [:]
    private let recommendationFailureCooldown: TimeInterval = 90

    init(configuration: Configuration = .live()) {
        self.configuration = configuration

        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.timeoutIntervalForRequest = 1.75
        sessionConfiguration.timeoutIntervalForResource = 3
        sessionConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: sessionConfiguration)

        let searchConfiguration = URLSessionConfiguration.ephemeral
        searchConfiguration.timeoutIntervalForRequest = 3.5
        searchConfiguration.timeoutIntervalForResource = 6
        searchConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.searchSession = URLSession(configuration: searchConfiguration)
    }

    func lookupProduct(barcode: String, locale: Locale) async throws -> ProductLookupResult {
        let scannedBarcode = Self.normalizedBarcode(barcode)
        var sawSourceFailure = false

        for lookupBarcode in Self.lookupCandidates(for: scannedBarcode) {
            switch await lookupProduct(scannedBarcode: scannedBarcode, lookupBarcode: lookupBarcode) {
            case .matched(let result):
                return result
            case .noMatch:
                continue
            case .sourceFailure:
                sawSourceFailure = true
            }
        }

        if sawSourceFailure {
            return ProductLookupResult(
                product: nil,
                message: "The product code was recognized, but the product sources could not return a verified record right now. Check your connection or capture the ingredient label to continue."
            )
        }

        return ProductLookupResult(
            product: nil,
            message: "Recognized product code \(scannedBarcode), but no matching product record was found in Open Food Facts, Open Beauty Facts, or USDA. Capture the ingredient label to continue."
        )
    }

    func lookupFoodOFF(barcode: String) async throws -> NormalizedProduct? {
        let fields = [
            "code", "product_name", "brands", "image_front_small_url", "ingredients_text",
            "ingredients_text_en", "ingredients_tags", "allergens_tags", "additives_tags",
            "abbreviated_product_name", "generic_name",
            "categories_tags", "product_quantity", "quantity",
            "nutriments", "nutrition_grade_fr", "nutriscore_grade", "nova_group", "ecoscore_grade"
        ].joined(separator: ",")
        let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json?fields=\(fields)")!
        let response: OFFProductResponse = try await fetch(url)

        guard response.status == 1, let product = response.product else {
            return nil
        }

        return normalizedFoodProduct(from: product, fallbackBarcode: barcode)
    }

    func lookupBeautyOBF(barcode: String) async throws -> NormalizedProduct? {
        let fields = [
            "code", "product_name", "brands", "image_front_small_url",
            "ingredients_text", "ingredients_tags", "categories_tags",
            "abbreviated_product_name", "generic_name"
        ].joined(separator: ",")
        let url = URL(string: "https://world.openbeautyfacts.org/api/v2/product/\(barcode).json?fields=\(fields)")!
        let response: OBFProductResponse = try await fetch(url)

        guard response.status == 1, let product = response.product else {
            return nil
        }

        let resolvedName = ProductPresentationResolver.resolvedName(
            primaryName: product.productName,
            secondaryName: product.abbreviatedProductName,
            genericName: product.genericName,
            ingredientText: product.ingredientsText ?? "",
            categoryTags: product.categoriesTags ?? []
        )

        return NormalizedProduct(
            id: "beauty-\(barcode)",
            barcode: barcode,
            name: resolvedName,
            brand: product.brands.nonEmpty,
            imageURL: URL(string: product.imageFrontSmallURL ?? ""),
            ingredientText: product.ingredientsText ?? "",
            ingredientTags: product.ingredientsTags ?? [],
            categoryTags: product.categoriesTags ?? [],
            additives: [],
            allergens: [],
            category: .beauty,
            source: .openBeautyFacts,
            nutrition: nil,
            ingredientsProvenance: .api,
            capturedAt: .now
        )
    }

    func lookupUSDA(barcode: String) async throws -> NormalizedProduct? {
        guard let key = configuration.usdaAPIKey else {
            return nil
        }

        var components = URLComponents(string: "https://api.nal.usda.gov/fdc/v1/foods/search")!
        components.queryItems = [
            URLQueryItem(name: "query", value: barcode),
            URLQueryItem(name: "dataType", value: "Branded"),
            URLQueryItem(name: "pageSize", value: "5"),
            URLQueryItem(name: "api_key", value: key),
        ]

        let response: USDASearchResponse = try await fetch(components.url!)
        guard
            let food = response.foods.first(where: {
                Self.normalizedBarcode($0.gtinUpc ?? "") == barcode
            })
        else {
            return nil
        }

        return NormalizedProduct(
            id: "usda-\(food.fdcId)",
            barcode: barcode,
            name: food.description,
            brand: food.brandOwner.nonEmpty,
            imageURL: nil,
            ingredientText: food.ingredients.nonEmpty ?? "",
            ingredientTags: [],
            categoryTags: [food.foodCategory ?? "branded"],
            additives: [],
            allergens: [],
            category: .food,
            source: .usda,
            nutrition: nil,
            ingredientsProvenance: .api,
            capturedAt: .now
        )
    }

    func similarProducts(for product: NormalizedProduct, limit: Int) async throws -> [NormalizedProduct] {
        guard product.category == .food, limit > 0 else {
            return []
        }

        let fields = [
            "code", "product_name", "brands", "image_front_small_url", "ingredients_text",
            "ingredients_tags", "allergens_tags", "additives_tags",
            "categories_tags", "nutriments", "nutrition_grade_fr", "nutriscore_grade",
            "nova_group"
        ].joined(separator: ",")

        let currentBarcode = Self.normalizedBarcode(product.barcode ?? "")
        let currentName = normalizedName(product.name)
        let pageSize = String(min(max(limit, 4), 6))

        var candidates: [NormalizedProduct] = []
        let targets = Array(recommendationSearchTargets(for: product).prefix(2))
        var saw503 = false
        var saw429 = false
        var sawOtherFailure = false

#if DEBUG
        print("[WIT Similar] start name=\(product.name) targets=\(targets.map { $0.debugLabel }) pageSize=\(pageSize)")
#endif

        for target in targets {
            if let cached = recommendationCache[target.cacheKey] {
#if DEBUG
                print("[WIT Similar] target='\(target.debugLabel)' cache-hit matches=\(cached.count)")
#endif
                candidates.append(contentsOf: cached)
                continue
            }

            if let failedAt = recommendationFailureDates[target.cacheKey],
               Date().timeIntervalSince(failedAt) < recommendationFailureCooldown {
#if DEBUG
                print("[WIT Similar] target='\(target.debugLabel)' skipped recent-failure")
#endif
                continue
            }

            do {
                let matches = try await fetchSimilarFoodProductsSearch(
                    target: target,
                    pageSize: pageSize,
                    fields: fields
                )
                recommendationCache[target.cacheKey] = matches
                recommendationFailureDates[target.cacheKey] = nil
#if DEBUG
                print("[WIT Similar] target='\(target.debugLabel)' matches=\(matches.count)")
#endif
                candidates.append(contentsOf: matches)
                if !matches.isEmpty {
                    break
                }
            } catch let error as HTTPStatusError {
                recommendationFailureDates[target.cacheKey] = Date()
                saw503 = saw503 || error.code == 503
                saw429 = saw429 || error.code == 429
                sawOtherFailure = sawOtherFailure || (error.code != 503 && error.code != 429)
#if DEBUG
                print("[WIT Similar] target='\(target.debugLabel)' failed status=\(error.code)")
#endif
                if error.code == 429 {
                    break
                }
            } catch {
                recommendationFailureDates[target.cacheKey] = Date()
                sawOtherFailure = true
#if DEBUG
                print("[WIT Similar] target='\(target.debugLabel)' failed error=\(error.localizedDescription)")
#endif
            }

            if candidates.count >= max(limit * 2, 8) {
                break
            }
        }

        let filtered = deduplicatedProducts(candidates)
            .filter { candidate in
                let candidateBarcode = Self.normalizedBarcode(candidate.barcode ?? "")
                let sameBarcode = !currentBarcode.isEmpty && candidateBarcode == currentBarcode
                let sameName = normalizedName(candidate.name) == currentName
                return !sameBarcode && !sameName
            }
            .filter { $0.nutrition?.hasAnyValue == true }
            .prefix(limit)
            .map { $0 }

#if DEBUG
        print("[WIT Similar] final candidates=\(filtered.count)")
#endif

        if filtered.isEmpty {
            if saw429 {
                throw SimilarProductsLookupError.rateLimited
            }
            if saw503 {
                throw SimilarProductsLookupError.serviceUnavailable
            }
            if sawOtherFailure {
                throw SimilarProductsLookupError.unavailable
            }
        }

        return filtered
    }

    private func preferredCandidate(from candidates: [NormalizedProduct]) -> NormalizedProduct? {
        candidates
            .sorted { lhs, rhs in
                if lhs.ingredientText.count == rhs.ingredientText.count {
                    return lhs.source.rawValue < rhs.source.rawValue
                }
                return lhs.ingredientText.count > rhs.ingredientText.count
            }
            .first
    }

    private func lookupProduct(scannedBarcode: String, lookupBarcode: String) async -> LookupResolution {
        async let foodAttempt = attemptLookup {
            try await lookupFoodOFF(barcode: lookupBarcode)
        }
        async let beautyAttempt = attemptLookup {
            try await lookupBeautyOBF(barcode: lookupBarcode)
        }
        async let usdaAttempt = attemptLookup {
            try await lookupUSDA(barcode: lookupBarcode)
        }

        let food = await foodAttempt
        let beauty = await beautyAttempt
        let usda = await usdaAttempt
        let attempts = [food, beauty, usda]
        let candidates = attempts
            .compactMap(\.product)
            .map { rebasedProduct($0, scannedBarcode: scannedBarcode) }

        if let preferred = preferredCandidate(from: candidates) {
            if preferred.ingredientText.isEmpty {
                return .matched(ProductLookupResult(
                    product: preferred,
                    message: "Found \(preferred.name) in \(preferred.source.displayName), but that record does not include an ingredient list. Capture the ingredient label to continue."
                ))
            }

            return .matched(ProductLookupResult(product: preferred, message: nil))
        }

        if attempts.allSatisfy({ !$0.succeeded }) {
            return .sourceFailure
        }

        return .noMatch
    }

    private func fetch<Response: Decodable>(_ url: URL, session: URLSession? = nil, timeoutInterval: TimeInterval? = nil) async throws -> Response {
        var request = URLRequest(url: url)
        request.setValue(configuration.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let timeoutInterval {
            request.timeoutInterval = timeoutInterval
        }

        let (data, response) = try await (session ?? self.session).data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw HTTPStatusError(code: httpResponse.statusCode)
        }

        return try JSONDecoder().decode(Response.self, from: data)
    }

    private nonisolated static func normalizedBarcode(_ barcode: String) -> String {
        barcode.filter(\.isNumber)
    }

    private nonisolated static func lookupCandidates(for barcode: String) -> [String] {
        guard !barcode.isEmpty else {
            return []
        }

        if barcode.count == 14, barcode.hasPrefix("0") {
            return [barcode, String(barcode.dropFirst())]
        }

        return [barcode]
    }

    private func rebasedProduct(_ product: NormalizedProduct, scannedBarcode: String) -> NormalizedProduct {
        guard product.barcode != scannedBarcode else {
            return product
        }

        return NormalizedProduct(
            id: product.id,
            barcode: scannedBarcode,
            name: product.name,
            brand: product.brand,
            imageURL: product.imageURL,
            ingredientText: product.ingredientText,
            ingredientTags: product.ingredientTags,
            categoryTags: product.categoryTags,
            additives: product.additives,
            allergens: product.allergens,
            category: product.category,
            source: product.source,
            nutrition: product.nutrition,
            ingredientsProvenance: product.ingredientsProvenance,
            capturedAt: product.capturedAt
        )
    }

    private func attemptLookup(_ operation: () async throws -> NormalizedProduct?) async -> SourceAttempt {
        do {
            return SourceAttempt(product: try await operation(), succeeded: true)
        } catch {
            return SourceAttempt(product: nil, succeeded: false)
        }
    }

    private func normalizedFoodProduct(from product: OFFProduct, fallbackBarcode: String) -> NormalizedProduct? {
        let resolvedBarcode = product.code.nonEmpty ?? fallbackBarcode
        guard !resolvedBarcode.isEmpty else { return nil }

        let ingredientText = product.ingredientsTextEn.nonEmpty ?? product.ingredientsText.nonEmpty ?? ""
        let resolvedName = ProductPresentationResolver.resolvedName(
            primaryName: product.productName,
            secondaryName: product.abbreviatedProductName,
            genericName: product.genericName,
            ingredientText: ingredientText,
            categoryTags: product.categoriesTags ?? []
        )

        return NormalizedProduct(
            id: resolvedBarcode,
            barcode: resolvedBarcode,
            name: resolvedName,
            brand: product.brands.nonEmpty,
            imageURL: URL(string: product.imageFrontSmallURL ?? ""),
            ingredientText: ingredientText,
            ingredientTags: product.ingredientsTags ?? [],
            categoryTags: product.categoriesTags ?? [],
            additives: product.additivesTags ?? [],
            allergens: product.allergensTags ?? [],
            category: .food,
            source: .openFoodFacts,
            nutrition: NutritionSnapshot(
                energyKcalPer100g: product.nutriments?.energyKcal100g,
                sugarsPer100g: product.nutriments?.sugars100g,
                saturatedFatPer100g: product.nutriments?.saturatedFat100g,
                fiberPer100g: product.nutriments?.fiber100g,
                proteinPer100g: product.nutriments?.proteins100g,
                saltPer100g: product.nutriments?.salt100g,
                nutritionGrade: product.nutriscoreGrade.nonEmpty ?? product.nutritionGradeFR.nonEmpty,
                novaGroup: product.novaGroup,
                ecoScoreGrade: product.ecoScoreGrade.nonEmpty
            ),
            ingredientsProvenance: .api,
            capturedAt: .now
        )
    }

    private func fetchSimilarFoodProductsSearch(
        target: RecommendationSearchTarget,
        pageSize: String,
        fields: String
    ) async throws -> [NormalizedProduct] {
        let hosts = [
            "https://world.openfoodfacts.net/api/v2/search",
            "https://world.openfoodfacts.org/api/v2/search"
        ]

        var lastError: Error?

        for host in hosts {
            var components = URLComponents(string: host)!
            components.queryItems = [
                URLQueryItem(name: "categories_tags_en", value: target.searchValue),
                URLQueryItem(name: "page_size", value: pageSize),
                URLQueryItem(name: "sort_by", value: "unique_scans_n"),
                URLQueryItem(name: "fields", value: fields)
            ]

            do {
                let response: OFFSearchResponse = try await fetch(
                    components.url!,
                    session: searchSession,
                    timeoutInterval: 3.5
                )
#if DEBUG
                print("[WIT Similar] host='\(components.host ?? host)' target='\(target.debugLabel)' matches=\(response.products.count)")
#endif
                return response.products.compactMap {
                    normalizedFoodProduct(from: $0, fallbackBarcode: $0.code.nonEmpty ?? "")
                }
            } catch {
#if DEBUG
                let code = (error as? HTTPStatusError)?.code
                if let code {
                    print("[WIT Similar] host='\(components.host ?? host)' target='\(target.debugLabel)' failed status=\(code)")
                } else {
                    print("[WIT Similar] host='\(components.host ?? host)' target='\(target.debugLabel)' failed error=\(error.localizedDescription)")
                }
#endif
                lastError = error
            }
        }

        throw lastError ?? SimilarProductsLookupError.unavailable
    }

    private func rankedRecommendationCategoryTags(from tags: [String]) -> [String] {
        tags
            .filter { $0.contains(":") }
            .filter { !isGenericRecommendationCategoryTag($0) }
            .sorted { lhs, rhs in
                categorySpecificityScore(lhs) > categorySpecificityScore(rhs)
            }
    }

    private func categorySpecificityScore(_ tag: String) -> Int {
        let value = tag.split(separator: ":").last.map(String.init) ?? tag
        let tokenCount = value.split(separator: "-").count
        return value.count + value.filter { $0 == "-" }.count * 8 - tokenCount * 3
    }

    private func recommendationSearchTargets(for product: NormalizedProduct) -> [RecommendationSearchTarget] {
        var targets: [RecommendationSearchTarget] = preferredRecommendationSearchTargets(for: product)

        if targets.isEmpty {
            for tag in rankedRecommendationCategoryTags(from: product.categoryTags).prefix(3) {
                guard let target = recommendationSearchTarget(from: tag) else { continue }
                targets.append(target)
            }
        }

        var seen: Set<String> = []
        return targets
            .filter { !isGenericRecommendationCategorySlug($0.slug) }
            .filter { seen.insert($0.slug).inserted }
            .prefix(3)
            .map { $0 }
    }

    private func preferredRecommendationSearchTargets(for product: NormalizedProduct) -> [RecommendationSearchTarget] {
        let context = normalizedName(([product.name] + product.categoryTags + [product.ingredientText]).joined(separator: " "))

        if matchesAny(of: ["confiture", "jam", "jams", "marmalade", "jelly", "preserve", "preserves"], in: context) {
            return [
                RecommendationSearchTarget(slug: "jams", debugLabel: "jams"),
                RecommendationSearchTarget(slug: "fruit-preserves", debugLabel: "fruit preserves")
            ]
        }

        if matchesAny(of: ["hazelnut spread", "chocolate spread", "cocoa and hazelnut", "pate a tartiner", "sweet spread", "sweet spreads"], in: context) {
            return [
                RecommendationSearchTarget(slug: "cocoa-and-hazelnuts-spreads", debugLabel: "cocoa and hazelnuts spreads"),
                RecommendationSearchTarget(slug: "sweet-spreads", debugLabel: "sweet spreads")
            ]
        }

        if matchesAny(of: ["yogurt", "yoghurt", "yaourt"], in: context) {
            return [RecommendationSearchTarget(slug: "yogurts", debugLabel: "yogurts")]
        }

        if matchesAny(of: ["biscuit", "biscuits", "cookie", "cookies"], in: context) {
            return [
                RecommendationSearchTarget(slug: "biscuits", debugLabel: "biscuits"),
                RecommendationSearchTarget(slug: "cookies", debugLabel: "cookies")
            ]
        }

        if matchesAny(of: ["cereal", "cereals", "granola", "muesli"], in: context) {
            return [
                RecommendationSearchTarget(slug: "breakfast-cereals", debugLabel: "breakfast cereals"),
                RecommendationSearchTarget(slug: "granolas", debugLabel: "granolas"),
                RecommendationSearchTarget(slug: "mueslis", debugLabel: "mueslis")
            ]
        }

        if matchesAny(of: ["soda", "cola", "soft drink", "soft drinks"], in: context) {
            return [
                RecommendationSearchTarget(slug: "sodas", debugLabel: "sodas"),
                RecommendationSearchTarget(slug: "soft-drinks", debugLabel: "soft drinks")
            ]
        }

        return []
    }

    private func isGenericRecommendationCategorySlug(_ slug: String) -> Bool {
        let genericSlugs = [
            "foods",
            "foods-and-beverages",
            "beverages",
            "plant-based-foods",
            "plant-based-foods-and-beverages",
            "fruits-and-vegetables-based-foods",
            "fruit-and-vegetable-preserves",
            "plant-based-spreads",
            "groceries"
        ]

        return genericSlugs.contains(slug)
    }

    private func recommendationSearchTarget(from tag: String) -> RecommendationSearchTarget? {
        let rawValue = tag.split(separator: ":").last.map(String.init) ?? tag
        let slug = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !slug.isEmpty else { return nil }
        return RecommendationSearchTarget(
            slug: slug,
            debugLabel: rawValue.replacingOccurrences(of: "-", with: " ")
        )
    }

    private func humanizedCategoryLabel(from tag: String) -> String? {
        let rawValue = tag.split(separator: ":").last.map(String.init) ?? tag
        guard !rawValue.isEmpty else { return nil }
        return rawValue.replacingOccurrences(of: "-", with: " ")
    }

    private func isGenericRecommendationCategoryTag(_ tag: String) -> Bool {
        let value = normalizedName(tag.split(separator: ":").last.map(String.init) ?? tag)
        let genericPhrases = [
            "foods",
            "foods and beverages",
            "beverages",
            "plant based foods",
            "plant based foods and beverages",
            "fruits and vegetables based foods",
            "fruit and vegetable preserves",
            "plant based spreads",
            "groceries"
        ]
        return genericPhrases.contains { phrase in
            value == phrase || value.hasPrefix("\(phrase) ")
        }
    }

    private func normalizedName(_ name: String) -> String {
        name
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func deduplicatedProducts(_ products: [NormalizedProduct]) -> [NormalizedProduct] {
        var seen: Set<String> = []
        return products.filter { product in
            let barcode = Self.normalizedBarcode(product.barcode ?? "")
            let key = barcode.isEmpty ? normalizedName(product.name) : barcode
            return seen.insert(key).inserted
        }
    }

    private func matchesAny(of candidates: [String], in text: String) -> Bool {
        candidates.contains(where: text.contains)
    }
}

private struct OFFProductResponse: Decodable {
    let status: Int
    let product: OFFProduct?
}

private struct OFFProduct: Decodable {
    let code: String?
    let productName: String?
    let abbreviatedProductName: String?
    let genericName: String?
    let brands: String?
    let imageFrontSmallURL: String?
    let ingredientsText: String?
    let ingredientsTextEn: String?
    let ingredientsTags: [String]?
    let allergensTags: [String]?
    let additivesTags: [String]?
    let categoriesTags: [String]?
    let nutriments: OFFNutriments?
    let nutritionGradeFR: String?
    let nutriscoreGrade: String?
    let novaGroup: Int?
    let ecoScoreGrade: String?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case abbreviatedProductName = "abbreviated_product_name"
        case genericName = "generic_name"
        case brands
        case imageFrontSmallURL = "image_front_small_url"
        case ingredientsText = "ingredients_text"
        case ingredientsTextEn = "ingredients_text_en"
        case ingredientsTags = "ingredients_tags"
        case allergensTags = "allergens_tags"
        case additivesTags = "additives_tags"
        case categoriesTags = "categories_tags"
        case nutriments
        case nutritionGradeFR = "nutrition_grade_fr"
        case nutriscoreGrade = "nutriscore_grade"
        case novaGroup = "nova_group"
        case ecoScoreGrade = "ecoscore_grade"
    }
}

private struct OFFSearchResponse: Decodable {
    let products: [OFFProduct]
}

private struct OBFProductResponse: Decodable {
    let status: Int
    let product: OBFProduct?
}

private struct OBFProduct: Decodable {
    let productName: String?
    let abbreviatedProductName: String?
    let genericName: String?
    let brands: String?
    let imageFrontSmallURL: String?
    let ingredientsText: String?
    let ingredientsTags: [String]?
    let categoriesTags: [String]?

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case abbreviatedProductName = "abbreviated_product_name"
        case genericName = "generic_name"
        case brands
        case imageFrontSmallURL = "image_front_small_url"
        case ingredientsText = "ingredients_text"
        case ingredientsTags = "ingredients_tags"
        case categoriesTags = "categories_tags"
    }
}

private struct USDASearchResponse: Decodable {
    let foods: [USDAFood]
}

private struct USDAFood: Decodable {
    let fdcId: Int
    let description: String
    let brandOwner: String?
    let ingredients: String?
    let gtinUpc: String?
    let foodCategory: String?
}

private struct OFFNutriments: Decodable {
    let energyKcal100g: Double?
    let sugars100g: Double?
    let saturatedFat100g: Double?
    let fiber100g: Double?
    let proteins100g: Double?
    let salt100g: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case sugars100g = "sugars_100g"
        case saturatedFat100g = "saturated-fat_100g"
        case fiber100g = "fiber_100g"
        case proteins100g = "proteins_100g"
        case salt100g = "salt_100g"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        energyKcal100g = container.decodeFlexibleDouble(forKey: .energyKcal100g)
        sugars100g = container.decodeFlexibleDouble(forKey: .sugars100g)
        saturatedFat100g = container.decodeFlexibleDouble(forKey: .saturatedFat100g)
        fiber100g = container.decodeFlexibleDouble(forKey: .fiber100g)
        proteins100g = container.decodeFlexibleDouble(forKey: .proteins100g)
        salt100g = container.decodeFlexibleDouble(forKey: .salt100g)
    }
}

private extension Optional where Wrapped == String {
    var nonEmpty: String? {
        guard let self else { return nil }
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleDouble(forKey key: Key) -> Double? {
        if let doubleValue = ((try? decodeIfPresent(Double.self, forKey: key)) ?? nil) {
            return doubleValue
        }

        if let intValue = ((try? decodeIfPresent(Int.self, forKey: key)) ?? nil) {
            return Double(intValue)
        }

        if let stringValue = ((try? decodeIfPresent(String.self, forKey: key)) ?? nil) {
            return Double(stringValue.replacingOccurrences(of: ",", with: "."))
        }

        return nil
    }
}
