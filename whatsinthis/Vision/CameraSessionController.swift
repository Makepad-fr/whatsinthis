//
//  CameraSessionController.swift
//  whatsinthis
//
//  Created by Codex on 28/04/2026.
//

import AVFoundation
import Combine
import UIKit

enum CameraCaptureMode {
    case barcode
    case ingredients
}

// Capture-session objects are confined to `sessionQueue`; published UI state is
// pushed back onto the main actor before SwiftUI observes it.
final class CameraSessionController: NSObject, ObservableObject, @unchecked Sendable {
    @Published private(set) var authorizationStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published private(set) var isRunning = false
    @Published private(set) var isTorchEnabled = false
    @Published var mode: CameraCaptureMode = .barcode

    let session = AVCaptureSession()

    var onScanPayloadDetected: ((ScanPayload) -> Void)?
    var onPhotoCaptured: ((UIImage) -> Void)?
    var onError: ((String) -> Void)?

    private let sessionQueue = DispatchQueue(label: "io.makepad.whatsinthis.camera-session", qos: .userInitiated)
    private let metadataOutput = AVCaptureMetadataOutput()
    private let photoOutput = AVCapturePhotoOutput()

    private var videoInput: AVCaptureDeviceInput?
    private var isConfigured = false
    private var lastDetectedPayloadKey: String?
    private var lastDetectedAt = Date.distantPast

    func requestAccessIfNeeded() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

        switch authorizationStatus {
        case .authorized:
            configureIfNeeded()
            startSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    self.authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
                    if granted {
                        self.configureIfNeeded()
                        self.startSession()
                    }
                }
            }
        default:
            break
        }
    }

    func configureIfNeeded() {
        guard !isConfigured else { return }

        sessionQueue.async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            defer {
                self.session.commitConfiguration()
            }

            do {
                guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                    throw CameraError.noCamera
                }

                let input = try AVCaptureDeviceInput(device: camera)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                    self.videoInput = input
                }

                if self.session.canAddOutput(self.metadataOutput) {
                    self.session.addOutput(self.metadataOutput)
                    self.metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                    let supportedTypes = self.metadataOutput.availableMetadataObjectTypes
                    self.metadataOutput.metadataObjectTypes = supportedTypes.filter {
                        [.ean8, .ean13, .upce, .code128, .qr].contains($0)
                    }
                }

                if self.session.canAddOutput(self.photoOutput) {
                    self.session.addOutput(self.photoOutput)
                    self.photoOutput.maxPhotoQualityPrioritization = .balanced
                }

                Task { @MainActor in
                    self.isConfigured = true
                }
            } catch {
                Task { @MainActor in
                    self.onError?(error.localizedDescription)
                }
            }
        }
    }

    func startSession() {
        guard authorizationStatus == .authorized else { return }
        configureIfNeeded()

        sessionQueue.async {
            guard !self.session.isRunning else { return }
            self.session.startRunning()
            Task { @MainActor in
                self.isRunning = true
            }
        }
    }

    func stopSession() {
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
            Task { @MainActor in
                self.isRunning = false
            }
        }
    }

    func toggleTorch() {
        guard let device = videoInput?.device, device.hasTorch else { return }

        do {
            try device.lockForConfiguration()
            if device.isTorchActive {
                device.torchMode = .off
                isTorchEnabled = false
            } else {
                try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
                isTorchEnabled = true
            }
            device.unlockForConfiguration()
        } catch {
            onError?("Torch is unavailable right now.")
        }
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        settings.photoQualityPrioritization = .balanced
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func updateMode(_ mode: CameraCaptureMode) {
        self.mode = mode
        if mode == .ingredients {
            lastDetectedPayloadKey = nil
            lastDetectedAt = .distantPast
        }
    }
}

extension CameraSessionController: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        MainActor.assumeIsolated {
            handleMetadataObjects(metadataObjects)
        }
    }
}

extension CameraSessionController: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            Task { @MainActor in
                self.onError?(error.localizedDescription)
            }
            return
        }

        guard
            let data = photo.fileDataRepresentation(),
            let image = UIImage(data: data)
        else {
            Task { @MainActor in
                self.onError?("The captured photo could not be processed.")
            }
            return
        }

        Task { @MainActor in
            self.onPhotoCaptured?(image)
        }
    }
}

private extension CameraSessionController {
    @MainActor
    func handleMetadataObjects(_ metadataObjects: [AVMetadataObject]) {
        guard mode == .barcode else { return }

        guard
            let barcodeObject = metadataObjects.compactMap({ $0 as? AVMetadataMachineReadableCodeObject }).first,
            let payload = barcodeObject.stringValue
        else {
            return
        }

        let symbology: ScanSymbology = barcodeObject.type == .qr ? .qrCode : .linearCode
        guard let scanPayload = ScanPayloadParser.parse(rawValue: payload, symbology: symbology) else {
            return
        }

        let now = Date.now
        if scanPayload.deduplicationKey == lastDetectedPayloadKey, now.timeIntervalSince(lastDetectedAt) < 1.5 {
            return
        }

        lastDetectedPayloadKey = scanPayload.deduplicationKey
        lastDetectedAt = now
        onScanPayloadDetected?(scanPayload)
    }
}

private enum CameraError: LocalizedError {
    case noCamera

    var errorDescription: String? {
        switch self {
        case .noCamera:
            "A back camera is required to scan products."
        }
    }
}
