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
    @Environment(PurchaseStore.self) private var purchases
    @State private var prompt = ""
    @State private var detailed = false
    @State private var generating = false
    @State private var image: UIImage?
    @State private var requestID = UUID()
    @State private var remaining: Int?
    @State private var limit: Int?
    @State private var error: String?
    @State private var showPaywall = false
    @State private var drawing: Drawing?
    var body: some View {
        StudioPage {
            StudioIcon(name: "spark", size: 34).foregroundStyle(StudioTheme.green)
            Text("Imagine your next drawing.").studioTitle()
            Text("Describe a subject and a style for your outline.").studioCaption()
            TextField("A sleepy kitten among wildflowers…", text: $prompt, axis: .vertical).lineLimit(4...7).padding(18).background(.white, in: RoundedRectangle(cornerRadius: 20)).disabled(generating)
            Picker("Line detail", selection: $detailed) { Text("Simple").tag(false); Text("Detailed").tag(true) }.pickerStyle(.segmented).disabled(generating)
            Text("TRY AN IDEA").font(StudioTheme.font(11, .bold)).foregroundStyle(StudioTheme.green)
            ForEach(["A kitten with a tiny flower crown", "A cozy cottage in a wildflower garden", "A manga character with round glasses"], id: \.self) { idea in Button(idea) { prompt = idea }.font(StudioTheme.font(14)).frame(maxWidth: .infinity, alignment: .leading).studioCard(StudioTheme.sage).disabled(generating) }
            if let image {
                Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: 22))
                StudioButton("Trace this drawing →") { useImage(image) }
            }
            if AIConfiguration.baseURL != nil {
                StudioButton(generating ? "Creating your drawing…" : image == nil ? "Create my drawing ✦" : "Create another version ✦", color: StudioTheme.green, isBusy: generating) { Task { await generate() } }
                    .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 || prompt.count > 1000)
                if let remaining, let limit { Text("\(remaining) of \(limit) generations available in your 7-day allowance.").font(StudioTheme.font(12)).foregroundStyle(StudioTheme.muted) }
                Text("Your description is sent to OpenAI to create your drawing. Your photos stay on this device.").font(StudioTheme.font(12)).foregroundStyle(StudioTheme.muted)
            } else {
                Label("AI service isn’t connected yet", systemImage: "sparkles").font(StudioTheme.font(17, .bold))
                Text("You can use a photo or start from a ready-to-draw template while AI creation is being connected.").studioCaption()
                NavigationLink("Explore templates →", value: Route.catalog).font(StudioTheme.font(16, .bold)).frame(minHeight: 44)
            }
            if let error { Text(error).font(StudioTheme.font(13)).foregroundStyle(StudioTheme.coral) }
        }.navigationTitle("Create with AI")
            .onChange(of: prompt) { _, _ in requestID = UUID(); image = nil; error = nil }
            .onChange(of: detailed) { _, _ in requestID = UUID(); image = nil; error = nil }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .navigationDestination(item: $drawing) { DrawingAccessView(drawing: $0) }
    }
    private func generate() async {
        guard purchases.isPro else { showPaywall = true; return }
        guard let url = AIConfiguration.baseURL else { return }
        generating = true; error = nil; defer { generating = false }
        guard let transaction = await purchases.signedEntitlement() else { error = "Restore your Pro purchase, then try again."; return }
        do {
            let result = try await AIClient(baseURL: url).generate(prompt: prompt.trimmingCharacters(in: .whitespacesAndNewlines), detailed: detailed, requestID: requestID, signedTransaction: transaction)
            guard let data = Data(base64Encoded: result.imageBase64), let generated = UIImage(data: data) else { throw ImageFiles.ImageError.invalidImage }
            image = ImageFiles.normalized(generated)
            remaining = result.remaining; limit = result.limit
            requestID = UUID()
        } catch { self.error = error.localizedDescription }
    }
    private func useImage(_ image: UIImage) {
        do {
            drawing = Drawing(id: UUID().uuidString, title: String(prompt.prefix(60)), asset: "", topic: .manga, difficulty: detailed ? .medium : .easy, minutes: 15, isFree: false, localImage: try ImageFiles.save(image), origin: "ai")
        } catch { self.error = error.localizedDescription }
    }
}
