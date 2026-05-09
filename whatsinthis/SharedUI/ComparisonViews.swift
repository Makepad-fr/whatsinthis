//
//  ComparisonViews.swift
//  whatsinthis
//
//  Created by Codex on 01/05/2026.
//

import SwiftUI

struct SimilarProductsToCompareCardView: View {
    let title: String
    let recommendations: [ProductDetailViewModel.SwapRecommendation]
    let isLoading: Bool
    let emptyStateMessage: String?
    let onTap: (ProductDetailViewModel.SwapRecommendation) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeadingView(
                title: title,
                subtitle: nil,
                trailingText: nil
            )

            if isLoading, recommendations.isEmpty {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Finding similar products with lighter nutrition or fewer additives…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else if let emptyStateMessage, recommendations.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "arrow.triangle.swap")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)

                    Text(emptyStateMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recommendations.enumerated()), id: \.element.id) { index, recommendation in
                        SwapIdeaCardView(recommendation: recommendation) {
                            onTap(recommendation)
                        }

                        if index < recommendations.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 18)
                .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                Text("Based on product database. Availability may vary.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 2)
            }
        }
    }
}

struct SwapIdeaCardView: View {
    let recommendation: ProductDetailViewModel.SwapRecommendation
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    SwapProductThumbnailView(
                        imageURL: recommendation.analyzedProduct.product.imageURL,
                        fallbackSystemImage: iconName,
                        tint: iconTint
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(recommendation.title)
                            .font(.headline)
                            .multilineTextAlignment(.leading)

                        if let subtitle = recommendation.subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }

                Text(recommendation.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                    ForEach(recommendation.reasons) { reason in
                        SwapReasonPill(reason: reason)
                    }
                }
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var iconName: String {
        switch recommendation.presentation {
        case .recommended:
            return "arrow.triangle.swap"
        case .similar:
            return "square.grid.2x2"
        }
    }

    private var iconTint: Color {
        switch recommendation.presentation {
        case .recommended:
            return .green
        case .similar:
            return Color(uiColor: .secondaryLabel)
        }
    }
}

struct SwapProductThumbnailView: View {
    let imageURL: URL?
    let fallbackSystemImage: String
    let tint: Color

    var body: some View {
        AsyncImage(url: imageURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .empty:
                thumbnailFallback
            case .failure:
                thumbnailFallback
            @unknown default:
                thumbnailFallback
            }
        }
        .frame(width: 52, height: 52)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
    }

    private var thumbnailFallback: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.12))

            Image(systemName: fallbackSystemImage)
                .font(.headline)
                .foregroundStyle(tint)
        }
    }
}

struct SwapReasonPill: View {
    let reason: ProductDetailViewModel.SwapReason

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: reason.systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(IngredientVisualStyle.accent(for: reason.severity))

            Text(reason.text)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.leading)
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(IngredientVisualStyle.background(for: reason.severity), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
