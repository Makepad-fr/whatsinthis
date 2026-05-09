//
//  ProductDetailViewModel.swift
//  whatsinthis
//
//  Created by Codex on 28/04/2026.
//

import Combine
import Foundation

@MainActor
final class ProductDetailViewModel: ObservableObject {
    struct HeaderStatus {
        let title: String
        let subtitle: String
        let severity: FlagSeverity
    }

    struct Takeaway: Identifiable, Hashable {
        let id = UUID()
        let text: String
        let severity: FlagSeverity
        let systemImage: String
    }

    struct SummaryChip: Identifiable, Hashable {
        let id = UUID()
        let text: String
        let severity: FlagSeverity
        let systemImage: String
    }

    struct ComparisonCriterion: Identifiable, Hashable {
        let id = UUID()
        let text: String
        let systemImage: String
    }

    struct NutritionMetric: Identifiable, Hashable {
        let id = UUID()
        let title: String
        let valueText: String
        let severity: FlagSeverity
        let systemImage: String
    }

    struct NutritionInsight: Identifiable, Hashable {
        let id = UUID()
        let title: String
        let subtitle: String
        let valueText: String
        let systemImage: String
        let severity: FlagSeverity
    }

    struct IngredientRow: Identifiable, Hashable {
        let id: UUID
        let token: IngredientToken
        let position: Int
        let notice: String?
        let compactRole: String
        let whatItIs: String
        let whyItMatters: String?
        let usedFor: String?
        let severity: FlagSeverity
    }

    struct SwapReason: Identifiable, Hashable {
        let id = UUID()
        let text: String
        let systemImage: String
        let severity: FlagSeverity
    }

    struct SwapRecommendation: Identifiable, Hashable {
        enum Presentation: Hashable {
            case recommended
            case similar
        }

        let id: String
        let analyzedProduct: AnalyzedProduct
        let title: String
        let subtitle: String?
        let summary: String
        let reasons: [SwapReason]
        let presentation: Presentation

        init(
            analyzedProduct: AnalyzedProduct,
            title: String,
            subtitle: String?,
            summary: String,
            reasons: [SwapReason],
            presentation: Presentation
        ) {
            self.id = analyzedProduct.id
            self.analyzedProduct = analyzedProduct
            self.title = title
            self.subtitle = subtitle
            self.summary = summary
            self.reasons = reasons
            self.presentation = presentation
        }
    }

    enum LocalFallbackResult {
        case loaded
        case unavailable(cachedCount: Int, comparableCount: Int)
    }

    struct ScoredRecommendationCandidate {
        let product: NormalizedProduct
        let subtypeOverlap: Int
        let nutritionDistance: Int
        let additiveDistance: Int
    }

    @Published private(set) var analyzedProduct: AnalyzedProduct
    @Published private(set) var imageData: Data?
    @Published var swapRecommendations: [SwapRecommendation] = []
    @Published private(set) var isLoadingSwapRecommendations = false
    @Published var swapSectionTitle = "Compare with similar products"
    @Published var swapSectionStatusMessage: String?

    let imageRepository: ProductImageRepository
    let productBackend: ProductBackend?
    let ingredientAnalyzer: IngredientAnalyzer?
    private var hasLoadedImage = false
    var hasLoadedSwapRecommendations = false

    init(
        analyzedProduct: AnalyzedProduct,
        imageRepository: ProductImageRepository,
        productBackend: ProductBackend? = nil,
        ingredientAnalyzer: IngredientAnalyzer? = nil
    ) {
        self.analyzedProduct = analyzedProduct
        self.imageRepository = imageRepository
        self.productBackend = productBackend
        self.ingredientAnalyzer = ingredientAnalyzer
    }

    var product: NormalizedProduct { analyzedProduct.product }
    var ingredients: [IngredientToken] { analyzedProduct.ingredients }
    var summary: InsightSummary { analyzedProduct.summary }
    var cautionCount: Int { analyzedProduct.cautionCount }
    var unknownCount: Int { analyzedProduct.unknownCount }
    var nutrition: NutritionSnapshot? { product.nutrition }
    var hasNutritionTab: Bool {
        product.category == .food && nutrition?.hasAnyValue == true
    }

    func loadImageIfNeeded() async {
        guard !hasLoadedImage else { return }
        hasLoadedImage = true

        let cacheKey = analyzedProduct.product.barcode ?? analyzedProduct.id
        imageData = await imageRepository.loadImageData(for: cacheKey, remoteURL: analyzedProduct.product.imageURL)
    }

    func loadSwapRecommendationsIfNeeded() async {
        guard !hasLoadedSwapRecommendations else { return }
        hasLoadedSwapRecommendations = true

        guard
            product.category == .food,
            !product.isOCRBacked,
            let nutrition,
            nutrition.hasAnyValue,
            let productBackend,
            let ingredientAnalyzer
        else {
            return
        }

        isLoadingSwapRecommendations = true
        defer { isLoadingSwapRecommendations = false }
        swapSectionStatusMessage = nil

        do {
            let candidates = prioritizedRecommendationCandidates(
                try await productBackend.similarProducts(
                    SimilarProductsRequest(product: product, limit: 6)
                )
            )
            let recommendations = candidates.compactMap { candidate in
                buildSwapRecommendation(for: candidate, using: ingredientAnalyzer)
            }

            if !recommendations.isEmpty {
                swapSectionTitle = "Compare with similar products"
                swapRecommendations = Array(recommendations.prefix(3))
            } else {
                let similarOptions = candidates.compactMap { candidate in
                    buildSimilarOption(for: candidate, using: ingredientAnalyzer)
                }
                if !similarOptions.isEmpty {
                    swapSectionTitle = "Compare with similar products"
                    swapRecommendations = Array(similarOptions.prefix(3))
                } else {
                    switch await applyLocalFallbackRecommendations(using: ingredientAnalyzer) {
                    case .loaded:
                        break
                    case .unavailable:
                        swapSectionTitle = "Compare with similar products"
                        swapRecommendations = []
                    }
                }
            }
        } catch let error as SimilarProductsLookupError {
            switch await applyLocalFallbackRecommendations(using: ingredientAnalyzer) {
            case .loaded:
                break
            case .unavailable(let cachedCount, let comparableCount):
                swapSectionTitle = "Compare with similar products"
                swapRecommendations = []
                swapSectionStatusMessage = localFallbackFailureMessage(
                    for: error,
                    cachedCount: cachedCount,
                    comparableCount: comparableCount
                )
            }
        } catch {
            switch await applyLocalFallbackRecommendations(using: ingredientAnalyzer) {
            case .loaded:
                break
            case .unavailable(_, let comparableCount):
                swapSectionTitle = "Compare with similar products"
                swapRecommendations = []
                if comparableCount == 0 {
                    swapSectionStatusMessage = "Similar products could not be loaded right now, and there are no comparable \(recommendationFamilyLabel) products in your recent scans yet."
                } else {
                    swapSectionStatusMessage = "Similar products could not be loaded right now. Scan another similar product to compare manually."
                }
            }
        }
    }

    func makeDetailViewModel(for analyzedProduct: AnalyzedProduct) -> ProductDetailViewModel {
        ProductDetailViewModel(
            analyzedProduct: analyzedProduct,
            imageRepository: imageRepository,
            productBackend: productBackend,
            ingredientAnalyzer: ingredientAnalyzer
        )
    }
}
