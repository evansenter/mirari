import AVFoundation
import UIKit

@MainActor
@Observable
final class CameraManager: NSObject, @unchecked Sendable {
    var previewLayer: AVCaptureVideoPreviewLayer?
    var lastCapturedImage: UIImage?
    var isAuthorized = false
    var error: CameraError?

    private let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var photoContinuation: CheckedContinuation<UIImage?, Never>?
    private var isConfigured = false

    enum CameraError: LocalizedError, Sendable {
        case notAuthorized
        case configurationFailed
        case captureError(String)

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Camera access not authorized. Please enable in Settings."
            case .configurationFailed:
                return "Failed to configure camera."
            case .captureError(let message):
                return "Capture failed: \(message)"
            }
        }
    }

    override init() {
        super.init()
    }

    func checkAuthorization() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        default:
            isAuthorized = false
            error = .notAuthorized
        }
    }

    func configure() {
        guard isAuthorized, !isConfigured else { return }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo

        // Add video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              captureSession.canAddInput(videoInput) else {
            error = .configurationFailed
            captureSession.commitConfiguration()
            return
        }
        captureSession.addInput(videoInput)

        // Add photo output
        guard captureSession.canAddOutput(photoOutput) else {
            error = .configurationFailed
            captureSession.commitConfiguration()
            return
        }
        captureSession.addOutput(photoOutput)

        // Set maximum photo dimensions for high resolution capture
        let maxDimensions = videoDevice.activeFormat.supportedMaxPhotoDimensions.first ?? CMVideoDimensions(width: 0, height: 0)
        photoOutput.maxPhotoDimensions = maxDimensions

        captureSession.commitConfiguration()

        // Create preview layer
        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        previewLayer = layer

        isConfigured = true
    }

    func start() {
        guard isConfigured, !captureSession.isRunning else { return }
        captureSession.startRunning()
    }

    func stop() {
        guard captureSession.isRunning else { return }
        captureSession.stopRunning()
    }

    func capturePhoto() async -> UIImage? {
        guard isConfigured else { return nil }

        return await withCheckedContinuation { continuation in
            photoContinuation = continuation
            let settings = AVCapturePhotoSettings()
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image: UIImage?
        let captureError: CameraError?

        if let error {
            image = nil
            captureError = .captureError(error.localizedDescription)
        } else if let imageData = photo.fileDataRepresentation(),
                  let uiImage = UIImage(data: imageData) {
            image = uiImage
            captureError = nil
        } else {
            image = nil
            captureError = nil
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            if let captureError {
                self.error = captureError
            }
            if let image {
                self.lastCapturedImage = image
            }
            self.photoContinuation?.resume(returning: image)
            self.photoContinuation = nil
        }
    }
}
