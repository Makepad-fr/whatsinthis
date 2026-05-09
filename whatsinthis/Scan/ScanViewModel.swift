//
//  ScanViewModel.swift
//  whatsinthis
//
//  Created by Codex on 28/04/2026.
//

import AVFoundation
import Combine
import UIKit

@MainActor
final class ScanViewModel: ObservableObject {
    @Published var status: LookupStatus = .scanning
    @Published var activeProduct: AnalyzedProduct?
    @Published var latestSnapshot: RecentScanSummary?
    @Published var isProcessingCapture = false
    @Published var currentBarcode: String?
    @Published var premiumUnlocked = false

    let cameraController = CameraSessionController()
    let imageRepository: ProductImageRepository
    let productBackend: ProductBackend
    let ingredientAnalyzer: IngredientAnalyzer

    private let dataStore: DataStore
    private let visionProcessor: VisionProcessor

    private var hasPrepared = false
    private var lookupTask: Task<Void, Never>?
    private var glossaryRefreshTask: Task<Void, Never>?
    private var pendingProductForOCR: NormalizedProduct?

    init(
        dataStore: DataStore,
        productBackend: ProductBackend,
        ingredientAnalyzer: IngredientAnalyzer,
        visionProcessor: VisionProcessor,
        imageRepository: ProductImageRepository
    ) {
        self.dataStore = dataStore
        self.productBackend = productBackend
        self.ingredientAnalyzer = ingredientAnalyzer
        self.visionProcessor = visionProcessor
        self.imageRepository = imageRepository

        cameraController.onScanPayloadDetected = { [weak self] payload in
            Task { @MainActor in
                self?.handleScanPayload(payload)
            }
        }

        cameraController.onPhotoCaptured = { [weak self] image in
            Task { @MainActor in
                await self?.handleCapturedPhoto(image)
            }
        }

        cameraController.onError = { [weak self] message in
            Task { @MainActor in
                self?.status = .error(message)
            }
        }
    }

    func prepare() async {
        guard !hasPrepared else { return }
        hasPrepared = true

        do {
            try dataStore.bootstrapGlossaryIfNeeded()
            ingredientAnalyzer.updateGlossary(try dataStore.glossaryItems())
            latestSnapshot = try dataStore.latestSnapshot()
            premiumUnlocked = try dataStore.isPremiumUnlocked()
        } catch {
            status = .error("Local data setup failed: \(error.localizedDescription)")
        }

        cameraController.requestAccessIfNeeded()
        if cameraController.authorizationStatus == .authorized {
            status = .scanning
        }

        glossaryRefreshTask?.cancel()
        glossaryRefreshTask = Task { [weak self] in
            await self?.refreshRemoteGlossary()
        }
    }

    func toggleTorch() {
        cameraController.toggleTorch()
    }

    func beginIngredientCapture() {
        status = .needsOCR("Capture the ingredient label to continue.")
        cameraController.updateMode(.ingredients)
    }

    func returnToBarcodeMode() {
        pendingProductForOCR = nil
        isProcessingCapture = false
        cameraController.updateMode(.barcode)
        status = .scanning
    }

    func captureIngredientPhoto() {
        guard !isProcessingCapture else { return }
        isProcessingCapture = true
        status = .lookingUp("Reading ingredient label…")
        cameraController.capturePhoto()
    }

    func reopenLatestScan() {
        guard let latestSnapshot else { return }
        let key = latestSnapshot.barcode ?? latestSnapshot.id
        guard let cached = try? dataStore.cachedProduct(forKey: key) else { return }

        switch cached {
        case .fresh(let product), .stale(let product):
            let refreshed = refreshedAnalysis(from: product)
            activeProduct = refreshed
            try? dataStore.save(analyzedProduct: refreshed)
        }
    }

    func clearPresentedProduct() {
        activeProduct = nil
        status = cameraController.mode == .ingredients ? .needsOCR("Capture the ingredient label to continue.") : .scanning
    }

    private func handleScanPayload(_ payload: ScanPayload) {
        switch payload {
        case .productCode(let code):
            currentBarcode = code
            lookupTask?.cancel()
            lookupTask = Task { [weak self] in
                await self?.lookup(barcode: code)
            }
        case .unsupportedQRCode:
            currentBarcode = nil
            status = .error("This QR code looks like a generic link or unsupported format, not a product barcode the app can verify.")
        }
    }

    private func lookup(barcode: String) async {
        status = .lookingUp("Looking up \(barcode)…")

        do {
            if let cached = try dataStore.cachedProduct(for: barcode) {
                switch cached {
                case .fresh(let product):
                    let refreshed = refreshedAnalysis(from: product)
                    activeProduct = refreshed
                    try? dataStore.save(analyzedProduct: refreshed)
                    latestSnapshot = try dataStore.latestSnapshot()
                    status = .scanning
                    return
                case .stale(let product):
                    let refreshed = refreshedAnalysis(from: product)
                    activeProduct = refreshed
                    try? dataStore.save(analyzedProduct: refreshed)
                    status = .lookingUp("Refreshing cached product…")
                }
            }
        } catch {
            status = .error("Cache lookup failed: \(error.localizedDescription)")
        }

        do {
            let result = try await productBackend.lookupProduct(
                ProductLookupRequest(barcode: barcode, locale: .current)
            )
            guard let product = result.product else {
                pendingProductForOCR = nil
                status = .needsOCR(result.message ?? "No product match was found.")
                cameraController.updateMode(.ingredients)
                return
            }

            if product.ingredientText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                pendingProductForOCR = product
                status = .needsOCR(result.message ?? "Product found, but the ingredient label needs OCR.")
                cameraController.updateMode(.ingredients)
                return
            }

            let analyzed = ingredientAnalyzer.analyze(product: product)
            try dataStore.save(analyzedProduct: analyzed)
            activeProduct = analyzed
            latestSnapshot = try dataStore.latestSnapshot()
            pendingProductForOCR = nil
            cameraController.updateMode(.barcode)
            status = .scanning
        } catch {
            if activeProduct == nil {
                status = .needsOCR("The product lookup failed before a verified record was returned. Capture the ingredient label to continue.")
                cameraController.updateMode(.ingredients)
            } else {
                status = .error("Showing the cached result because live refresh failed.")
            }
        }
    }

    private func refreshRemoteGlossary() async {
        guard let remoteGlossary = try? await productBackend.glossaryItems(),
              !Task.isCancelled,
              !remoteGlossary.isEmpty
        else {
            return
        }

        do {
            try dataStore.replaceGlossaryItems(remoteGlossary)
            ingredientAnalyzer.updateGlossary(try dataStore.glossaryItems())
        } catch {
            // Keep the bundled glossary if the remote refresh cannot be persisted.
        }
    }

    private func handleCapturedPhoto(_ image: UIImage) async {
        defer { isProcessingCapture = false }

        do {
            let ocrResult = try await visionProcessor.recognizeIngredients(from: image)
            let baseProduct = pendingProductForOCR
            let inferredCategory = ingredientAnalyzer.inferCategory(from: ocrResult.text)
            let category = baseProduct?.category == .unknown ? inferredCategory : (baseProduct?.category ?? inferredCategory)

            let product = NormalizedProduct(
                id: baseProduct?.id ?? currentBarcode ?? UUID().uuidString,
                barcode: baseProduct?.barcode ?? currentBarcode,
                name: baseProduct?.name ?? "Scanned Ingredient Label",
                brand: baseProduct?.brand,
                imageURL: baseProduct?.imageURL,
                ingredientText: ocrResult.text,
                ingredientTags: baseProduct?.ingredientTags ?? [],
                categoryTags: baseProduct?.categoryTags ?? [],
                additives: baseProduct?.additives ?? [],
                allergens: baseProduct?.allergens ?? [],
                category: category,
                source: baseProduct?.source ?? .ocr,
                nutrition: baseProduct?.nutrition,
                ocrConfidence: ocrResult.confidence,
                ingredientsProvenance: .ocr,
                capturedAt: .now
            )

            let analyzed = ingredientAnalyzer.analyze(product: product)
            try dataStore.save(analyzedProduct: analyzed)
            activeProduct = analyzed
            latestSnapshot = try dataStore.latestSnapshot()
            pendingProductForOCR = nil
            cameraController.updateMode(.barcode)
            status = .scanning
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    private func refreshedAnalysis(from analyzedProduct: AnalyzedProduct) -> AnalyzedProduct {
        ingredientAnalyzer.analyze(product: analyzedProduct.product)
    }
}
