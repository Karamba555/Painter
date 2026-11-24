import SwiftUI
import PhotosUI
import AVFoundation

struct ProjectDetailView: View {
    let projectID: UUID
    @Environment(StudioLibrary.self) private var library
    @Environment(PurchaseStore.self) private var purchases
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var editingTitle = false
    @State private var deleteConfirmation = false
    @State private var showCamera = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var shareURL: URL?
    @State private var error: String?
    private var project: SavedProject? { library.state.projects.first { $0.id == projectID } }

    var body: some View {
        StudioPage {
            if let project {
                Text(project.drawing.title).studioTitle()
                HStack { Badge(text: project.isComplete ? "FINISHED" : "IN PROGRESS"); Spacer(); Text(project.createdAt, style: .date).font(StudioTheme.font(12)).foregroundStyle(StudioTheme.muted) }
                Group {
                    if let name = project.workPhoto, let image = ImageFiles.load(name) { Image(uiImage: image).resizable().scaledToFit() }
                    else { Artwork(drawing: project.drawing).scaledToFit() }
                }.frame(maxWidth: .infinity).frame(height: 340).clipped().clipShape(RoundedRectangle(cornerRadius: 24))
                NavigationLink {
                    if !library.state.canOpen(project.drawing, isPro: purchases.isPro) { PaywallView(isPushed: true) }
                    else if project.traceSettings?.mode == TraceMode.ar.rawValue { ARTracingWorkspace(drawing: project.drawing, existingProjectID: projectID) }
                    else { TracingWorkspace(drawing: project.drawing, mode: TraceMode(rawValue: project.traceSettings?.mode ?? "camera") ?? .camera, existingProjectID: projectID) }
                } label: { Text("Continue drawing →").font(StudioTheme.font(16, .bold)).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 18).background(StudioTheme.coral, in: RoundedRectangle(cornerRadius: 18)) }
                FinishedArtworkControls(showCamera: $showCamera, selectedPhoto: $selectedPhoto)
                Button { do { shareURL = try ImageFiles.pdf(for: project.drawing) } catch { self.error = error.localizedDescription } } label: { Label("Export outline PDF", systemImage: "doc.richtext").frame(minHeight: 44) }
                if let name = project.workPhoto, let url = ImageFiles.exportImage(name) { ShareLink(item: url) { Label("Share finished artwork", systemImage: "square.and.arrow.up").frame(minHeight: 44) } }
                Button("Rename project") { title = project.drawing.title; editingTitle = true }.frame(minHeight: 44)
                Button("Delete project", role: .destructive) { deleteConfirmation = true }.frame(minHeight: 44)
            }
        }.navigationTitle("My Project")
            .alert("Rename project", isPresented: $editingTitle) {
                TextField("Project name", text: $title)
                Button("Save") { library.renameProject(projectID, title: title) }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Delete this project?", isPresented: $deleteConfirmation, titleVisibility: .visible) {
                Button("Delete project", role: .destructive) { deleteProject() }
            } message: { Text("The project will be removed from Your Studio. Export your artwork first if you want to keep it.") }
            .fullScreenCover(isPresented: $showCamera) { ArtworkCamera { image in save(image) } }
            .task(id: selectedPhoto) {
                guard let selectedPhoto else { return }
                do {
                    guard let data = try await selectedPhoto.loadTransferable(type: Data.self), let image = UIImage(data: data) else { throw ImageFiles.ImageError.invalidImage }
                    save(image)
                } catch { self.error = error.localizedDescription }
            }
            .sheet(isPresented: Binding(get: { shareURL != nil }, set: { if !$0 { shareURL = nil } })) { if let shareURL { ShareSheet(items: [shareURL]) } }
            .alert("Couldn’t save artwork", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }
    private func save(_ image: UIImage) {
        do { library.finishProject(projectID, workPhoto: try ImageFiles.save(ImageFiles.normalized(image))) }
        catch { self.error = error.localizedDescription }
    }
    private func deleteProject() {
        guard let project else { return }
        let otherFiles = Set(library.state.projects.filter { $0.id != projectID }.flatMap { [$0.drawing.localImage, $0.workPhoto].compactMap { $0 } })
        do {
            for filename in Set([project.drawing.localImage, project.workPhoto].compactMap { $0 }) where !otherFiles.contains(filename) { try ImageFiles.remove(filename) }
            library.removeProject(projectID); dismiss()
        } catch { self.error = "The project files could not be removed. Please try again." }
    }
}

struct FinishedArtworkControls: View {
    @Binding var showCamera: Bool
    @Binding var selectedPhoto: PhotosPickerItem?
    @State private var permissionDenied = false
    var body: some View {
        VStack(spacing: 10) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button { Task {
                    var allowed = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
                    if !allowed { allowed = await AVCaptureDevice.requestAccess(for: .video) }
                    if allowed { showCamera = true } else { permissionDenied = true }
                } } label: { Label("Photograph your artwork", systemImage: "camera").frame(maxWidth: .infinity, minHeight: 48).studioCard(StudioTheme.peach, padding: 8) }
            }
            PhotosPicker(selection: $selectedPhoto, matching: .images) { Label("Choose artwork photo", systemImage: "photo").frame(maxWidth: .infinity, minHeight: 44) }
        }.alert("Allow camera access", isPresented: $permissionDenied) {
            if let url = URL(string: UIApplication.openSettingsURLString) { Button("Open Settings") { UIApplication.shared.open(url) } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Enable the camera in Settings, or choose a photo from your library.") }
    }
}

struct ArtworkCamera: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onCapture: (UIImage) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera; picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ArtworkCamera
        init(parent: ArtworkCamera) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onCapture(image) }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
