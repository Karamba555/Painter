import SwiftUI
import PhotosUI

struct PhotoCreationView: View {
    @Environment(StudioLibrary.self) private var library
    @Environment(PurchaseStore.self) private var purchases
    @State private var selection: PhotosPickerItem?
    @State private var original: UIImage?
    @State private var preview: UIImage?
    @State private var detailed = false
    @State private var processing = false
    @State private var error: String?
    @State private var drawing: Drawing?
    @State private var showPaywall = false
    var body: some View {
        StudioPage {
            Text("A photo. A new possibility.").studioTitle()
            Text("Choose a photo, then make the outline your own.").studioCaption()
            PhotosPicker(selection: $selection, matching: .images, photoLibrary: .shared()) {
                Group {
                    if let preview { Image(uiImage: preview).resizable().scaledToFit().frame(maxWidth: .infinity).frame(height: 320) }
                    else { VStack(spacing: 16) { StudioIcon(name: "photo", size: 44); Text("Choose a photo").font(StudioTheme.font(18, .bold)); Text("Pets, people, places. Start with what you love.").studioCaption().multilineTextAlignment(.center) }.frame(maxWidth: .infinity).frame(height: 290) }
                }.studioCard(StudioTheme.peach)
            }.buttonStyle(.plain).disabled(processing)
            if original != nil {
                Picker("Outline detail", selection: $detailed) { Text("Simple").tag(false); Text("Detailed").tag(true) }.pickerStyle(.segmented)
                Text("Tip: a clear subject against a simple background works best.").studioCaption()
                StudioButton("Choose how to trace →", isBusy: processing) { createDrawing() }.disabled(preview == nil)
            }
            if processing { ProgressView("Making your outline…").frame(maxWidth: .infinity) }
            if let error { Text(error).foregroundStyle(StudioTheme.coral).font(StudioTheme.font(13)) }
            Text(library.state.freePhotoID == nil ? "Your first photo project is free, including PDF export." : "Your first photo project is saved. New photo projects are included with Pro.").font(StudioTheme.font(12)).foregroundStyle(StudioTheme.muted)
        }.navigationTitle("Use a Photo")
            .task(id: selection) {
                guard let selection else { return }
                processing = true; error = nil
                do {
                    guard let data = try await selection.loadTransferable(type: Data.self), let image = UIImage(data: data) else { throw ImageFiles.ImageError.invalidImage }
                    original = ImageFiles.normalized(image)
                    if let original { preview = ImageFiles.outline(original, detailed: detailed) }
                } catch { self.error = error.localizedDescription }
                processing = false
            }
            .onChange(of: detailed) { _, value in if let original { preview = ImageFiles.outline(original, detailed: value) } }
            .navigationDestination(item: $drawing) { DrawingAccessView(drawing: $0) }
            .sheet(isPresented: $showPaywall) { PaywallView() }
    }
    private func createDrawing() {
        guard library.state.freePhotoID == nil || purchases.isPro else { showPaywall = true; return }
        guard let preview else { return }
        do {
            let file = try ImageFiles.save(preview)
            drawing = Drawing(id: UUID().uuidString, title: "My photo sketch", asset: "", topic: .portraits, difficulty: detailed ? .medium : .easy, minutes: 15, isFree: true, localImage: file)
        } catch { self.error = error.localizedDescription }
    }
}

struct AICreationView: View {
    @State private var prompt = ""
    var body: some View {
        StudioPage {
            StudioIcon(name: "spark", size: 34).foregroundStyle(StudioTheme.green)
            Text("Imagine your next drawing.").studioTitle()
            Text("Describe a subject and a style for your outline.").studioCaption()
            TextField("A sleepy kitten among wildflowers…", text: $prompt, axis: .vertical).lineLimit(4...7).padding(18).background(.white, in: RoundedRectangle(cornerRadius: 20))
            Text("TRY AN IDEA").font(StudioTheme.font(11, .bold)).foregroundStyle(StudioTheme.green)
            ForEach(["A kitten with a tiny flower crown", "A cozy cottage in a wildflower garden", "A manga character with round glasses"], id: \.self) { idea in Button(idea) { prompt = idea }.font(StudioTheme.font(14)).frame(maxWidth: .infinity, alignment: .leading).studioCard(StudioTheme.sage) }
            Label("AI creation is coming soon", systemImage: "sparkles").font(StudioTheme.font(17, .bold))
            Text("The generation service is not connected in this build. You can start from a photo or choose a ready-to-draw template today.").studioCaption()
            NavigationLink("Explore templates →", value: Route.catalog).font(StudioTheme.font(16, .bold)).frame(minHeight: 44)
        }.navigationTitle("Create with AI")
    }
}
