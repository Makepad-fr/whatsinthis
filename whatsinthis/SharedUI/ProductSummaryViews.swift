//
//  ProductSummaryViews.swift
//  whatsinthis
//
//  Created by Codex on 01/05/2026.
//

import SwiftUI

struct ProductHeroCard: View {
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
                width: 78,
                height: 94,
                cornerRadius: 20
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(name)
                    .font(.system(size: 27, weight: .bold))
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)

                if !metadata.isEmpty {
                    Text(metadata)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                CompactHeaderStatusView(
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

struct CompactHeaderStatusView: View {
    let title: String
    let subtitle: String
    let severity: FlagSeverity

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: leadingSymbol)
                .font(.footnote.weight(.bold))
                .foregroundStyle(IngredientVisualStyle.accent(for: severity))
                .frame(width: 26, height: 26)
                .background(IngredientVisualStyle.background(for: severity), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.semibold))
                Text(subtitle)
                    .font(.footnote)
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
        VStack(alignment: .leading, spacing: 12) {
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

struct WhatToCompareCardView: View {
    let criteria: [ProductDetailViewModel.ComparisonCriterion]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What to compare")
                .font(.headline.weight(.semibold))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 8)], spacing: 8) {
                ForEach(criteria) { item in
                    HStack(spacing: 8) {
                        Image(systemName: item.systemImage)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.orange)
                        Text(item.text)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
