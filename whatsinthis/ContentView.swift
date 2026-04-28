//
//  ContentView.swift
//  whatsinthis
//
//  Created by Idil Saglam on 28/04/2026.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: ScanViewModel

    var body: some View {
        NavigationStack {
            ScanView(viewModel: viewModel)
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}
