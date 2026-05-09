//
//  DataStore.swift
//  whatsinthis
//
//  Created by Codex on 28/04/2026.
//

import Foundation
import SwiftData

enum CachedProductState {
    case fresh(AnalyzedProduct)
    case stale(AnalyzedProduct)
}

@MainActor
final class DataStore {
    static let cacheTTL: TimeInterval = 60 * 60 * 24 * 30

    let modelContainer: ModelContainer
    private let context: ModelContext

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.context = modelContainer.mainContext
    }

    static func makeContainer() -> ModelContainer {
        let schema = Schema([
            CachedProductRecord.self,
            CachedImageRecord.self,
            IngredientGlossaryEntryRecord.self,
            ScanSnapshotRecord.self,
            UserPreferenceRecord.self,
        ])

        do {
            return try ModelContainer(for: schema)
        } catch {
            fatalError("Unable to create model container: \(error.localizedDescription)")
        }
    }

    func bootstrapGlossaryIfNeeded() throws {
        guard
            let url = Bundle.main.url(forResource: "IngredientGlossary", withExtension: "json")
                ?? Bundle.main.url(forResource: "IngredientGlossary", withExtension: "json", subdirectory: "Resources")
        else {
            return
        }

        let data = try Data(contentsOf: url)
        let items = try JSONDecoder().decode([IngredientGlossaryItem].self, from: data)
        let fetch = FetchDescriptor<IngredientGlossaryEntryRecord>()
        let existingRecords = try context.fetch(fetch)
        let recordsByID = Dictionary(uniqueKeysWithValues: existingRecords.map { ($0.id, $0) })
        let didChange = Self.upsertGlossaryItems(items, recordsByID: recordsByID, context: context)

        if didChange {
            try context.save()
        }
    }

    func glossaryItems() throws -> [IngredientGlossaryItem] {
        let fetch = FetchDescriptor<IngredientGlossaryEntryRecord>(sortBy: [SortDescriptor(\.name)])
        return try context.fetch(fetch).map { record in
            IngredientGlossaryItem(
                id: record.id,
                name: record.name,
                aliases: record.aliasesBlob.split(separator: "\n").map(String.init),
                category: ProductCategory(rawValue: record.categoryRawValue) ?? .unknown,
                summary: record.summary,
                function: record.functionText,
                caution: record.caution,
                markers: record.markersBlob.split(separator: "\n").compactMap { AnalysisMarker(rawValue: String($0)) }
            )
        }
    }

    func replaceGlossaryItems(_ items: [IngredientGlossaryItem]) throws {
        try Self.replaceGlossaryItems(items, context: context)
    }

    func replaceGlossaryItemsInBackground(_ items: [IngredientGlossaryItem]) async throws {
        let payload = try JSONEncoder().encode(items)
        let container = modelContainer

        try await Task.detached(priority: .utility) {
            let items = try JSONDecoder().decode([IngredientGlossaryItem].self, from: payload)
            let context = ModelContext(container)
            try Self.replaceGlossaryItems(items, context: context)
        }.value
    }

    nonisolated private static func replaceGlossaryItems(_ items: [IngredientGlossaryItem], context: ModelContext) throws {
        let fetch = FetchDescriptor<IngredientGlossaryEntryRecord>()
        let existingRecords = try context.fetch(fetch)
        let recordsByID = Dictionary(uniqueKeysWithValues: existingRecords.map { ($0.id, $0) })
        let incomingIDs = Set(items.map(\.id))
        var didChange = false

        for record in existingRecords where !incomingIDs.contains(record.id) {
            context.delete(record)
            didChange = true
        }

        didChange = upsertGlossaryItems(items, recordsByID: recordsByID, context: context) || didChange

        if didChange {
            try context.save()
        }
    }

    nonisolated private static func upsertGlossaryItems(
        _ items: [IngredientGlossaryItem],
        recordsByID: [String: IngredientGlossaryEntryRecord],
        context: ModelContext
    ) -> Bool {
        var didChange = false

        for item in items {
            didChange = upsertGlossaryItem(item, existing: recordsByID[item.id], context: context) || didChange
        }

        return didChange
    }

    nonisolated private static func upsertGlossaryItem(
        _ item: IngredientGlossaryItem,
        existing: IngredientGlossaryEntryRecord?,
        context: ModelContext
    ) -> Bool {
        let aliasesBlob = item.aliases.joined(separator: "\n")
        let markersBlob = item.markers.map(\.rawValue).joined(separator: "\n")

        if let existing {
            guard existing.name != item.name
                || existing.aliasesBlob != aliasesBlob
                || existing.categoryRawValue != item.category.rawValue
                || existing.summary != item.summary
                || existing.functionText != item.function
                || existing.caution != item.caution
                || existing.markersBlob != markersBlob
            else {
                return false
            }

            existing.name = item.name
            existing.aliasesBlob = aliasesBlob
            existing.categoryRawValue = item.category.rawValue
            existing.summary = item.summary
            existing.functionText = item.function
            existing.caution = item.caution
            existing.markersBlob = markersBlob
            return true
        }

        context.insert(
            IngredientGlossaryEntryRecord(
                id: item.id,
                name: item.name,
                aliasesBlob: aliasesBlob,
                categoryRawValue: item.category.rawValue,
                summary: item.summary,
                functionText: item.function,
                caution: item.caution,
                markersBlob: markersBlob
            )
        )
        return true
    }

    func cachedProduct(for barcode: String) throws -> CachedProductState? {
        try cachedProduct(forKey: barcode)
    }

    func cachedProduct(forKey key: String) throws -> CachedProductState? {
        let fetch = FetchDescriptor<CachedProductRecord>(
            predicate: #Predicate<CachedProductRecord> { record in
                record.key == key
            }
        )

        guard let record = try context.fetch(fetch).first else {
            return nil
        }

        let analyzedProduct = try JSONDecoder().decode(AnalyzedProduct.self, from: record.payload)
        if record.expiresAt > .now {
            return .fresh(analyzedProduct)
        } else {
            return .stale(analyzedProduct)
        }
    }

    func save(analyzedProduct: AnalyzedProduct) throws {
        let key = analyzedProduct.product.barcode ?? analyzedProduct.id
        let fetch = FetchDescriptor<CachedProductRecord>(
            predicate: #Predicate<CachedProductRecord> { record in
                record.key == key
            }
        )

        let payload = try JSONEncoder().encode(analyzedProduct)
        let updatedAt = Date.now
        let expiresAt = updatedAt.addingTimeInterval(Self.cacheTTL)

        if let existing = try context.fetch(fetch).first {
            existing.payload = payload
            existing.updatedAt = updatedAt
            existing.expiresAt = expiresAt
            existing.sourceRawValue = analyzedProduct.product.source.rawValue
        } else {
            context.insert(
                CachedProductRecord(
                    key: key,
                    payload: payload,
                    updatedAt: updatedAt,
                    expiresAt: expiresAt,
                    sourceRawValue: analyzedProduct.product.source.rawValue
                )
            )
        }

        try saveSnapshot(from: analyzedProduct)
        try context.save()
    }

    func latestSnapshot() throws -> RecentScanSummary? {
        let fetch = FetchDescriptor<ScanSnapshotRecord>(
            sortBy: [SortDescriptor(\.scannedAt, order: .reverse)]
        )

        guard let record = try context.fetch(fetch).first else {
            return nil
        }

        return RecentScanSummary(
            id: record.id,
            name: record.name,
            summary: record.summary,
            barcode: record.barcode,
            scannedAt: record.scannedAt,
            source: ScanSource(rawValue: record.sourceRawValue) ?? .cache
        )
    }

    func recentCachedProducts(limit: Int) throws -> [AnalyzedProduct] {
        guard limit > 0 else { return [] }

        let fetch = FetchDescriptor<CachedProductRecord>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )

        return try context.fetch(fetch)
            .prefix(limit)
            .compactMap { record in
                try? JSONDecoder().decode(AnalyzedProduct.self, from: record.payload)
            }
    }

    func registerCachedImage(key: String, relativePath: String) throws {
        let fetch = FetchDescriptor<CachedImageRecord>(
            predicate: #Predicate<CachedImageRecord> { record in
                record.key == key
            }
        )

        if let existing = try context.fetch(fetch).first {
            existing.relativePath = relativePath
            existing.updatedAt = .now
        } else {
            context.insert(CachedImageRecord(key: key, relativePath: relativePath, updatedAt: .now))
        }

        try context.save()
    }

    func cachedImageRelativePath(for key: String) throws -> String? {
        let fetch = FetchDescriptor<CachedImageRecord>(
            predicate: #Predicate<CachedImageRecord> { record in
                record.key == key
            }
        )

        return try context.fetch(fetch).first?.relativePath
    }

    func isPremiumUnlocked() throws -> Bool {
        let fetch = FetchDescriptor<UserPreferenceRecord>()
        return try context.fetch(fetch).first?.premiumUnlocked ?? false
    }

    private func saveSnapshot(from analyzedProduct: AnalyzedProduct) throws {
        let key = analyzedProduct.product.barcode ?? analyzedProduct.id
        let fetch = FetchDescriptor<ScanSnapshotRecord>(
            predicate: #Predicate<ScanSnapshotRecord> { record in
                record.id == key
            }
        )

        let summary = analyzedProduct.summary.headline
        let product = analyzedProduct.product

        if let existing = try context.fetch(fetch).first {
            existing.name = product.name
            existing.summary = summary
            existing.barcode = product.barcode
            existing.scannedAt = .now
            existing.sourceRawValue = product.source.rawValue
        } else {
            context.insert(
                ScanSnapshotRecord(
                    id: key,
                    name: product.name,
                    summary: summary,
                    barcode: product.barcode,
                    scannedAt: .now,
                    sourceRawValue: product.source.rawValue
                )
            )
        }
    }
}
