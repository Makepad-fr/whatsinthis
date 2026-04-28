//
//  Components.swift
//  whatsinthis
//
//  Created by Codex on 28/04/2026.
//

import SwiftUI
import UIKit

enum IngredientVisualStyle {
    static func accent(for severity: FlagSeverity) -> Color {
        switch severity {
        case .safe:
            Color.green
        case .caution:
            Color.orange
        case .unknown:
            Color.gray
        }
    }

    static func background(for severity: FlagSeverity) -> Color {
        switch severity {
        case .safe:
            Color.green.opacity(0.12)
        case .caution:
            Color.orange.opacity(0.16)
        case .unknown:
            Color.gray.opacity(0.14)
        }
    }

    static func iconName(for flag: AnalysisFlag?) -> String {
        switch flag?.kind {
        case .allergen:
            "exclamationmark.triangle.fill"
        case .additive:
            "sparkles.rectangle.stack.fill"
        case .processing:
            "list.bullet.rectangle.portrait.fill"
        case .fragrance:
            "sparkles"
        case .preservative:
            "shield.lefthalf.filled"
        case .surfactant:
            "drop.fill"
        case .irritant:
            "hand.raised.fill"
        case .unknown:
            "questionmark.circle.fill"
        case nil:
            "checkmark.circle.fill"
        }
    }
}

struct SourceBadge: View {
    let source: ScanSource

    var body: some View {
        Label(source.displayName, systemImage: iconName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.thinMaterial, in: Capsule())
    }

    private var iconName: String {
        switch source {
        case .openFoodFacts:
            "barcode.viewfinder"
        case .openBeautyFacts:
            "sparkles"
        case .usda:
            "leaf"
        case .ocr:
            "text.viewfinder"
        case .cache:
            "clock.arrow.circlepath"
        }
    }
}

struct HighlightCardView: View {
    let card: HighlightCard

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: card.systemImage)
                    .font(.headline)
                    .foregroundStyle(iconColor)
                    .frame(width: 36, height: 36)
                    .background(iconColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(card.title)
                    .font(.headline)
            }
            Text(card.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var backgroundColor: Color {
        switch card.tint {
        case .positive:
            Color.green.opacity(0.14)
        case .caution:
            Color.orange.opacity(0.18)
        case .neutral:
            Color.primary.opacity(0.08)
        }
    }

    private var iconColor: Color {
        switch card.tint {
        case .positive:
            .green
        case .caution:
            .orange
        case .neutral:
            .primary
        }
    }
}

struct StatusPill: View {
    let text: String
    let severity: FlagSeverity

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(IngredientVisualStyle.accent(for: severity))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(IngredientVisualStyle.background(for: severity), in: Capsule())
    }
}

struct VerdictBadgeView: View {
    let title: String
    let subtitle: String
    let severity: FlagSeverity

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(IngredientVisualStyle.accent(for: severity))
                .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.bold))
                Text(subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct CompactStatPill: View {
    let title: String
    let value: String
    let severity: FlagSeverity

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(valueColor)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var valueColor: Color {
        switch severity {
        case .safe:
            .primary
        case .caution:
            IngredientVisualStyle.accent(for: .caution)
        case .unknown:
            IngredientVisualStyle.accent(for: .unknown)
        }
    }

    private var backgroundColor: Color {
        switch severity {
        case .safe:
            Color.primary.opacity(0.06)
        case .caution:
            IngredientVisualStyle.background(for: .caution)
        case .unknown:
            IngredientVisualStyle.background(for: .unknown)
        }
    }
}

struct SectionHeadingView: View {
    let title: String
    let subtitle: String?
    let trailingText: String?

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.bold))
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let trailingText, !trailingText.isEmpty {
                Text(trailingText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ProductHeaderView: View {
    let imageData: Data?
    let name: String
    let metadata: String
    let statusTitle: String
    let statusSubtitle: String
    let severity: FlagSeverity

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ProductImageCard(
                imageData: imageData,
                width: 92,
                height: 110,
                cornerRadius: 22
            )

            VStack(alignment: .leading, spacing: 10) {
                Text(name)
                    .font(.system(size: 26, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)

                if !metadata.isEmpty {
                    Text(metadata)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HeaderStatusView(
                    title: statusTitle,
                    subtitle: statusSubtitle,
                    severity: severity
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct HeaderStatusView: View {
    let title: String
    let subtitle: String
    let severity: FlagSeverity

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: leadingSymbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(IngredientVisualStyle.accent(for: severity))
                .frame(width: 28, height: 28)
                .background(IngredientVisualStyle.background(for: severity), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var leadingSymbol: String {
        switch severity {
        case .safe:
            "checkmark.circle.fill"
        case .caution:
            "exclamationmark.circle.fill"
        case .unknown:
            "info.circle.fill"
        }
    }
}

struct AtAGlanceCardView: View {
    let items: [ProductDetailViewModel.Takeaway]
    let chips: [ProductDetailViewModel.SummaryChip]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("At a glance")
                .font(.title3.weight(.bold))

            VStack(alignment: .leading, spacing: 10) {
                ForEach(items) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: item.systemImage)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(IngredientVisualStyle.accent(for: item.severity))
                            .frame(width: 20, height: 20)

                        Text(item.text)
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if !chips.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                    ForEach(chips) { chip in
                        SummaryChipView(chip: chip)
                    }
                }
            }
        }
        .padding(18)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct SummaryChipView: View {
    let chip: ProductDetailViewModel.SummaryChip

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: chip.systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(IngredientVisualStyle.accent(for: chip.severity))
            Text(chip.text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(IngredientVisualStyle.background(for: chip.severity), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct NutritionSummaryView: View {
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

struct SwapIdeasView: View {
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

struct IngredientsSectionView: View {
    let rows: [ProductDetailViewModel.IngredientRow]
    let countLabel: String
    let onTap: (IngredientToken) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeadingView(
                title: "Ingredients",
                subtitle: nil,
                trailingText: countLabel
            )

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    IngredientCompactCardView(row: row) {
                        onTap(row.token)
                    }

                    if index < rows.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 18)
            .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }
}

struct IngredientCompactCardView: View {
    let row: ProductDetailViewModel.IngredientRow
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    leadingMarker

                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.token.text)
                            .font(.headline)
                            .multilineTextAlignment(.leading)

                        if let notice = row.notice {
                            Label(notice, systemImage: IngredientVisualStyle.iconName(for: row.token.primaryFlag))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(IngredientVisualStyle.accent(for: row.severity))
                                .multilineTextAlignment(.leading)
                        }
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }

                LabeledValueBlock(label: "What it is", value: row.whatItIs)

                if let whyItMatters = row.whyItMatters {
                    LabeledValueBlock(label: "Why it matters", value: whyItMatters)
                }

                if let usedFor = row.usedFor {
                    LabeledValueBlock(label: "Used for", value: usedFor)
                }
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var leadingMarker: some View {
        ZStack {
            Circle()
                .fill(IngredientVisualStyle.background(for: row.severity))
            Text("\(row.position)")
                .font(.caption.weight(.bold))
                .foregroundStyle(IngredientVisualStyle.accent(for: row.severity))
        }
        .frame(width: 28, height: 28)
    }
}

struct QuickIngredientRow: View {
    let token: IngredientToken
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(IngredientVisualStyle.accent(for: token.severity))
                    .frame(width: 10, height: 10)
                    .padding(.top, 6)

                VStack(alignment: .leading, spacing: 4) {
                    Text(token.text)
                        .font(.headline)
                        .multilineTextAlignment(.leading)
                    Text(token.quickLookSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)
                StatusPill(text: token.statusBadge, severity: token.severity)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct LabeledValueBlock: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct IngredientInsightRow: View {
    let token: IngredientToken
    let position: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    leadingMarker

                    VStack(alignment: .leading, spacing: 4) {
                        Text(token.text)
                            .font(.title3.weight(.semibold))
                            .multilineTextAlignment(.leading)

                        Text(token.statusTitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 10) {
                        StatusPill(text: token.statusBadge, severity: token.severity)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }

                LabeledValueBlock(label: "What it is", value: token.shortSummary)

                LabeledValueBlock(label: "Role here", value: token.supportingSummary)

                if let primaryFlag {
                    LabeledValueBlock(label: "Why it stands out", value: primaryFlag.reason)
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var leadingMarker: some View {
        Group {
            if let position {
                ZStack {
                    Circle()
                        .fill(IngredientVisualStyle.background(for: token.severity))
                    Text("\(position)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(IngredientVisualStyle.accent(for: token.severity))
                }
                .frame(width: 28, height: 28)
            } else {
                Image(systemName: IngredientVisualStyle.iconName(for: token.primaryFlag))
                    .font(.title3)
                    .foregroundStyle(iconColor)
                    .frame(width: 28, height: 28)
            }
        }
    }

    private var primaryFlag: AnalysisFlag? {
        token.primaryFlag
    }

    private var iconColor: Color {
        switch token.severity {
        case .safe:
            .secondary
        case .caution:
            IngredientVisualStyle.accent(for: .caution)
        case .unknown:
            IngredientVisualStyle.accent(for: .unknown)
        }
    }
}

struct SourceFactRow: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.vertical, 14)
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

struct IngredientChip: View {
    let token: IngredientToken
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: IngredientVisualStyle.iconName(for: token.primaryFlag))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(IngredientVisualStyle.accent(for: token.severity))
                        .frame(width: 34, height: 34)
                        .background(IngredientVisualStyle.background(for: token.severity), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top, spacing: 8) {
                            Text(token.text)
                                .font(.subheadline.weight(.semibold))
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            StatusPill(text: token.statusBadge, severity: token.severity)
                        }

                        Text(token.shortSummary)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)

                        Text(token.supportingSummary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }

                if let flag = token.primaryFlag {
                    Label(flag.kind.displayName, systemImage: IngredientVisualStyle.iconName(for: flag))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(IngredientVisualStyle.accent(for: token.severity))
                }
            }
            .foregroundStyle(.primary)
            .padding(16)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var backgroundColor: Color {
        IngredientVisualStyle.background(for: token.severity)
    }
}

struct ProductImageCard: View {
    let imageData: Data?
    var width: CGFloat = 112
    var height: CGFloat = 132
    var cornerRadius: CGFloat = 28

    var body: some View {
        Group {
            if
                let imageData,
                let uiImage = UIImage(data: imageData)
            {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [Color(red: 0.16, green: 0.26, blue: 0.20), Color(red: 0.30, green: 0.22, blue: 0.17)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
