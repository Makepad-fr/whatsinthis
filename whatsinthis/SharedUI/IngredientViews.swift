//
//  IngredientViews.swift
//  whatsinthis
//
//  Created by Codex on 01/05/2026.
//

import SwiftUI

struct CompactIngredientsCardView: View {
    let rows: [ProductDetailViewModel.IngredientRow]
    let countLabel: String
    let onTap: (IngredientToken) -> Void
    let onOpenLearnMode: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeadingView(
                title: "Ingredients",
                subtitle: nil,
                trailingText: countLabel
            )

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    CompactIngredientRow(row: row) {
                        onTap(row.token)
                    }

                    if index < rows.count - 1 {
                        Divider()
                    }
                }

                Button(action: onOpenLearnMode) {
                    HStack(spacing: 8) {
                        Text("See full explanation")
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(.primary)
                    .padding(.top, 14)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }
}

struct CompactIngredientRow: View {
    let row: ProductDetailViewModel.IngredientRow
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(IngredientVisualStyle.background(for: row.severity))
                    Text("\(row.position)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(IngredientVisualStyle.accent(for: row.severity))
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(row.token.text)
                            .font(.headline)
                            .multilineTextAlignment(.leading)
                        Text("— \(row.compactRole)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }

                    if let notice = row.notice, row.severity != .safe {
                        Text(notice)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(IngredientVisualStyle.accent(for: row.severity))
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
