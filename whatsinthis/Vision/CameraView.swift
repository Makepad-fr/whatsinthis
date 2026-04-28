//
//  CameraView.swift
//  whatsinthis
//
//  Created by Codex on 28/04/2026.
//

import AVFoundation
import SwiftUI

struct CameraView<Overlay: View>: View {
    @ObservedObject var controller: CameraSessionController
    @ViewBuilder var overlay: () -> Overlay

    var body: some View {
        ZStack {
            CameraPreviewRepresentable(session: controller.session)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            overlay()
        }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct CameraPreviewRepresentable: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.previewLayer.session = session
    }
}

private final class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Expected AVCaptureVideoPreviewLayer")
        }
        return layer
    }
}
