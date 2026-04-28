//
//  ScanPayload.swift
//  whatsinthis
//
//  Created by Codex on 28/04/2026.
//

import Foundation

enum ScanSymbology {
    case linearCode
    case qrCode
}

enum ScanPayload: Equatable {
    case productCode(String)
    case unsupportedQRCode(String)

    var deduplicationKey: String {
        switch self {
        case .productCode(let code):
            "product:\(code)"
        case .unsupportedQRCode(let rawValue):
            "unsupported-qr:\(rawValue)"
        }
    }
}

enum ScanPayloadParser {
    static func parse(rawValue: String, symbology: ScanSymbology) -> ScanPayload? {
        switch symbology {
        case .linearCode:
            guard let productCode = normalizedProductCode(from: rawValue) else {
                return nil
            }
            return .productCode(productCode)
        case .qrCode:
            if let productCode = productCodeFromQRCode(rawValue) {
                return .productCode(productCode)
            }
            return .unsupportedQRCode(rawValue)
        }
    }

    static func normalizedProductCode(from rawValue: String) -> String? {
        let digits = rawValue.filter(\.isNumber)
        guard supportedProductCodeLengths.contains(digits.count) else {
            return nil
        }
        return digits
    }

    private static func productCodeFromQRCode(_ rawValue: String) -> String? {
        if let directCode = exactProductCode(from: rawValue) {
            return directCode
        }

        if let digitalLinkCode = extractUsingPattern(#"/01/(\d{14})(?:[/?#]|$)"#, from: rawValue) {
            return digitalLinkCode
        }

        if let applicationIdentifierCode = extractUsingPattern(#"(?:^|[^0-9])01(\d{14})(?:[^0-9]|$)"#, from: rawValue) {
            return applicationIdentifierCode
        }

        if let queryCode = extractCodeFromQueryItems(in: rawValue) {
            return queryCode
        }

        return nil
    }

    private static func exactProductCode(from rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.allSatisfy(\.isNumber), supportedProductCodeLengths.contains(trimmed.count) else {
            return nil
        }
        return trimmed
    }

    private static func extractCodeFromQueryItems(in rawValue: String) -> String? {
        guard
            let components = URLComponents(string: rawValue),
            let queryItems = components.queryItems
        else {
            return nil
        }

        let supportedKeys = ["gtin", "ean", "upc", "barcode", "code"]

        for item in queryItems {
            guard supportedKeys.contains(item.name.lowercased()) else { continue }
            if let value = item.value, let code = normalizedProductCode(from: value) {
                return code
            }
        }

        return nil
    }

    private static func extractUsingPattern(_ pattern: String, from rawValue: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(rawValue.startIndex..., in: rawValue)
        guard
            let match = regex.firstMatch(in: rawValue, options: [], range: range),
            match.numberOfRanges > 1,
            let capturedRange = Range(match.range(at: 1), in: rawValue)
        else {
            return nil
        }

        return String(rawValue[capturedRange])
    }

    private static let supportedProductCodeLengths: Set<Int> = [8, 12, 13, 14]
}
