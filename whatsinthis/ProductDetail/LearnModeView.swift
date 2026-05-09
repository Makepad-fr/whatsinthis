//
//  LearnModeView.swift
//  whatsinthis
//
//  Created by Codex on 02/05/2026.
//

import SwiftUI

struct LearnModeView: View {
    let productName: String
    let metadata: String
    let rows: [ProductDetailViewModel.IngredientRow]
    let countLabel: String

    @State private var selectedIngredient: IngredientToken?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    learnModeHeader

                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                            IngredientCompactCardView(row: row) {
                                selectedIngredient = row.token
                            }

                            if index < rows.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(
                        Color(uiColor: .systemBackground),
                        in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Full explanation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $selectedIngredient) { token in
            IngredientDetailView(token: token)
                .presentationDetents([.medium, .large])
        }
    }

    private var learnModeHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(productName)
                .font(.system(size: 26, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)

            if !metadata.isEmpty {
                Text(metadata)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Image(systemName: "book.pages.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)

                Text("\(countLabel) explained in more detail.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(uiColor: .systemBackground),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }
}
