//
//  VisionProcessor.swift
//  whatsinthis
//
//  Created by Codex on 28/04/2026.
//

import UIKit
import Vision

enum VisionProcessorError: LocalizedError {
    case imageUnavailable
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .imageUnavailable:
            "The captured image could not be processed."
        case .noTextFound:
            "No readable ingredient text was detected."
        }
    }
}

final class VisionProcessor {
    func recognizeIngredients(from image: UIImage) async throws -> OCRResult {
        guard let cgImage = image.cgImage else {
            throw VisionProcessorError.imageUnavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest { request, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    let observations = request.results as? [VNRecognizedTextObservation] ?? []
                    let candidates = observations.compactMap { $0.topCandidates(1).first }
                    let lines = candidates.map(\.string)

                    guard !lines.isEmpty else {
                        continuation.resume(throwing: VisionProcessorError.noTextFound)
                        return
                    }

                    let extractedText = self.extractIngredientBlock(from: lines)
                    let confidence = candidates.map(\.confidence).reduce(0, +) / Float(max(candidates.count, 1))

                    continuation.resume(
                        returning: OCRResult(
                            text: extractedText,
                            confidence: Double(confidence),
                            lines: lines
                        )
                    )
                }

                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = false
                request.minimumTextHeight = 0.015
                request.recognitionLanguages = ["en_US", "fr_FR", "de_DE", "es_ES", "it_IT"]

                do {
                    let handler = VNImageRequestHandler(cgImage: cgImage, orientation: image.cgImageOrientation)
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func detectBarcode(in image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else {
            throw VisionProcessorError.imageUnavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNDetectBarcodesRequest { request, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    let payloads = (request.results as? [VNBarcodeObservation])?
                        .compactMap(\.payloadStringValue) ?? []
                    continuation.resume(returning: payloads)
                }

                do {
                    let handler = VNImageRequestHandler(cgImage: cgImage, orientation: image.cgImageOrientation)
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func extractIngredientBlock(from lines: [String]) -> String {
        let lowercasedLines = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let ingredientAnchors = ["ingredients", "ingredient", "inci"]
        let stopWords = ["nutrition", "directions", "storage", "warning", "keep out", "made in"]

        let startIndex = lowercasedLines.firstIndex { line in
            ingredientAnchors.contains(where: { line.lowercased().contains($0) })
        } ?? 0

        var collected: [String] = []
        for line in lowercasedLines[startIndex...] {
            let lowercase = line.lowercased()
            if !collected.isEmpty, stopWords.contains(where: lowercase.contains) {
                break
            }
            collected.append(line)
        }

        let joined = collected.joined(separator: " ")
        return normalizeIngredientsText(joined)
    }

    private func normalizeIngredientsText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "(?i)ingredients\\s*[:\\-]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "(?i)inci\\s*[:\\-]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "•", with: ", ")
            .replacingOccurrences(of: ";", with: ", ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension UIImage {
    var cgImageOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up:
            .up
        case .down:
            .down
        case .left:
            .left
        case .right:
            .right
        case .upMirrored:
            .upMirrored
        case .downMirrored:
            .downMirrored
        case .leftMirrored:
            .leftMirrored
        case .rightMirrored:
            .rightMirrored
        @unknown default:
            .up
        }
    }
}
