import SwiftUI
import ARKit
import RealityKit
import AVFoundation

/// Markerless table anchoring prototype. It does not track the paper itself.
@MainActor final class ARTraceController: NSObject, ObservableObject, ARSessionDelegate {
    @Published private(set) var status = "Slowly scan the table around your paper."
    @Published private(set) var isPlaced = false
    @Published private(set) var trackingNormal = false
    @Published private(set) var needsRealignment = false
    @Published private(set) var unavailable = false
    @Published var locked = false
    private weak var view: ARView?
    private var anchorEntity: AnchorEntity?
    private var model: ModelEntity?
    private var texture: TextureResource?
    private var imageAspect: Float = 1
    private var material = UnlitMaterial()
    private var surfaceDetected = false
    private var started = false

    func attach(_ view: ARView) {
        self.view = view
        view.automaticallyConfigureSession = false
        view.session.delegate = self
        view.session.delegateQueue = .main
        let tap = UITapGestureRecognizer(target: self, action: #selector(place(_:)))
        view.addGestureRecognizer(tap)
    }
    func prepare(image: UIImage) throws {
        let transparent = ImageFiles.transparentOutline(image)
        guard let cg = transparent.cgImage else { throw ImageFiles.ImageError.invalidImage }
        texture = try TextureResource.generate(from: cg, options: .init(semantic: .color))
        imageAspect = Float(image.size.width / image.size.height)
        material.color = .init(tint: .white, texture: .init(texture!))
        material.blending = .transparent(opacity: .init(floatLiteral: 0.8))
        if #available(iOS 18.0, *) { material.faceCulling = .none }
    }
    func start() async {
        guard ARWorldTrackingConfiguration.isSupported else {
            unavailable = true; status = "AR Trace needs a compatible iPhone or iPad. You can use Screen Trace on this device."; return
        }
        var allowed = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        if !allowed { allowed = await AVCaptureDevice.requestAccess(for: .video) }
        guard !Task.isCancelled else { return }
        guard allowed else { unavailable = true; status = "Allow camera access in Settings to use AR Trace."; return }
        guard let view else { return }
        unavailable = false
        if !isPlaced { status = surfaceDetected ? "Tap the paper to place your outline." : "Slowly scan the table around your paper." }
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .none
        view.session.run(configuration, options: started ? [] : [.resetTracking, .removeExistingAnchors])
        started = true
    }
    func pause() {
        view?.session.pause()
        if isPlaced { requireRealignment("Session paused. Realign the outline before drawing.") }
    }
    func resetPlacement() {
        if let anchorEntity { view?.scene.removeAnchor(anchorEntity) }
        anchorEntity = nil; model = nil
        isPlaced = false; locked = false; needsRealignment = false
        status = surfaceDetected ? "Tap the paper to place your outline." : "Slowly scan the table around your paper."
    }
    func update(width: Float, rotation: Float, opacity: Float) {
        model?.scale = SIMD3(repeating: width / 0.18)
        model?.orientation = simd_quatf(angle: rotation * .pi / 180, axis: [0, 1, 0])
        material.blending = .transparent(opacity: .init(floatLiteral: opacity))
        model?.model?.materials = [material]
    }
    @objc private func place(_ recognizer: UITapGestureRecognizer) {
        guard !locked, !needsRealignment, trackingNormal, let view, texture != nil else { return }
        let point = recognizer.location(in: view)
        guard let result = view.raycast(from: point, allowing: .existingPlaneGeometry, alignment: .horizontal).first else {
            status = "No surface here yet. Scan the textured area around your paper, then tap again."; return
        }
        resetPlacement()
        let entity = AnchorEntity(world: result.worldTransform)
        let plane = ModelEntity(mesh: .generatePlane(width: 0.18, depth: 0.18 / imageAspect), materials: [material])
        plane.position.y = 0.001
        entity.addChild(plane)
        view.scene.addAnchor(entity)
        anchorEntity = entity; model = plane
        isPlaced = true
        status = "Outline placed. Adjust it, then lock. Keep the paper still."
    }
    private func requireRealignment(_ message: String) {
        needsRealignment = true; locked = false; model?.isEnabled = false; status = message
    }
    nonisolated func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        let state = camera.trackingState
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch state {
            case .normal:
                self.trackingNormal = true
                if !self.isPlaced { self.status = self.surfaceDetected ? "Tap the paper to place your outline." : "Slowly scan the table around your paper." }
            case .notAvailable:
                self.trackingNormal = false
                if self.isPlaced { self.requireRealignment("Tracking unavailable. Stop drawing and realign.") }
                else { self.status = "Tracking unavailable. Try better lighting and restart AR." }
            case .limited(let reason):
                self.trackingNormal = false
                let message: String
                switch reason {
                case .excessiveMotion: message = "Move your phone more slowly."
                case .insufficientFeatures: message = "Show more of the textured table around your paper."
                case .relocalizing: message = "Finding the table again."
                case .initializing: message = "Slowly scan the table around your paper."
                @unknown default: message = "Tracking is limited."
                }
                if self.isPlaced { self.requireRealignment(message + " Stop drawing and realign.") }
                else { self.status = message }
            }
        }
    }
    nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        let found = anchors.contains { $0 is ARPlaneAnchor }
        Task { @MainActor [weak self] in
            guard let self, found else { return }
            self.surfaceDetected = true
            if !self.isPlaced && self.trackingNormal { self.status = "Tap the paper to place your outline." }
        }
    }
    nonisolated func sessionWasInterrupted(_ session: ARSession) {
        Task { @MainActor [weak self] in self?.requireRealignment("AR was interrupted. Stop drawing and realign when the camera returns.") }
    }
    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor [weak self] in self?.requireRealignment("AR tracking stopped. Return to mode selection and try again.") }
    }
}

struct ARCameraSurface: UIViewRepresentable {
    @ObservedObject var controller: ARTraceController
    let width: Float
    let rotation: Float
    let opacity: Float
    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: ARWorldTrackingConfiguration.isSupported ? .ar : .nonAR, automaticallyConfigureSession: false)
        controller.attach(view)
        return view
    }
    func updateUIView(_ view: ARView, context: Context) { controller.update(width: width, rotation: rotation, opacity: opacity) }
    static func dismantleUIView(_ uiView: ARView, coordinator: ()) { uiView.session.pause(); uiView.scene.anchors.removeAll() }
}
