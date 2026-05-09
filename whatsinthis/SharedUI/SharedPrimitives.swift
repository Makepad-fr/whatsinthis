//
//  SharedPrimitives.swift
//  whatsinthis
//
//  Created by Codex on 01/05/2026.
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
