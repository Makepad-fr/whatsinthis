//
//  BackendConfiguration.swift
//  whatsinthis
//
//  Created by Codex on 09/05/2026.
//

import Foundation

enum BackendConfiguration {
    static func baseURL(bundle: Bundle = .main) -> URL {
        let value = (bundle.object(forInfoDictionaryKey: "WhatsInThisBackendBaseURL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let value, !value.isEmpty, let url = URL(string: value) {
            return url
        }

        return URL(string: "http://127.0.0.1:8080")!
    }
}
