import SwiftUI
import PhotosUI

struct DrawingAccessView: View {
    let drawing: Drawing
    @Environment(StudioLibrary.self) private var library
    @Environment(PurchaseStore.self) private var purchases
    var body: some View {
        if library.state.canOpen(drawing, isPro: purchases.isPro) { ModeChooserView(drawing: drawing) }
        else { PaywallView(isPushed: true) }
    }
}

struct ModeChooserView: View {
    let drawing: Drawing
    @State private var setup: TraceMode?
    @State private var selected: TraceMode?
    var body: some View {
        StudioPage {
            Text("How will you trace?").studioTitle()
            Text("Same drawing. Three ways to make it yours.").studioCaption()
            ForEach(TraceMode.allCases) { mode in
                VStack(spacing: 10) {
                    Button { selected = mode } label: {
                        HStack(spacing: 12) {
                            LoopVideo(name: mode.rawValue).frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: 16))
                            VStack(alignment: .leading, spacing: 6) { Text(mode.title).font(StudioTheme.font(19, .bold)); Text(mode.caption).font(StudioTheme.font(12)).foregroundStyle(StudioTheme.muted) }.frame(maxWidth: .infinity, alignment: .leading)
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityLabel(mode.title + ". " + mode.caption)
                    HStack {
                        Text(mode.badge).font(StudioTheme.font(10, .bold)).foregroundStyle(StudioTheme.green)
                        Spacer(minLength: 4)
                        Button("See setup →") { setup = mode }.font(StudioTheme.font(12, .medium)).frame(minHeight: 44).accessibilityLabel("See \(mode.title) setup")
                    }
                }.studioCard(padding: 12)
            }
            Text("Watch the phone move: Camera drifts, AR stays aligned.").font(StudioTheme.font(12)).foregroundStyle(StudioTheme.muted)
            Text("AR uses your table as its anchor. Keep the paper in place.").font(StudioTheme.font(12)).foregroundStyle(StudioTheme.muted)
        }.navigationTitle(drawing.title)
            .sheet(item: $setup) { mode in NavigationStack { ModeSetupView(mode: mode) } }
            .navigationDestination(item: $selected) { mode in
                if mode == .ar { ARTracingWorkspace(drawing: drawing) }
                else { TracingWorkspace(drawing: drawing, mode: mode) }
            }
    }
}

struct ModeSetupView: View {
    let mode: TraceMode
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        StudioPage {
            Text(mode.title).studioTitle()
            LoopVideo(name: mode.rawValue).clipShape(RoundedRectangle(cornerRadius: 22))
            Text(mode.caption).font(StudioTheme.font(21, .bold))
            ForEach(Array(mode.instructions.enumerated()), id: \.offset) { index, instruction in
                HStack(alignment: .top, spacing: 14) { Text("\(index + 1)").font(StudioTheme.font(18, .bold)).foregroundStyle(StudioTheme.coral).frame(width: 30); Text(instruction).font(StudioTheme.font(15)).fixedSize(horizontal: false, vertical: true) }.studioCard()
            }
            StudioButton("Got it") { dismiss() }
        }.navigationTitle("Quick setup")
    }
}

struct TracingWorkspace: View {
    let drawing: Drawing
    let mode: TraceMode
    var existingProjectID: UUID? = nil
    @Environment(StudioLibrary.self) private var library
    @Environment(PurchaseStore.self) private var purchases
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraController()
    @State private var outline: UIImage?
    @State private var cameraOutline: UIImage?
    @State private var opacity = 0.7
    @State private var scale: CGFloat = 0.8
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var locked = false
    @State private var projectID: UUID?
    @State private var oldBrightness: CGFloat?
    @State private var showSaved = false
    @State private var workPhoto: PhotosPickerItem?
    @State private var shareURL: URL?
    @State private var error: String?
    @State private var saving = false
    @State private var showArtworkCamera = false
    @State private var rotation = 0.0
    @State private var mirrored = false
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color.white
                if mode == .camera { CameraPreview(session: camera.session) }
                if let outline {
                    Image(uiImage: mode == .camera ? (cameraOutline ?? outline) : outline).resizable().scaledToFit().scaleEffect(x: mirrored ? -scale : scale, y: scale)
                        .rotationEffect(.degrees(rotation))
                        .offset(offset).opacity(mode == .screen ? 1 : opacity)
                        .gesture(DragGesture().onChanged { value in
                            guard !locked else { return }
                            offset = CGSize(width: lastOffset.width + value.translation.width, height: lastOffset.height + value.translation.height)
                        }.onEnded { _ in lastOffset = offset })
                        .allowsHitTesting(!locked)
                } else { ProgressView("Preparing outline…") }
                if let message = camera.message, mode == .camera {
                    VStack(spacing: 14) {
                        Text(message).multilineTextAlignment(.center)
                        if let url = URL(string: UIApplication.openSettingsURLString) { Link("Open Settings", destination: url) }
                    }.padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20)).padding(24)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .contentShape(Rectangle())
            VStack(spacing: 10) {
                VStack(spacing: 10) {
                    HStack { Text("Size").frame(width: 55, alignment: .leading); Slider(value: $scale, in: 0.25...1.8).accessibilityLabel("Outline size") }
                    if mode == .camera { HStack { Text("Opacity").frame(width: 55, alignment: .leading); Slider(value: $opacity, in: 0.15...1).accessibilityLabel("Outline opacity") } }
                    HStack { Text("Rotate").frame(width: 55, alignment: .leading); Slider(value: $rotation, in: -180...180).accessibilityLabel("Outline rotation") }
                    HStack {
                        Button { mirrored.toggle() } label: { Label("Flip", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right") }
                        Spacer()
                        Button("Reset position") { scale = 0.8; offset = .zero; lastOffset = .zero; rotation = 0; mirrored = false }
                    }.frame(minHeight: 36)
                }
                .opacity(locked ? 0 : 1)
                .allowsHitTesting(!locked)
                .accessibilityHidden(locked)
                HStack {
                    Button { locked.toggle() } label: { Label(locked ? "Unlock" : "Lock outline", systemImage: locked ? "lock.fill" : "lock.open") }.frame(minHeight: 44)
                    Spacer()
                    Button {
                        do { shareURL = try ImageFiles.pdf(for: drawing) } catch { self.error = error.localizedDescription }
                    } label: {
                        Image(systemName: "square.and.arrow.up").frame(width: 44, height: 44)
                    }.accessibilityLabel("Export outline PDF")
                    Button("Finish") { finish() }
                        .font(StudioTheme.font(16, .bold))
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .accessibilityIdentifier("finishDrawing")
                        .disabled(projectID == nil)
                }
                Text(locked ? "Outline locked. Draw gently on your paper." : "Drag to position. Adjust the size, then lock the outline.").font(StudioTheme.font(11)).foregroundStyle(StudioTheme.muted)
            }.font(StudioTheme.font(13)).padding(.horizontal, 24).padding(.vertical, 12).background(StudioTheme.paper)
        }.navigationTitle(mode.title).navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .modifier(ActivityTracking(isActive: projectID != nil && !showSaved && (mode == .screen || camera.isReady)))
            .task {
                projectID = existingProjectID ?? library.startProject(drawing, isPro: purchases.isPro)
                guard projectID != nil else { error = "This drawing requires Pro."; return }
                if let settings = library.state.projects.first(where: { $0.id == projectID })?.traceSettings, settings.mode == mode.rawValue {
                    scale = settings.scale; opacity = settings.opacity
                    offset = CGSize(width: settings.offsetX, height: settings.offsetY); lastOffset = offset
                    rotation = settings.rotation; mirrored = settings.mirrored
                }
                if let source = ImageFiles.source(for: drawing) {
                    let lines = drawing.isOutline ? source : ImageFiles.outline(source, detailed: true)
                    outline = lines; cameraOutline = ImageFiles.transparentOutline(lines)
                }
                else { error = "The drawing file could not be found." }
                UIApplication.shared.isIdleTimerDisabled = true
                if mode == .camera { await camera.start() } else { brighten() }
            }
            .onDisappear { saveSettings(); camera.stop(); restoreScreen() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active && !showSaved {
                    UIApplication.shared.isIdleTimerDisabled = true
                    if mode == .camera { Task { await camera.start() } } else { brighten() }
                } else { saveSettings(); camera.stop(); restoreScreen() }
            }
            .sheet(isPresented: $showSaved) {
                NavigationStack {
                    StudioPage {
                        Text("Made by you.").studioTitle()
                        Text("Your drawing is saved in My Projects. Add a photo of your paper artwork to keep the finished result.").studioCaption()
                        FinishedArtworkControls(showCamera: $showArtworkCamera, selectedPhoto: $workPhoto).disabled(saving)
                        if saving { ProgressView("Saving your photo…") }
                        StudioButton("Back to my studio") { showSaved = false; dismiss() }.disabled(saving)
                    }.navigationTitle("Drawing saved")
                }.presentationDetents([.medium, .large])
                    .fullScreenCover(isPresented: $showArtworkCamera) { ArtworkCamera { image in
                        guard let projectID else { return }
                        do { library.finishProject(projectID, workPhoto: try ImageFiles.save(ImageFiles.normalized(image))) }
                        catch { self.error = error.localizedDescription }
                    } }
            }
            .task(id: workPhoto) {
                guard let workPhoto, let projectID else { return }
                saving = true; defer { saving = false }
                do {
                    guard let data = try await workPhoto.loadTransferable(type: Data.self), let image = UIImage(data: data) else { throw ImageFiles.ImageError.invalidImage }
                    let filename = try ImageFiles.save(ImageFiles.normalized(image))
                    library.finishProject(projectID, workPhoto: filename)
                } catch { self.error = error.localizedDescription }
            }
            .sheet(isPresented: Binding(get: { shareURL != nil }, set: { if !$0 { shareURL = nil } })) { if let shareURL { ShareSheet(items: [shareURL]) } }
            .alert("Trace Studio", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }
    private func finish() { if let projectID { saveSettings(); library.finishProject(projectID); camera.stop(); restoreScreen(); showSaved = true } }
    private func saveSettings() {
        if let projectID { library.saveTraceSettings(TraceSettings(mode: mode.rawValue, scale: scale, offsetX: offset.width, offsetY: offset.height, opacity: opacity, rotation: rotation, mirrored: mirrored), projectID: projectID) }
    }
    private func brighten() { if oldBrightness == nil { oldBrightness = UIScreen.main.brightness }; UIScreen.main.brightness = 1 }
    private func restoreScreen() { UIApplication.shared.isIdleTimerDisabled = false; if let oldBrightness { UIScreen.main.brightness = oldBrightness; self.oldBrightness = nil } }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
