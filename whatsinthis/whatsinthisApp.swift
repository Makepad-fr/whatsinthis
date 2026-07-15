//
//  whatsinthisApp.swift
//  whatsinthis
//
//  Created by Idil Saglam on 28/04/2026.
//

import SwiftData
import SwiftUI

@main
struct whatsinthisApp: App {
    @Environment(\.scenePhase) private var scenePhase

    private let modelContainer: ModelContainer
    @StateObject private var scanViewModel: ScanViewModel

    init() {
        let modelContainer = DataStore.makeContainer()
        self.modelContainer = modelContainer

        let dataStore = DataStore(modelContainer: modelContainer)
        let analyzer = IngredientAnalyzer()
        let visionProcessor = VisionProcessor()
        let imageRepository = ProductImageRepository(dataStore: dataStore)
        let productBackend: any ProductBackend
        if let backendBaseURL = BackendConfiguration.baseURL() {
            let transport = HTTPProductBackendTransport(baseURL: backendBaseURL)
            productBackend = RemoteProductBackend(transport: transport)
        } else {
            productBackend = UnavailableProductBackend()
        }

        _scanViewModel = StateObject(
            wrappedValue: ScanViewModel(
                dataStore: dataStore,
                productBackend: productBackend,
                ingredientAnalyzer: analyzer,
                visionProcessor: visionProcessor,
                imageRepository: imageRepository
            )
        )

        OpenPanelAnalytics.trackAppOpened()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: scanViewModel)
                .onChange(of: scenePhase) { phase in
                    if phase == .background {
                        OpenPanelAnalytics.trackAppClosed()
                    }
                }
        }
        .modelContainer(modelContainer)
    }
}
