import SwiftUI
@preconcurrency import AVFoundation

@MainActor final class CameraController: ObservableObject {
    let session = AVCaptureSession()
    @Published var message: String?
    @Published private(set) var isReady = false
    private let queue = DispatchQueue(label: "studio.camera")
    private var configured = false
    func start() async {
        var permitted = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        if !permitted { permitted = await requestAccess() }
        guard !Task.isCancelled else { return }
        guard permitted else { message = "Allow camera access in Settings to use Camera Trace."; return }
        if !configured {
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device) else { message = "A rear camera is needed. Try Screen Trace on this device."; return }
            session.beginConfiguration()
            session.sessionPreset = .high
            guard session.canAddInput(input) else { session.commitConfiguration(); message = "The camera could not be started."; return }
            session.addInput(input)
            session.commitConfiguration()
            configured = true
        }
        message = nil
        let captureSession = session
        queue.async { [weak self] in
            if !captureSession.isRunning { captureSession.startRunning() }
            let ready = captureSession.isRunning
            Task { @MainActor [weak self] in self?.isReady = ready }
        }
    }
    private func requestAccess() async -> Bool { await AVCaptureDevice.requestAccess(for: .video) }
    func stop() {
        isReady = false
        let captureSession = session
        queue.async { [weak self] in
            if captureSession.isRunning { captureSession.stopRunning() }
            Task { @MainActor [weak self] in self?.isReady = false }
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> CameraSurface {
        let surface = CameraSurface()
        surface.preview.session = session
        surface.preview.videoGravity = .resizeAspectFill
        return surface
    }
    func updateUIView(_ uiView: CameraSurface, context: Context) { uiView.setNeedsLayout() }
}

final class CameraSurface: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var preview: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    override func layoutSubviews() {
        super.layoutSubviews()
        if let connection = preview.connection, connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
    }
}
