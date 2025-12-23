import SwiftUI
import AVFoundation

struct ScannerView: View {
    @State private var cameraManager = CameraManager()
    @State private var geminiService = GeminiService()
    @State private var scryfallService = ScryfallService()
    @State private var isCapturing = false
    @State private var showingResult = false
    @State private var detectionResult: DetectionResult?
    @State private var scryfallCard: ScryfallCard?
    @State private var detectionError: Error?
    @State private var captureTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ZStack {
                // Camera preview
                CameraPreviewView(cameraManager: cameraManager)
                    .ignoresSafeArea()

                // Overlay
                VStack {
                    Spacer()

                    // Card frame guide
                    CardFrameGuide()
                        .padding(.horizontal, 40)

                    Spacer()

                    // Capture button and cancel
                    VStack(spacing: 16) {
                        CaptureButton(isCapturing: isCapturing) {
                            captureTask = Task {
                                await captureAndIdentify()
                            }
                        }

                        Button("Cancel") {
                            cancelCapture()
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .opacity(isCapturing ? 1 : 0)
                    }
                    .padding(.bottom, 40)
                }

                // Error overlay
                if let error = cameraManager.error {
                    ErrorOverlay(message: error.localizedDescription)
                }

                // Authorization prompt
                if !cameraManager.isAuthorized && cameraManager.error == nil {
                    AuthorizationPrompt()
                }
            }
            .navigationTitle("Scan Card")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await cameraManager.checkAuthorization()
                if cameraManager.isAuthorized {
                    cameraManager.configure()
                    cameraManager.start()
                }
            }
            .onDisappear {
                cameraManager.stop()
            }
            .sheet(isPresented: $showingResult) {
                if let image = cameraManager.lastCapturedImage {
                    DetectedCardView(
                        capturedImage: image,
                        detectionResult: detectionResult,
                        scryfallCard: scryfallCard,
                        detectionError: detectionError
                    )
                }
            }
        }
    }

    private func captureAndIdentify() async {
        isCapturing = true
        defer {
            isCapturing = false
            captureTask = nil
        }

        // Reset previous results
        detectionResult = nil
        scryfallCard = nil
        detectionError = nil

        // Capture photo
        guard let image = await cameraManager.capturePhoto() else {
            print("[ScannerView] Photo capture failed - no image returned")
            detectionError = CameraManager.CameraError.captureError("Failed to capture photo")
            showingResult = true
            return
        }

        // Check for cancellation before API call
        guard !Task.isCancelled else { return }

        // Identify card with Gemini
        do {
            let detection = try await geminiService.identifyCard(image: image)
            detectionResult = detection

            // Check for cancellation before Scryfall lookup
            guard !Task.isCancelled else { return }

            // Look up card on Scryfall to get full details
            do {
                scryfallCard = try await scryfallService.lookupFromDetection(detection)
                print("[ScannerView] Scryfall lookup successful: \(scryfallCard?.name ?? "unknown")")
            } catch {
                // Scryfall lookup failure is non-fatal - we still show Gemini results
                print("[ScannerView] Scryfall lookup failed: \(error.localizedDescription)")
                // Don't set detectionError - we have valid Gemini results
            }
        } catch {
            // Don't show error if cancelled
            guard !Task.isCancelled else { return }
            detectionError = error
        }

        // Show results (even if detection failed, we show the error)
        guard !Task.isCancelled else { return }
        showingResult = true
    }

    private func cancelCapture() {
        captureTask?.cancel()
        captureTask = nil
        isCapturing = false
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let cameraManager: CameraManager

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let previewLayer = cameraManager.previewLayer else { return }

        if previewLayer.superlayer == nil {
            uiView.layer.addSublayer(previewLayer)
        }
        previewLayer.frame = uiView.bounds
    }
}

struct CardFrameGuide: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(Color.white.opacity(0.8), lineWidth: 3)
            .aspectRatio(0.714, contentMode: .fit) // MTG card ratio: 63mm x 88mm
            .shadow(color: .black.opacity(0.5), radius: 4)
    }
}

struct CaptureButton: View {
    let isCapturing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 72, height: 72)

                Circle()
                    .fill(isCapturing ? Color.gray : Color.white)
                    .frame(width: 60, height: 60)

                if isCapturing {
                    ProgressView()
                        .tint(.black)
                }
            }
        }
        .disabled(isCapturing)
    }
}

struct ErrorOverlay: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)

            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.8))
    }
}

struct AuthorizationPrompt: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 64))
                .foregroundStyle(.white)

            Text("Camera Access Required")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

            Text("Mirari needs camera access to scan Magic cards.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 40)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.9))
    }
}

#Preview {
    ScannerView()
}
