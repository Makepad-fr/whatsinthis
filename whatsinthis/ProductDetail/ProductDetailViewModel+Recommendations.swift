//
//  ProductDetailViewModel+Recommendations.swift
//  whatsinthis
//
//  Created by Codex on 28/04/2026.
//

import Foundation

extension ProductDetailViewModel {
    func buildSwapRecommendation(
        for candidate: NormalizedProduct,
        using ingredientAnalyzer: IngredientAnalyzer
    ) -> SwapRecommendation? {
        let analyzedCandidate = ingredientAnalyzer.analyze(product: candidate)
        let comparison = comparisonReasons(for: analyzedCandidate)
        guard comparison.score > 0, !comparison.reasons.isEmpty else {
            return nil
        }

        return SwapRecommendation(
            analyzedProduct: analyzedCandidate,
            title: analyzedCandidate.product.name,
            subtitle: analyzedCandidate.product.brand,
            summary: comparison.summary,
            reasons: comparison.reasons,
            presentation: .recommended
        )
    }

    func buildSimilarOption(
        for candidate: NormalizedProduct,
        using ingredientAnalyzer: IngredientAnalyzer
    ) -> SwapRecommendation? {
        let analyzedCandidate = ingredientAnalyzer.analyze(product: candidate)
        let reasons = comparisonSnapshotReasons(for: analyzedCandidate)
        guard !reasons.isEmpty else { return nil }

        return SwapRecommendation(
            analyzedProduct: analyzedCandidate,
            title: analyzedCandidate.product.name,
            subtitle: analyzedCandidate.product.brand,
            summary: "Same category. Compare the listed nutrition and ingredients before deciding.",
            reasons: reasons,
            presentation: .similar
        )
    }

    func applyLocalFallbackRecommendations(using ingredientAnalyzer: IngredientAnalyzer) async -> LocalFallbackResult {
        let cachedProducts = await imageRepository.recentCachedProducts(limit: 24)
        let localCandidates = prioritizedRecommendationCandidates(
            comparableCachedProducts(from: cachedProducts)
        )

#if DEBUG
        print("[WIT Similar] local-fallback cached=\(cachedProducts.count) comparable=\(localCandidates.count)")
#endif

        let swapIdeas = localCandidates.compactMap { candidate in
            buildSwapRecommendation(for: candidate, using: ingredientAnalyzer)
        }

        if !swapIdeas.isEmpty {
#if DEBUG
            print("[WIT Similar] local-fallback swap-ideas=\(swapIdeas.count)")
#endif
            swapSectionTitle = "Compare with similar products"
            swapRecommendations = Array(swapIdeas.prefix(3))
            swapSectionStatusMessage = nil
            return .loaded
        }

        let similarOptions = localCandidates.compactMap { candidate in
            buildSimilarOption(for: candidate, using: ingredientAnalyzer)
        }

        if !similarOptions.isEmpty {
#if DEBUG
            print("[WIT Similar] local-fallback similar-options=\(similarOptions.count)")
#endif
            swapSectionTitle = "Compare with similar products"
            swapRecommendations = Array(similarOptions.prefix(3))
            swapSectionStatusMessage = nil
            return .loaded
        }

        return .unavailable(cachedCount: cachedProducts.count, comparableCount: localCandidates.count)
    }

    func prioritizedRecommendationCandidates(_ candidates: [NormalizedProduct]) -> [NormalizedProduct] {
        let currentSubtypes = recommendationSubtypeKeywords(for: product)
        let scoredCandidates = candidates.map { candidate in
            ScoredRecommendationCandidate(
                product: candidate,
                subtypeOverlap: recommendationSubtypeOverlap(currentSubtypes: currentSubtypes, candidate: candidate),
                nutritionDistance: nutritionDistanceScore(for: candidate),
                additiveDistance: additiveDistanceScore(for: candidate)
            )
        }

        let filteredCandidates: [ScoredRecommendationCandidate]
        if !currentSubtypes.isEmpty,
           scoredCandidates.contains(where: { $0.subtypeOverlap > 0 }) {
            filteredCandidates = scoredCandidates.filter { $0.subtypeOverlap > 0 }
        } else {
            filteredCandidates = scoredCandidates
        }

        return filteredCandidates
            .sorted { lhs, rhs in
                if lhs.subtypeOverlap != rhs.subtypeOverlap {
                    return lhs.subtypeOverlap > rhs.subtypeOverlap
                }
                if lhs.nutritionDistance != rhs.nutritionDistance {
                    return lhs.nutritionDistance < rhs.nutritionDistance
                }
                if lhs.additiveDistance != rhs.additiveDistance {
                    return lhs.additiveDistance < rhs.additiveDistance
                }
                return ProductDetailFormatting.normalized(lhs.product.name) < ProductDetailFormatting.normalized(rhs.product.name)
            }
            .map(\.product)
    }

    func localFallbackFailureMessage(
        for error: SimilarProductsLookupError,
        cachedCount: Int,
        comparableCount: Int
    ) -> String {
        if comparableCount == 0 {
            if cachedCount == 0 {
                return "\(error.errorDescription ?? "Similar products could not be loaded right now.") You do not have any recent scans saved locally yet."
            }

            return "\(error.errorDescription ?? "Similar products could not be loaded right now.") There are no comparable \(recommendationFamilyLabel) products in your recent scans yet."
        }

        return [error.errorDescription, error.recoverySuggestion]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    func recommendationSubtypeKeywords(for candidate: NormalizedProduct) -> Set<String> {
        ProductRecommendationPlanner.subtypeKeywords(for: candidate)
    }

    func recommendationSubtypeOverlap(currentSubtypes: Set<String>, candidate: NormalizedProduct) -> Int {
        ProductRecommendationPlanner.subtypeOverlap(currentSubtypes: currentSubtypes, candidate: candidate)
    }

    func nutritionDistanceScore(for candidate: NormalizedProduct) -> Int {
        guard let currentNutrition = product.nutrition, let candidateNutrition = candidate.nutrition else {
            return Int.max / 2
        }

        var score = 0
        var comparisons = 0

        func addDistance(_ lhs: Double?, _ rhs: Double?, scale: Double) {
            guard let lhs, let rhs else { return }
            comparisons += 1
            score += Int(abs(lhs - rhs) * scale)
        }

        addDistance(currentNutrition.sugarsPer100g, candidateNutrition.sugarsPer100g, scale: 10)
        addDistance(currentNutrition.saturatedFatPer100g, candidateNutrition.saturatedFatPer100g, scale: 15)
        addDistance(currentNutrition.energyKcalPer100g, candidateNutrition.energyKcalPer100g, scale: 0.5)
        addDistance(currentNutrition.saltPer100g, candidateNutrition.saltPer100g, scale: 100)
        addDistance(currentNutrition.fiberPer100g, candidateNutrition.fiberPer100g, scale: 10)

        guard comparisons > 0 else { return Int.max / 2 }
        return score
    }

    func additiveDistanceScore(for candidate: NormalizedProduct) -> Int {
        abs(candidate.additives.count - comparisonAdditiveCount)
    }

    func comparableCachedProducts(from cachedProducts: [AnalyzedProduct]) -> [NormalizedProduct] {
        let currentBarcode = ProductDetailFormatting.normalized(product.barcode ?? "")
        let currentName = ProductDetailFormatting.normalized(product.name)
        let currentFamily = recommendationFamily
        let currentCategoryLabels = Set(specificNormalizedCategoryLabels(for: product))
        var seen: Set<String> = []

        return cachedProducts
            .map(\.product)
            .filter { candidate in
                guard candidate.category == .food else { return false }
                guard candidate.nutrition?.hasAnyValue == true else { return false }
                guard !candidate.isOCRBacked else { return false }

                let candidateBarcode = ProductDetailFormatting.normalized(candidate.barcode ?? "")
                let candidateName = ProductDetailFormatting.normalized(candidate.name)
                guard candidate.id != product.id else { return false }
                guard currentBarcode.isEmpty || candidateBarcode != currentBarcode else { return false }
                guard candidateName != currentName else { return false }

                let dedupeKey = [candidateBarcode, candidate.id, candidateName].first(where: { !$0.isEmpty }) ?? candidate.id
                guard seen.insert(dedupeKey).inserted else { return false }

                let candidateFamily = ProductRecommendationPlanner.family(for: candidate)
                if currentFamily != .unknown {
                    return candidateFamily == currentFamily
                }

                if candidateFamily != .unknown {
                    return false
                }

                let candidateLabels = Set(specificNormalizedCategoryLabels(for: candidate))
                guard !currentCategoryLabels.isEmpty, !candidateLabels.isEmpty else { return false }
                return !currentCategoryLabels.isDisjoint(with: candidateLabels)
            }
    }

    func specificNormalizedCategoryLabels(for candidate: NormalizedProduct) -> [String] {
        ProductRecommendationPlanner.specificCategoryLabels(for: candidate)
    }

    func isGenericLocalRecommendationCategoryLabel(_ label: String) -> Bool {
        ProductRecommendationPlanner.isGenericLocalRecommendationCategoryLabel(label)
    }

    func comparisonReasons(for candidate: AnalyzedProduct) -> (score: Int, summary: String, reasons: [SwapReason]) {
        guard let currentNutrition = product.nutrition, let candidateNutrition = candidate.product.nutrition else {
            return (0, "", [])
        }

        var reasons: [SwapReason] = []
        var score = 0
        var penalty = 0

        if let currentSugar = currentNutrition.sugarsPer100g, let candidateSugar = candidateNutrition.sugarsPer100g {
            let delta = currentSugar - candidateSugar
            if delta >= 5 {
                reasons.append(
                    SwapReason(
                        text: "\(ProductDetailFormatting.formattedValue(delta, unit: "g")) less sugar",
                        systemImage: "cube.box.fill",
                        severity: .safe
                    )
                )
                score += 4
            } else if delta >= 3, currentSugar >= 20 {
                reasons.append(
                    SwapReason(
                        text: "\(ProductDetailFormatting.formattedValue(delta, unit: "g")) less sugar",
                        systemImage: "cube.box.fill",
                        severity: .safe
                    )
                )
                score += 2
            } else if delta <= -5 {
                penalty += 4
            }
        }

        if let currentSatFat = currentNutrition.saturatedFatPer100g, let candidateSatFat = candidateNutrition.saturatedFatPer100g {
            let delta = currentSatFat - candidateSatFat
            if delta >= 1.5 {
                reasons.append(
                    SwapReason(
                        text: "\(ProductDetailFormatting.formattedValue(delta, unit: "g")) less sat. fat",
                        systemImage: "drop.fill",
                        severity: .safe
                    )
                )
                score += 3
            } else if delta >= 1, currentSatFat >= 3 {
                reasons.append(
                    SwapReason(
                        text: "\(ProductDetailFormatting.formattedValue(delta, unit: "g")) less sat. fat",
                        systemImage: "drop.fill",
                        severity: .safe
                    )
                )
                score += 2
            } else if delta <= -1.5 {
                penalty += 3
            }
        }

        let candidateAdditives = max(
            candidate.product.additives.count,
            candidate.ingredients.flatMap(\.flags).filter { $0.kind == .additive }.count
        )
        let additiveDelta = comparisonAdditiveCount - candidateAdditives
        if additiveDelta >= 1 {
            reasons.append(
                SwapReason(
                    text: additiveDelta == 1 ? "Fewer additives" : "\(additiveDelta) fewer additives",
                    systemImage: "sparkles.rectangle.stack.fill",
                    severity: .safe
                )
            )
            score += 2
        } else if additiveDelta <= -2 {
            penalty += 2
        }

        if let currentFiber = currentNutrition.fiberPer100g, let candidateFiber = candidateNutrition.fiberPer100g {
            let delta = candidateFiber - currentFiber
            if delta >= 2 {
                reasons.append(
                    SwapReason(
                        text: "\(ProductDetailFormatting.formattedValue(delta, unit: "g")) more fiber",
                        systemImage: "leaf.fill",
                        severity: .safe
                    )
                )
                score += 1
            }
        }

        if let currentSalt = currentNutrition.saltPer100g, let candidateSalt = candidateNutrition.saltPer100g {
            let delta = currentSalt - candidateSalt
            if delta >= 0.3, reasons.count < 3 {
                reasons.append(
                    SwapReason(
                        text: "\(ProductDetailFormatting.formattedValue(delta, unit: "g")) less salt",
                        systemImage: "takeoutbag.and.cup.and.straw.fill",
                        severity: .safe
                    )
                )
                score += 1
            } else if delta <= -0.3 {
                penalty += 1
            }
        }

        guard score > penalty else {
            return (0, "", [])
        }

        let reasonTexts = reasons.prefix(2).map { $0.text.lowercased() }
        let summary: String
        if reasonTexts.count >= 2 {
            summary = "Same category · \(reasonTexts[0]) and \(reasonTexts[1])."
        } else if let first = reasonTexts.first {
            summary = "Same category · \(first)."
        } else {
            summary = ""
        }

        return (score - penalty, summary, Array(reasons.prefix(3)))
    }

    func comparisonSnapshotReasons(for candidate: AnalyzedProduct) -> [SwapReason] {
        guard let nutrition = candidate.product.nutrition else { return [] }

        var reasons: [SwapReason] = []

        if let sugar = nutrition.sugarsPer100g {
            reasons.append(
                SwapReason(
                    text: "\(ProductDetailFormatting.formattedValue(sugar, unit: "g")) sugar",
                    systemImage: "cube.box.fill",
                    severity: sugar >= 22.5 ? .caution : .unknown
                )
            )
        }

        if let saturatedFat = nutrition.saturatedFatPer100g {
            reasons.append(
                SwapReason(
                    text: "\(ProductDetailFormatting.formattedValue(saturatedFat, unit: "g")) sat. fat",
                    systemImage: "drop.fill",
                    severity: saturatedFat >= 5 ? .caution : .unknown
                )
            )
        }

        let candidateAdditives = max(
            candidate.product.additives.count,
            candidate.ingredients.flatMap(\.flags).filter { $0.kind == .additive }.count
        )
        reasons.append(
            SwapReason(
                text: candidateAdditives == 0 ? "No additive flags" : (candidateAdditives == 1 ? "1 additive flag" : "\(candidateAdditives) additive flags"),
                systemImage: "sparkles.rectangle.stack.fill",
                severity: candidateAdditives == 0 ? .safe : .unknown
            )
        )

        return Array(reasons.prefix(3))
    }
}
