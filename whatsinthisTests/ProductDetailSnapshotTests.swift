//
//  ProductDetailSnapshotTests.swift
//  whatsinthisTests
//
//  Created by Codex on 01/05/2026.
//

import SwiftUI
import Testing
#if canImport(UIKit)
import UIKit
#endif
@testable import whatsinthis

@MainActor
struct ProductDetailSnapshotTests {
    @Test
    func jamMarketModeSnapshotAndRender() throws {
        let analyzer = ProductDetailFixtures.makeAnalyzer()
        let viewModel = try makeViewModel(
            analyzedProduct: ProductDetailFixtures.analyzedJam(analyzer: analyzer),
            analyzer: analyzer
        )

        let snapshotName = "jam-market-mode"
        assertSnapshot(
            of: viewModel,
            contains: [
                "status: High sugar, typical for jam. — Compare sugar and fruit content if choosing between jars.",
                "glance: 59g sugar / 100g | Contains fruit pectin | Simple ingredient list | No salt/fat concern",
                "compare: Sugar | Fruit % | Additives",
                "ingredients: 1. Figues violettes — fruit base | 2. sucre — sweetener | 3. sucre roux de canne — sweetener | 4. jus de citron concentré — acidity | 5. gélifiant : pectine de fruits — gelling agent"
            ]
        )

        let pngData = try renderSnapshotData(for: viewModel)
        try recordRenderedBaselineIfRequested(named: snapshotName, pngData: pngData)
        #expect(pngData.count > 5_000)
    }

    @Test
    func flourMarketModeSnapshotAndRender() throws {
        let analyzer = ProductDetailFixtures.makeAnalyzer()
        let viewModel = try makeViewModel(
            analyzedProduct: ProductDetailFixtures.analyzedFlour(analyzer: analyzer),
            analyzer: analyzer
        )

        let snapshotName = "flour-market-mode"
        assertSnapshot(
            of: viewModel,
            contains: [
                "status: Contains wheat / gluten — Common allergen. Expected for this product type.",
                "glance: Check if avoiding gluten | Good fiber | Dry staple | Simple ingredient list",
                "compare: Fiber | Wholegrain | Gluten",
                "ingredients: 1. Type 150 wholemeal wheat flour — wholegrain flour"
            ]
        )

        let pngData = try renderSnapshotData(for: viewModel)
        try recordRenderedBaselineIfRequested(named: snapshotName, pngData: pngData)
        #expect(pngData.count > 5_000)
    }

    @Test
    func yogurtMarketModeSnapshotAndRender() throws {
        let analyzer = ProductDetailFixtures.makeAnalyzer()
        let viewModel = try makeViewModel(
            analyzedProduct: ProductDetailFixtures.analyzedYogurt(analyzer: analyzer),
            analyzer: analyzer
        )

        let snapshotName = "yogurt-market-mode"
        assertSnapshot(
            of: viewModel,
            contains: [
                "status: Contains milk — Common allergen. Check if avoiding it.",
                "glance: Check sugar | Some sat. fat to notice",
                "compare: Sugar | Protein | Fat",
                "ingredients: 1. Milk"
            ]
        )

        let pngData = try renderSnapshotData(for: viewModel)
        try recordRenderedBaselineIfRequested(named: snapshotName, pngData: pngData)
        #expect(pngData.count > 5_000)
    }

    @Test
    func ocrMarketModeSnapshotAndRender() throws {
        let analyzer = ProductDetailFixtures.makeAnalyzer()
        let viewModel = try makeViewModel(
            analyzedProduct: ProductDetailFixtures.analyzedOCRFood(analyzer: analyzer),
            analyzer: analyzer
        )

        let snapshotName = "ocr-market-mode"
        assertSnapshot(
            of: viewModel,
            contains: [
                "status: Label explained — Review ingredient text if something looks wrong.",
                "glance: Label explained | Review label text if something looks wrong",
                "compare: Ingredients | Allergens | Additives"
            ]
        )

        let pngData = try renderSnapshotData(for: viewModel)
        try recordRenderedBaselineIfRequested(named: snapshotName, pngData: pngData)
        #expect(pngData.count > 5_000)
    }

    @Test
    func beautyMarketModeSnapshotAndRender() throws {
        let analyzer = ProductDetailFixtures.makeAnalyzer()
        let viewModel = try makeViewModel(
            analyzedProduct: ProductDetailFixtures.analyzedBeauty(analyzer: analyzer),
            analyzer: analyzer
        )

        let snapshotName = "beauty-market-mode"
        assertSnapshot(
            of: viewModel,
            contains: [
                "status: Check sensitive-skin markers — Fragrance ingredients are listed in the formula.",
                "glance: Fragrance ingredients found | Preservatives listed",
                "compare: Fragrance | Alcohol | Preservatives",
                "3. Parfum"
            ]
        )

        let pngData = try renderSnapshotData(for: viewModel)
        try recordRenderedBaselineIfRequested(named: snapshotName, pngData: pngData)
        #expect(pngData.count > 5_000)
    }

    private func makeViewModel(
        analyzedProduct: AnalyzedProduct,
        analyzer: IngredientAnalyzer
    ) throws -> ProductDetailViewModel {
        ProductDetailViewModel(
            analyzedProduct: analyzedProduct,
            imageRepository: try TestSupport.makeImageRepository(),
            ingredientAnalyzer: analyzer
        )
    }

    private func snapshotText(for viewModel: ProductDetailViewModel) -> String {
        let ingredientPreview = viewModel.ingredientRows
            .prefix(5)
            .map { "\($0.position). \($0.token.text) — \($0.compactRole)" }
            .joined(separator: " | ")

        return """
        status: \(viewModel.headerStatus.title) — \(viewModel.headerStatus.subtitle)
        glance: \(viewModel.atAGlanceItems.map(\.text).joined(separator: " | "))
        compare: \(viewModel.comparisonCriteria.map(\.text).joined(separator: " | "))
        ingredients: \(ingredientPreview)
        """
    }

    private func assertSnapshot(
        of viewModel: ProductDetailViewModel,
        contains expectedLines: [String]
    ) {
        let snapshot = snapshotText(for: viewModel)
        for line in expectedLines {
            #expect(snapshot.contains(line))
        }
    }

    private func renderSnapshotData(for viewModel: ProductDetailViewModel) throws -> Data {
        let content = ProductDetailView(viewModel: viewModel)
            .frame(width: 390)
            .background(Color(uiColor: .systemGroupedBackground))

        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(width: 390, height: nil)
        renderer.scale = 2

        guard let image = renderer.uiImage, let data = image.pngData() else {
            throw SnapshotRenderError.renderFailed
        }

        return data
    }

    private func recordRenderedBaselineIfRequested(named name: String, pngData: Data) throws {
        guard Self.shouldRecordRenderedBaselines else { return }

        let directoryURL = try Self.renderedBaselineDirectoryURL()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try pngData.write(to: directoryURL.appendingPathComponent("\(name).png"), options: .atomic)
    }
}

private extension ProductDetailSnapshotTests {
    static var shouldRecordRenderedBaselines: Bool {
        ProcessInfo.processInfo.environment["RECORD_RENDER_SNAPSHOTS"] == "1"
    }

    static func renderedBaselineDirectoryURL() throws -> URL {
        let fileURL = URL(fileURLWithPath: #filePath)
        return fileURL
            .deletingLastPathComponent()
            .appendingPathComponent("__RenderedBaselines__", isDirectory: true)
    }
}

private enum SnapshotRenderError: Error {
    case renderFailed
}
