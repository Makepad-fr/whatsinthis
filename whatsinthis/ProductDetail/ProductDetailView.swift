//
//  ProductDetailView.swift
//  whatsinthis
//
//  Created by Codex on 28/04/2026.
//

import SwiftUI

struct ProductDetailView: View {
    @StateObject var viewModel: ProductDetailViewModel
    @State private var selectedIngredient: IngredientToken?
    @State private var selectedRecommendedProduct: AnalyzedProduct?
    @State private var showsLearnMode = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ProductHeroCard(
                    imageData: viewModel.imageData,
                    name: viewModel.product.name,
                    metadata: viewModel.headerMetadata,
                    statusTitle: viewModel.headerStatus.title,
                    statusSubtitle: viewModel.headerStatus.subtitle,
                    severity: viewModel.headerStatus.severity
                )

                topSummarySection

                if viewModel.hasNutritionTab {
                    NutritionSummaryCardView(
                        metrics: viewModel.nutritionMetrics,
                        worthNoticing: viewModel.negativeNutritionInsights,
                        goodPoints: viewModel.positiveNutritionInsights
                    )
                }

                if viewModel.showsSwapSection {
                    SimilarProductsToCompareCardView(
                        title: viewModel.swapSectionTitle,
                        recommendations: viewModel.swapRecommendations,
                        isLoading: viewModel.isLoadingSwapRecommendations,
                        emptyStateMessage: viewModel.swapSectionEmptyMessage
                    ) { recommendation in
                        selectedRecommendedProduct = recommendation.analyzedProduct
                    }
                }

                CompactIngredientsCardView(
                    rows: viewModel.ingredientRows,
                    countLabel: viewModel.ingredientCountLabel,
                    showsLearnMode: showsLearnMode
                ) { token in
                    selectedIngredient = token
                } onToggleLearnMode: {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        showsLearnMode.toggle()
                    }
                }

            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Result")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedIngredient) { token in
            IngredientDetailView(token: token)
                .presentationDetents([.medium, .large])
        }
        .navigationDestination(item: $selectedRecommendedProduct) { product in
            ProductDetailView(
                viewModel: viewModel.makeDetailViewModel(for: product)
            )
        }
        .task {
            await viewModel.loadImageIfNeeded()
            await viewModel.loadSwapRecommendationsIfNeeded()
        }
    }

    private var topSummarySection: some View {
        let layout = horizontalSizeClass == .regular
            ? AnyLayout(HStackLayout(alignment: .top, spacing: 12))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 12))

        return layout {
            AtAGlanceCardView(
                items: viewModel.atAGlanceItems,
                chips: viewModel.summaryChips
            )
            .frame(maxWidth: .infinity, alignment: .topLeading)

            WhatToCompareCardView(criteria: viewModel.comparisonCriteria)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}
