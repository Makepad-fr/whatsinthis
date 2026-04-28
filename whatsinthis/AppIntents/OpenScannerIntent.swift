//
//  OpenScannerIntent.swift
//  whatsinthis
//
//  Created by Codex on 28/04/2026.
//

import AppIntents

struct OpenScannerIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Scanner"
    static var description = IntentDescription("Open What’s In This? directly to the scanner.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        .result()
    }
}
