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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ProductHeaderView(
                    imageData: viewModel.imageData,
                    name: viewModel.product.name,
                    metadata: viewModel.headerMetadata,
                    statusTitle: viewModel.headerStatus.title,
                    statusSubtitle: viewModel.headerStatus.subtitle,
                    severity: viewModel.headerStatus.severity
                )

                AtAGlanceCardView(
                    items: viewModel.atAGlanceItems,
                    chips: viewModel.summaryChips
                )

                if viewModel.hasNutritionTab {
                    NutritionSummaryView(
                        metrics: viewModel.nutritionMetrics,
                        worthNoticing: viewModel.negativeNutritionInsights,
                        goodPoints: viewModel.positiveNutritionInsights
                    )
                }

                if viewModel.showsSwapSection {
                    SwapIdeasView(
                        title: viewModel.swapSectionTitle,
                        recommendations: viewModel.swapRecommendations,
                        isLoading: viewModel.isLoadingSwapRecommendations,
                        emptyStateMessage: viewModel.swapSectionEmptyMessage
                    ) { recommendation in
                        selectedRecommendedProduct = recommendation.analyzedProduct
                    }
                }

                IngredientsSectionView(
                    rows: viewModel.ingredientRows,
                    countLabel: viewModel.ingredientCountLabel
                ) { token in
                    selectedIngredient = token
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
}
