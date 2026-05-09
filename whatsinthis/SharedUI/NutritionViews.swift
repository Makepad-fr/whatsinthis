//
//  NutritionViews.swift
//  whatsinthis
//
//  Created by Codex on 01/05/2026.
//

import SwiftUI

struct NutritionSummaryCardView: View {
    let metrics: [ProductDetailViewModel.NutritionMetric]
    let worthNoticing: [ProductDetailViewModel.NutritionInsight]
    let goodPoints: [ProductDetailViewModel.NutritionInsight]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeadingView(
                title: "Nutrition",
                subtitle: nil,
                trailingText: "per 100 g"
            )

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
                ForEach(metrics) { metric in
                    NutritionMetricTile(metric: metric)
                }
            }

            if !worthNoticing.isEmpty {
                WorthNoticingView(insights: worthNoticing)
            }

            if !goodPoints.isEmpty {
                GoodPointsView(insights: goodPoints)
            }
        }
        .padding(18)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct NutritionMetricTile: View {
    let metric: ProductDetailViewModel.NutritionMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: metric.systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(IngredientVisualStyle.accent(for: metric.severity))
                Text(metric.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(metric.valueText)
                .font(.headline.weight(.bold))
                .foregroundStyle(metricValueColor)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(metricBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var metricValueColor: Color {
        switch metric.severity {
        case .safe:
            .primary
        case .caution:
            IngredientVisualStyle.accent(for: .caution)
        case .unknown:
            .primary
        }
    }

    private var metricBackground: Color {
        switch metric.severity {
        case .safe:
            Color.green.opacity(0.10)
        case .caution:
            Color.orange.opacity(0.12)
        case .unknown:
            Color(uiColor: .secondarySystemBackground)
        }
    }
}

struct WorthNoticingView: View {
    let insights: [ProductDetailViewModel.NutritionInsight]

    var body: some View {
        InsightListSectionView(
            title: "Worth noticing",
            insights: insights
        )
    }
}

struct GoodPointsView: View {
    let insights: [ProductDetailViewModel.NutritionInsight]

    var body: some View {
        InsightListSectionView(
            title: "Good points",
            insights: insights
        )
    }
}

struct InsightListSectionView: View {
    let title: String
    let insights: [ProductDetailViewModel.NutritionInsight]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(Array(insights.enumerated()), id: \.element.id) { index, insight in
                    NutritionInsightRow(
                        title: insight.title,
                        subtitle: insight.subtitle,
                        valueText: insight.valueText,
                        systemImage: insight.systemImage,
                        severity: insight.severity
                    )

                    if index < insights.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }
}

struct NutritionInsightRow: View {
    let title: String
    let subtitle: String
    let valueText: String
    let systemImage: String
    let severity: FlagSeverity

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            HStack(spacing: 10) {
                Text(valueText)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Circle()
                    .fill(IngredientVisualStyle.accent(for: severity))
                    .frame(width: 14, height: 14)
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 14)
    }
}

struct NutritionMiniCard: View {
    let title: String
    let valueText: String
    let severity: FlagSeverity

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(valueText)
                .font(.headline.weight(.bold))
                .foregroundStyle(IngredientVisualStyle.accent(for: severity))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(uiColor: .systemBackground),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }
}
