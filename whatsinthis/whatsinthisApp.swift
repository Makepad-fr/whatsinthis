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
    private let modelContainer: ModelContainer
    @StateObject private var scanViewModel: ScanViewModel

    init() {
        let modelContainer = DataStore.makeContainer()
        self.modelContainer = modelContainer

        let dataStore = DataStore(modelContainer: modelContainer)
        let analyzer = IngredientAnalyzer()
        let visionProcessor = VisionProcessor()
        let imageRepository = ProductImageRepository(dataStore: dataStore)
        let transport = HTTPProductBackendTransport(baseURL: BackendConfiguration.baseURL())
        let productBackend = RemoteProductBackend(transport: transport)

        _scanViewModel = StateObject(
            wrappedValue: ScanViewModel(
                dataStore: dataStore,
                productBackend: productBackend,
                ingredientAnalyzer: analyzer,
                visionProcessor: visionProcessor,
                imageRepository: imageRepository
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: scanViewModel)
        }
        .modelContainer(modelContainer)
    }
}
