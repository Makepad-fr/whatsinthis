//
//  IngredientDetailView.swift
//  whatsinthis
//
//  Created by Codex on 28/04/2026.
//

import SwiftUI

struct IngredientDetailView: View {
    let token: IngredientToken

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    statusCard

                    if let explanation = token.explanation {
                        detailCard(
                            title: "What This Ingredient Is",
                            text: explanation.summary
                        )

                        detailCard(
                            title: "What It Usually Does Here",
                            text: explanation.function
                        )

                        detailCard(
                            title: "Why The App Surfaced It",
                            text: explanation.whyHighlighted
                        )
                    }

                    if !token.flags.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Markers")
                                .font(.headline)
                            ForEach(token.flags) { flag in
                                Label(flag.kind.displayName, systemImage: iconName(for: flag))
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(backgroundColor(for: flag), in: Capsule())
                            }
                        }
                    }

                    detailCard(
                        title: "How Reliable This Match Looks",
                        text: token.confidenceSummary
                    )

                    if let provenance = token.explanation?.provenance {
                        detailCard(
                            title: "Source Of Explanation",
                            text: provenance.displayName
                        )
                    }

                    Text("Informational only, not medical advice.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
            }
            .navigationTitle("Ingredient")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(token.text)
                        .font(.title2.weight(.bold))
                    Text(token.statusTitle)
                        .font(.headline)
                }
                Spacer()
                StatusPill(text: token.statusBadge, severity: token.severity)
            }

            Text(token.shortSummary)
                .font(.body)

            if let flag = token.primaryFlag {
                Label(flag.kind.displayName, systemImage: iconName(for: flag))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(IngredientVisualStyle.accent(for: token.severity))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            IngredientVisualStyle.background(for: token.severity),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }

    private func detailCard(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func iconName(for flag: AnalysisFlag) -> String {
        IngredientVisualStyle.iconName(for: flag)
    }

    private func backgroundColor(for flag: AnalysisFlag) -> Color {
        IngredientVisualStyle.background(for: flag.severity)
    }
}
