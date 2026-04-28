//
//  ScanView.swift
//  whatsinthis
//
//  Created by Codex on 28/04/2026.
//

import AVFoundation
import SwiftUI

struct ScanView: View {
    @ObservedObject var viewModel: ScanViewModel
    @ObservedObject private var cameraController: CameraSessionController
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(viewModel: ScanViewModel) {
        self.viewModel = viewModel
        _cameraController = ObservedObject(wrappedValue: viewModel.cameraController)
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = ScanLayoutMetrics(
                containerSize: proxy.size,
                safeAreaInsets: proxy.safeAreaInsets,
                horizontalSizeClass: horizontalSizeClass,
                dynamicTypeSize: dynamicTypeSize
            )

            ScrollView {
                VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                    header(metrics: metrics)

                    Group {
                        switch cameraController.authorizationStatus {
                        case .authorized:
                            authorizedContent(metrics: metrics)
                        case .notDetermined:
                            cameraPermissionCard(
                                message: "Requesting camera access…",
                                metrics: metrics
                            )
                        default:
                            cameraPermissionCard(
                                message: "Camera access is required to scan barcodes and ingredient labels.",
                                metrics: metrics
                            )
                        }
                    }

                    supplementarySection(metrics: metrics)
                }
                .frame(maxWidth: metrics.contentMaxWidth, alignment: .top)
                .padding(.horizontal, metrics.horizontalPadding)
                .padding(.top, metrics.topPadding)
                .padding(.bottom, metrics.bottomPadding)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .background(backgroundGradient.ignoresSafeArea())
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $viewModel.activeProduct) { product in
            ProductDetailView(
                viewModel: ProductDetailViewModel(
                    analyzedProduct: product,
                    imageRepository: viewModel.imageRepository,
                    productService: viewModel.productService,
                    ingredientAnalyzer: viewModel.ingredientAnalyzer
                )
            )
        }
        .task {
            await viewModel.prepare()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            cameraController.requestAccessIfNeeded()
        }
    }

    private func authorizedContent(metrics: ScanLayoutMetrics) -> some View {
        CameraView(controller: cameraController) {
            ZStack {
                RoundedRectangle(cornerRadius: metrics.cameraCornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.24), lineWidth: 1)

                VStack(spacing: 0) {
                    HStack {
                        statusBadge
                        Spacer()
                    }
                    Spacer(minLength: 0)
                    scanGuide(metrics: metrics)
                    Spacer(minLength: 0)
                    controlBar(metrics: metrics)
                }
                .padding(metrics.cameraInnerPadding)
            }
        }
        .frame(height: metrics.cameraHeight)
        .frame(maxWidth: .infinity)
    }

    private func supplementarySection(metrics: ScanLayoutMetrics) -> some View {
        LazyVGrid(columns: metrics.supportingColumns, spacing: metrics.cardSpacing) {
            if let latestSnapshot = viewModel.latestSnapshot {
                latestScanCard(snapshot: latestSnapshot)
            }

            recommendationsCard
        }
    }

    private func header(metrics: ScanLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What’s In This?")
                .font(.system(size: metrics.headerTitleSize, weight: .bold, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: false, vertical: true)

            Text("Scan a barcode or product QR first. If the product database is incomplete or you’re offline, switch to the ingredient label and keep moving.")
                .font(metrics.headerBodyFont)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: metrics.headerTextMaxWidth, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusBadge: some View {
        Text(statusMessage)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.black.opacity(0.35), in: Capsule())
    }

    private func scanGuide(metrics: ScanLayoutMetrics) -> some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .strokeBorder(Color.white.opacity(0.8), style: StrokeStyle(lineWidth: 3, dash: [12, 8]))
            .frame(
                width: metrics.scanGuideWidth,
                height: cameraController.mode == .barcode ? metrics.barcodeGuideHeight : metrics.ingredientGuideHeight
            )
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: cameraController.mode == .barcode ? "barcode.viewfinder" : "text.viewfinder")
                        .font(.system(size: metrics.scanGuideIconSize))
                        .foregroundStyle(.white.opacity(0.88))

                    Text(cameraController.mode == .barcode ? "Center the barcode or product QR inside the frame." : "Fill the frame with the ingredient panel.")
                        .font(.footnote.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.92))
                        .frame(maxWidth: metrics.scanGuideWidth * 0.72)
                }
            }
    }

    private func controlBar(metrics: ScanLayoutMetrics) -> some View {
        VStack(spacing: 12) {
            if case .needsOCR(let message) = viewModel.status {
                overlayMessage(message)
            } else if case .error(let message) = viewModel.status {
                overlayMessage(message)
            }

            if metrics.usesStackedControls {
                LazyVGrid(columns: metrics.controlColumns, spacing: 12) {
                    controlButtons
                }
            } else {
                HStack(spacing: 12) {
                    controlButtons
                }
            }
        }
    }

    @ViewBuilder
    private var controlButtons: some View {
        controlButton(
            title: cameraController.isTorchEnabled ? "Torch Off" : "Torch",
            systemImage: cameraController.isTorchEnabled ? "flashlight.off.fill" : "flashlight.on.fill",
            action: viewModel.toggleTorch
        )

        if cameraController.mode == .barcode {
            controlButton(
                title: "Scan Ingredients",
                systemImage: "text.viewfinder",
                action: viewModel.beginIngredientCapture
            )
        } else {
            controlButton(
                title: viewModel.isProcessingCapture ? "Reading…" : "Capture Label",
                systemImage: "camera.circle.fill",
                action: viewModel.captureIngredientPhoto
            )
        }

        controlButton(
            title: cameraController.mode == .barcode ? "Need OCR?" : "Back To Barcode",
            systemImage: cameraController.mode == .barcode ? "arrow.trianglehead.2.clockwise.rotate.90" : "arrow.uturn.backward.circle",
            action: {
                if cameraController.mode == .barcode {
                    viewModel.beginIngredientCapture()
                } else {
                    viewModel.returnToBarcodeMode()
                }
            }
        )
    }

    private var recommendationsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recommendations")
                .font(.headline)
            Text("If two products look similar on the shelf, compare the few things that usually change the buying decision fastest.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 10)], spacing: 10) {
                recommendationTile(
                    title: "Sugar",
                    detail: "Drinks, yogurt, cereals",
                    systemImage: "cube.box.fill"
                )
                recommendationTile(
                    title: "Sat. fat",
                    detail: "Desserts, dairy, spreads",
                    systemImage: "drop.fill"
                )
                recommendationTile(
                    title: "Additives",
                    detail: "Snacks, sauces, ready meals",
                    systemImage: "sparkles.rectangle.stack.fill"
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func latestScanCard(snapshot: RecentScanSummary) -> some View {
        Button(action: viewModel.reopenLatestScan) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last Scan")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(snapshot.name)
                        .font(.headline)
                        .multilineTextAlignment(.leading)
                    Text(snapshot.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.up.forward.app")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .padding(.top, 4)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func recommendationTile(title: String, detail: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func controlButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 54)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    private func overlayMessage(_ message: String) -> some View {
        Text(message)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.74), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func cameraPermissionCard(message: String, metrics: ScanLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "camera.fill")
                .font(.system(size: 28))
            Text("Camera Required")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: metrics.permissionCardHeight, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var statusMessage: String {
        switch viewModel.status {
        case .idle, .scanning:
            if let barcode = viewModel.currentBarcode {
                return "Ready • \(barcode)"
            }
            return cameraController.mode == .barcode ? "Barcode ready" : "Ingredient capture ready"
        case .lookingUp(let message):
            return message
        case .needsOCR:
            return "OCR fallback ready"
        case .error:
            return "Attention needed"
        }
    }

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                colorScheme == .dark ? Color(red: 0.08, green: 0.11, blue: 0.10) : Color(red: 0.95, green: 0.97, blue: 0.93),
                colorScheme == .dark ? Color(red: 0.12, green: 0.16, blue: 0.13) : Color(red: 0.88, green: 0.91, blue: 0.86)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct ScanLayoutMetrics {
    let containerSize: CGSize
    let safeAreaInsets: EdgeInsets
    let horizontalSizeClass: UserInterfaceSizeClass?
    let dynamicTypeSize: DynamicTypeSize

    var isRegularWidth: Bool {
        horizontalSizeClass == .regular || containerSize.width >= 768
    }

    var isCompactWidth: Bool {
        containerSize.width < 390
    }

    var contentMaxWidth: CGFloat {
        isRegularWidth ? 920 : .infinity
    }

    var horizontalPadding: CGFloat {
        isRegularWidth ? 28 : 20
    }

    var topPadding: CGFloat {
        safeAreaInsets.top + (isRegularWidth ? 18 : 12)
    }

    var bottomPadding: CGFloat {
        safeAreaInsets.bottom + (isRegularWidth ? 26 : 18)
    }

    var sectionSpacing: CGFloat {
        isRegularWidth ? 22 : 18
    }

    var cardSpacing: CGFloat {
        16
    }

    var headerTitleSize: CGFloat {
        if isRegularWidth {
            return 34
        }

        return isCompactWidth ? 28 : 32
    }

    var headerBodyFont: Font {
        isCompactWidth ? .body : .title3
    }

    var headerTextMaxWidth: CGFloat {
        isRegularWidth ? 760 : .infinity
    }

    var cameraHeight: CGFloat {
        if isRegularWidth {
            return min(max(containerSize.height * 0.52, 460), 620)
        }

        return min(max(containerSize.width * 1.06, 430), 590)
    }

    var cameraCornerRadius: CGFloat {
        isRegularWidth ? 34 : 28
    }

    var cameraInnerPadding: CGFloat {
        isRegularWidth ? 22 : 18
    }

    var scanGuideWidth: CGFloat {
        if isRegularWidth {
            return min(containerSize.width * 0.34, 340)
        }

        return min(containerSize.width * 0.62, 300)
    }

    var barcodeGuideHeight: CGFloat {
        scanGuideWidth * 0.78
    }

    var ingredientGuideHeight: CGFloat {
        scanGuideWidth * 0.94
    }

    var scanGuideIconSize: CGFloat {
        isRegularWidth ? 34 : 30
    }

    var permissionCardHeight: CGFloat {
        isRegularWidth ? 300 : 240
    }

    var usesStackedControls: Bool {
        isCompactWidth || dynamicTypeSize >= .accessibility1
    }

    var controlColumns: [GridItem] {
        let count = isCompactWidth ? 2 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    var supportingColumns: [GridItem] {
        [GridItem(.adaptive(minimum: isRegularWidth ? 280 : 260), spacing: 16)]
    }
}
