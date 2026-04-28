//
//  PersistenceModels.swift
//  whatsinthis
//
//  Created by Codex on 28/04/2026.
//

import Foundation
import SwiftData

@Model
final class CachedProductRecord {
    @Attribute(.unique) var key: String
    @Attribute(.externalStorage) var payload: Data
    var updatedAt: Date
    var expiresAt: Date
    var sourceRawValue: String

    init(key: String, payload: Data, updatedAt: Date, expiresAt: Date, sourceRawValue: String) {
        self.key = key
        self.payload = payload
        self.updatedAt = updatedAt
        self.expiresAt = expiresAt
        self.sourceRawValue = sourceRawValue
    }
}

@Model
final class CachedImageRecord {
    @Attribute(.unique) var key: String
    var relativePath: String
    var updatedAt: Date

    init(key: String, relativePath: String, updatedAt: Date) {
        self.key = key
        self.relativePath = relativePath
        self.updatedAt = updatedAt
    }
}

@Model
final class IngredientGlossaryEntryRecord {
    @Attribute(.unique) var id: String
    var name: String
    var aliasesBlob: String
    var categoryRawValue: String
    var summary: String
    var functionText: String
    var caution: Bool
    var markersBlob: String

    init(
        id: String,
        name: String,
        aliasesBlob: String,
        categoryRawValue: String,
        summary: String,
        functionText: String,
        caution: Bool,
        markersBlob: String
    ) {
        self.id = id
        self.name = name
        self.aliasesBlob = aliasesBlob
        self.categoryRawValue = categoryRawValue
        self.summary = summary
        self.functionText = functionText
        self.caution = caution
        self.markersBlob = markersBlob
    }
}

@Model
final class ScanSnapshotRecord {
    @Attribute(.unique) var id: String
    var name: String
    var summary: String
    var barcode: String?
    var scannedAt: Date
    var sourceRawValue: String

    init(id: String, name: String, summary: String, barcode: String?, scannedAt: Date, sourceRawValue: String) {
        self.id = id
        self.name = name
        self.summary = summary
        self.barcode = barcode
        self.scannedAt = scannedAt
        self.sourceRawValue = sourceRawValue
    }
}

@Model
final class UserPreferenceRecord {
    @Attribute(.unique) var id: String
    var allergenBlob: String
    var preferenceBlob: String
    var premiumUnlocked: Bool

    init(id: String = "primary", allergenBlob: String, preferenceBlob: String, premiumUnlocked: Bool) {
        self.id = id
        self.allergenBlob = allergenBlob
        self.preferenceBlob = preferenceBlob
        self.premiumUnlocked = premiumUnlocked
    }
}
