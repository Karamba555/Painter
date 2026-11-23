import SwiftUI
import StoreKit

struct ProfileView: View {
    @Environment(StudioLibrary.self) private var library
    @Environment(PurchaseStore.self) private var purchases
    @State private var showPaywall = false
    @State private var manageSubscription = false
    var body: some View {
        StudioPage {
            Text("Your studio").studioTitle()
            HStack(spacing: 14) {
                StudioIcon(name: "pencil").foregroundStyle(StudioTheme.coral).padding(15).background(StudioTheme.peach, in: Circle())
                VStack(alignment: .leading, spacing: 5) { Text("Hello, maker.").font(StudioTheme.font(21, .bold)); Text("Your creative space, at your pace.").font(StudioTheme.font(12)).foregroundStyle(StudioTheme.muted) }
            }.frame(maxWidth: .infinity, alignment: .leading).studioCard()
            Text("Your Progress").font(StudioTheme.font(21, .bold))
            HStack(spacing: 10) {
                stat("\(library.state.completedDrawings)", "Drawings")
                stat("\(library.state.completedLessons.count)", "Lessons")
                stat("\(Int(library.state.activeSeconds / 60)) min", "Active time")
            }
            Text("Small wins, real progress").font(StudioTheme.font(18, .bold))
            HStack(alignment: .top, spacing: 10) {
                achievement("First Drawing", value: library.state.completedDrawings, target: 1, unit: "drawings", color: StudioTheme.sage)
                achievement("3 Lessons", value: library.state.completedLessons.count, target: 3, unit: "lessons", color: StudioTheme.peach)
                achievement("7 Drawing Days", value: library.state.drawingDays.count, target: 7, unit: "days", color: StudioTheme.lavender)
            }
            HStack { Text("My Projects").font(StudioTheme.font(21, .bold)); Spacer(); NavigationLink("View all", value: Route.projects).font(StudioTheme.font(12, .semibold)).frame(minHeight: 44) }
            if library.state.projects.isEmpty {
                VStack(alignment: .leading, spacing: 8) { Text("Your next idea belongs here.").font(StudioTheme.font(16, .bold)); Text("Start a drawing, then save your finished work.").studioCaption(); NavigationLink("Find a drawing →", value: Route.catalog).font(StudioTheme.font(14, .semibold)) }.frame(maxWidth: .infinity, alignment: .leading).studioCard()
            } else {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(Array(library.state.projects.prefix(3))) { project in
                        NavigationLink(value: Route.drawing(project.drawing)) { ProjectThumbnail(project: project) }.buttonStyle(.plain)
                    }
                }
            }
            VStack(spacing: 0) {
                NavigationLink(value: Route.interests) { settingsRow("Drawing interests", detail: "Make your feed your own", icon: "spark") }
                Divider().padding(.leading, 48)
                Button { purchases.isPro ? (manageSubscription = true) : (showPaywall = true) } label: { settingsRow(purchases.isPro ? "Manage subscription" : "Get Trace Studio Pro", detail: purchases.isPro ? "Your Pro membership" : "Make room for every idea", icon: "pencil") }
                Divider().padding(.leading, 48)
                Button { Task { await purchases.restore() } } label: { settingsRow("Restore purchases", detail: "Already a member?", icon: "user") }
                Divider().padding(.leading, 48)
                NavigationLink(value: Route.help) { settingsRow("Help & support", detail: "A little guidance", icon: "book") }
            }.buttonStyle(.plain).studioCard(padding: 12)
        }.toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .manageSubscriptionsSheet(isPresented: $manageSubscription)
            .alert("Purchases", isPresented: Binding(get: { purchases.message != nil && !showPaywall }, set: { if !$0 { purchases.message = nil } })) { Button("OK") { purchases.message = nil } } message: { Text(purchases.message ?? "") }
    }
    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) { Text(value).font(StudioTheme.font(23, .bold)).foregroundStyle(StudioTheme.green).minimumScaleFactor(0.7).lineLimit(1); Text(label).font(StudioTheme.font(11)).foregroundStyle(StudioTheme.muted) }.frame(maxWidth: .infinity, alignment: .leading).studioCard(padding: 13)
    }
    private func achievement(_ title: String, value: Int, target: Int, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(value >= target ? "✓" : "\(target)").font(StudioTheme.font(24, .bold)).foregroundStyle(StudioTheme.green)
            Text(title).font(StudioTheme.font(12, .bold)).fixedSize(horizontal: false, vertical: true)
            Text("\(min(value, target)) / \(target) \(value >= target ? "· earned" : unit)").font(StudioTheme.font(10)).foregroundStyle(StudioTheme.muted)
        }.frame(maxWidth: .infinity, alignment: .leading).studioCard(color, padding: 11)
    }
    private func settingsRow(_ title: String, detail: String, icon: String) -> some View {
        HStack(spacing: 12) { StudioIcon(name: icon); VStack(alignment: .leading, spacing: 4) { Text(title).font(StudioTheme.font(15)); Text(detail).font(StudioTheme.font(11)).foregroundStyle(StudioTheme.muted) }; Spacer(); Image(systemName: "arrow.right").foregroundStyle(StudioTheme.muted) }.padding(.vertical, 12).foregroundStyle(StudioTheme.ink)
    }
}

struct ProjectThumbnail: View {
    let project: SavedProject
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Group {
                if let photo = project.workPhoto, let image = ImageFiles.load(photo) { Image(uiImage: image).resizable().scaledToFill() }
                else { Artwork(drawing: project.drawing) }
            }.frame(height: 110).clipped().clipShape(RoundedRectangle(cornerRadius: 18))
            Text(project.drawing.title).font(StudioTheme.font(11))
            Text(project.isComplete ? "Finished" : "In progress").font(StudioTheme.font(10)).foregroundStyle(StudioTheme.muted)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ProjectsView: View {
    @Environment(StudioLibrary.self) private var library
    var body: some View {
        StudioPage {
            Text("Made by you.").studioTitle()
            if library.state.projects.isEmpty { ContentUnavailableView("Your studio is ready", systemImage: "pencil.tip", description: Text("Your drawings will appear here when you start a project.")) }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                ForEach(library.state.projects) { project in NavigationLink(value: Route.drawing(project.drawing)) { ProjectThumbnail(project: project) }.buttonStyle(.plain) }
            }
        }.navigationTitle("My Projects")
    }
}

struct HelpView: View {
    var body: some View {
        List {
            Section("Start with what you have") { Text("A phone, paper and a pencil are all you need. For Camera Trace, use a stable glass to hold your phone above the paper.") }
            ForEach(TraceMode.allCases) { mode in Section(mode.title) { ForEach(mode.instructions, id: \.self) { Text($0) } } }
            Section("Your work") { Text("Interests, favorites, lesson progress and projects are saved on this device. Removing the app removes this local data. Export any drawings you want to keep.") }
            Section("Subscription") { Text("You can manage or cancel your subscription in Settings → Apple Account → Subscriptions. Restore purchases uses the Apple Account signed in to the App Store.") }
        }.navigationTitle("A little guidance")
    }
}
