import SwiftUI

struct PaywallView: View {
    var isPushed = false
    @Environment(\.dismiss) private var dismiss
    @Environment(PurchaseStore.self) private var purchases
    @State private var policy: Policy?
    enum Policy: String, Identifiable { case terms, privacy; var id: String { rawValue } }
    var body: some View {
        StudioPage {
            HStack {
                Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 20)).foregroundStyle(StudioTheme.muted).frame(width: 44, height: 44) }.accessibilityLabel("Close paywall")
                Spacer()
                Button("Restore purchases") { Task { await purchases.restore() } }.font(StudioTheme.font(12)).foregroundStyle(StudioTheme.muted).frame(minHeight: 44)
            }
            HStack(spacing: -8) {
                Image("pet").resizable().scaledToFit().rotationEffect(.degrees(-7))
                Image("flowers").resizable().scaledToFit()
                Image("flower-girl").resizable().scaledToFit().rotationEffect(.degrees(7))
            }.frame(height: 166).padding(.horizontal, 8).background(StudioTheme.peach, in: RoundedRectangle(cornerRadius: 24)).clipped()
            Badge(text: "TRACE STUDIO PRO", color: StudioTheme.coral, background: StudioTheme.peach)
            Text("Make room for\nevery idea.").font(StudioTheme.font(34, .bold))
            Text("Your next favorite drawing starts here.").studioCaption()
            VStack(alignment: .leading, spacing: 12) {
                benefit("Turn more of your photos into drawings")
                if AIConfiguration.baseURL != nil { benefit("Create with AI · generation limits apply") }
                benefit("Every template. Every lesson.")
                benefit("Save your art & export printable PDFs")
            }
            if AIConfiguration.baseURL == nil { Text("AI creation will be available when the service is connected.").font(StudioTheme.font(12)).foregroundStyle(StudioTheme.muted) }
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) { Text(purchases.price).font(StudioTheme.font(32, .bold)); Text("/ week").studioCaption() }
                Text("Weekly subscription · Cancel anytime").font(StudioTheme.font(12)).foregroundStyle(StudioTheme.muted)
            }.frame(maxWidth: .infinity, alignment: .leading).studioCard()
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(StudioTheme.coral, lineWidth: 1.3))
            StudioButton("Subscribe for \(purchases.price) / week", isBusy: purchases.isBusy) { Task { await purchases.purchase(); if purchases.isPro { dismiss() } } }.accessibilityIdentifier("subscribe")
            Text("Payment is charged at confirmation. Renews automatically at \(purchases.price)/week unless canceled at least 24 hours before the current period ends. Manage in App Store settings.")
                .font(StudioTheme.font(10)).foregroundStyle(StudioTheme.muted).multilineTextAlignment(.center).padding(.horizontal, 12)
            HStack(spacing: 28) {
                Button("Terms of Use") { policy = .terms }
                Button("Privacy Policy") { policy = .privacy }
            }.font(StudioTheme.font(11)).foregroundStyle(StudioTheme.muted).frame(maxWidth: .infinity, minHeight: 44)
        }.toolbar(isPushed ? .visible : .hidden, for: .navigationBar)
            .task { await purchases.load() }
            .sheet(item: $policy) { PolicyView(policy: $0) }
            .alert("Trace Studio Pro", isPresented: Binding(get: { purchases.message != nil }, set: { if !$0 { purchases.message = nil } })) { Button("OK") { purchases.message = nil } } message: { Text(purchases.message ?? "") }
    }
    private func benefit(_ text: String) -> some View { HStack(alignment: .top, spacing: 12) { Image(systemName: "checkmark").foregroundStyle(StudioTheme.green); Text(text).font(StudioTheme.font(13)) } }
}

struct PolicyView: View {
    let policy: PaywallView.Policy
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                if policy == .terms {
                    Section("Development build") { Text("This build is for evaluating the Trace Studio interface. Subscription testing uses Apple’s StoreKit test environment when the local configuration is enabled. Production subscription availability depends on App Store Connect setup.") }
                    Section("Apple’s standard license") { Link("Read Apple’s Standard EULA", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) }
                } else {
                    Section("Data on your device") { Text("Your interests, favorites, lesson progress, active drawing time, imported images and projects are stored locally on this device. This build does not upload your photos or use analytics or advertising SDKs.") }
                    Section("Camera & photos") { Text("Camera frames are used for the live tracing preview and are not uploaded. The photo picker shares only images you select. Exporting uses the iOS share sheet.") }
                    Section("AI creation") { Text("When an AI service is configured and you request a drawing, your text description is sent to our backend and OpenAI. Your subscription transaction is verified with Apple. The backend keeps request identifiers, a hashed subscription identifier, usage counts and generated images for up to 30 days to enforce limits and safely retry requests. Imported photos are not sent to the AI service.") }
                    Section("Purchases") { Text("Apple processes purchases. This app checks verified StoreKit transactions to determine access to Pro features.") }
                    Section("Before release") { Text("A published privacy policy and support contact must be configured before this app is released to customers.") }
                }
            }.navigationTitle(policy == .terms ? "Terms of Use" : "Privacy")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
