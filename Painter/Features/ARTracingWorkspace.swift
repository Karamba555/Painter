import SwiftUI
import PhotosUI

struct ARTracingWorkspace: View {
    let drawing: Drawing
    var existingProjectID: UUID? = nil
    @Environment(StudioLibrary.self) private var library
    @Environment(PurchaseStore.self) private var purchases
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller = ARTraceController()
    @State private var width = 0.18
    @State private var rotation = 0.0
    @State private var opacity = 0.8
    @State private var projectID: UUID?
    @State private var error: String?
    @State private var showFinished = false
    @State private var showCamera = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var shareURL: URL?
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                ARCameraSurface(controller: controller, width: Float(width), rotation: Float(rotation), opacity: Float(opacity))
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: controller.needsRealignment ? "exclamationmark.triangle" : "viewfinder")
                    Text(controller.status).font(StudioTheme.font(14, .medium)).fixedSize(horizontal: false, vertical: true)
                }.padding(16).frame(maxWidth: .infinity).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18)).padding(16)
                if controller.unavailable {
                    VStack(spacing: 16) {
                        Spacer()
                        StudioButton("Choose another mode") { dismiss() }
                        if let url = URL(string: UIApplication.openSettingsURLString) { Link("Open Settings", destination: url) }
                        Spacer()
                    }.padding(24)
                }
            }.frame(maxHeight: .infinity)
            if !controller.unavailable {
                VStack(spacing: 10) {
                    if controller.isPlaced && !controller.locked && !controller.needsRealignment {
                        HStack { Text("Width \(Int(width * 100)) cm").frame(width: 90, alignment: .leading); Slider(value: $width, in: 0.05...0.35) }
                        HStack { Text("Rotate").frame(width: 90, alignment: .leading); Slider(value: $rotation, in: -180...180) }
                        HStack { Text("Opacity").frame(width: 90, alignment: .leading); Slider(value: $opacity, in: 0.15...1) }
                    }
                    HStack {
                        if controller.needsRealignment { Button("Realign outline") { controller.resetPlacement() }.fontWeight(.bold) }
                        else { Button(controller.locked ? "Unlock" : "Lock outline") { controller.locked.toggle() }.disabled(!controller.isPlaced) }
                        Spacer()
                        if controller.isPlaced && !controller.needsRealignment {
                            Button("Reposition") { controller.resetPlacement() }.disabled(controller.locked)
                            Button("Finish") { finish() }.fontWeight(.bold)
                        }
                    }.frame(minHeight: 44)
                    Text("Anchored to the table. Keep the paper in place.").font(StudioTheme.font(11)).foregroundStyle(StudioTheme.muted)
                }.font(StudioTheme.font(13)).padding(16).background(StudioTheme.paper)
            }
        }.navigationTitle("AR Trace").navigationBarTitleDisplayMode(.inline).toolbar(.hidden, for: .tabBar)
            .modifier(ActivityTracking(isActive: controller.isPlaced && !controller.needsRealignment && !showFinished))
            .task {
                guard library.state.canOpen(drawing, isPro: purchases.isPro) else { error = "This drawing requires Pro."; return }
                await controller.start()
                guard !controller.unavailable else { return }
                guard let source = ImageFiles.source(for: drawing) else { error = "This drawing could not be loaded."; return }
                do { try controller.prepare(image: drawing.isOutline ? source : ImageFiles.outline(source, detailed: true)) }
                catch { self.error = error.localizedDescription; return }
                if !controller.unavailable {
                    projectID = existingProjectID ?? library.startProject(drawing, isPro: purchases.isPro)
                    if let settings = library.state.projects.first(where: { $0.id == projectID })?.traceSettings, settings.mode == "ar" {
                        width = settings.scale; rotation = settings.rotation; opacity = settings.opacity
                    }
                    UIApplication.shared.isIdleTimerDisabled = true
                }
            }
            .onDisappear { saveSettings(); controller.pause(); UIApplication.shared.isIdleTimerDisabled = false }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active && !showFinished { Task { await controller.start() }; UIApplication.shared.isIdleTimerDisabled = true }
                else { saveSettings(); controller.pause(); UIApplication.shared.isIdleTimerDisabled = false }
            }
            .sheet(isPresented: $showFinished) {
                NavigationStack {
                    StudioPage {
                        Text("Made by you.").studioTitle()
                        Text("Your project is saved. Add a photo of your finished drawing.").studioCaption()
                        FinishedArtworkControls(showCamera: $showCamera, selectedPhoto: $selectedPhoto)
                        Button("Export outline PDF") { do { shareURL = try ImageFiles.pdf(for: drawing) } catch { self.error = error.localizedDescription } }.frame(minHeight: 44)
                        StudioButton("Back to my studio") { showFinished = false; dismiss() }
                    }.navigationTitle("Drawing saved")
                        .fullScreenCover(isPresented: $showCamera) { ArtworkCamera { saveArtwork($0) } }
                        .sheet(isPresented: Binding(get: { shareURL != nil }, set: { if !$0 { shareURL = nil } })) { if let shareURL { ShareSheet(items: [shareURL]) } }
                }
            }
            .task(id: selectedPhoto) {
                guard let selectedPhoto else { return }
                do {
                    guard let data = try await selectedPhoto.loadTransferable(type: Data.self), let image = UIImage(data: data) else { throw ImageFiles.ImageError.invalidImage }
                    saveArtwork(image)
                } catch { self.error = error.localizedDescription }
            }
            .alert("AR Trace", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }
    private func finish() { guard let projectID else { return }; saveSettings(); library.finishProject(projectID); controller.pause(); UIApplication.shared.isIdleTimerDisabled = false; showFinished = true }
    private func saveSettings() { if let projectID { library.saveTraceSettings(TraceSettings(mode: "ar", scale: width, opacity: opacity, rotation: rotation), projectID: projectID) } }
    private func saveArtwork(_ image: UIImage) { guard let projectID else { return }; do { library.finishProject(projectID, workPhoto: try ImageFiles.save(ImageFiles.normalized(image))) } catch { self.error = error.localizedDescription } }
}
