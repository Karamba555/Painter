import SwiftUI

@main
struct PainterApp: App {
    @State private var library = StudioLibrary()
    @State private var purchases = PurchaseStore()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(library).environment(purchases)
                .font(StudioTheme.font(15)).tint(StudioTheme.coral)
                .preferredColorScheme(.light)
                .task { await purchases.load(); await purchases.observeTransactions() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await purchases.refreshEntitlements() } }
                }
        }
    }
}

enum Route: Hashable {
    case catalog, topic(Topic), drawing(Drawing), lesson(String), interests, projects, photo, ai, help
}

struct RootView: View {
    @Environment(StudioLibrary.self) private var library
    var body: some View {
        Group {
            if library.state.hasOnboarded { StudioTabs() }
            else { NavigationStack { WelcomeView().studioDestinations() } }
        }
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--reset-state") { library.reset() }
            #endif
        }
    }
}

struct StudioTabs: View {
    var body: some View {
        TabView {
            NavigationStack { HomeView().studioDestinations() }
                .tabItem { Label("Home", image: "icon-home") }
            NavigationStack { LessonsView().studioDestinations() }
                .tabItem { Label("Lessons", image: "icon-book") }
            NavigationStack { FavoritesView().studioDestinations() }
                .tabItem { Label("Favorites", image: "icon-heart") }
            NavigationStack { ProfileView().studioDestinations() }
                .tabItem { Label("Profile", image: "icon-user") }
        }
    }
}

private struct StudioDestinations: ViewModifier {
    func body(content: Content) -> some View {
        content.navigationDestination(for: Route.self) { route in
            switch route {
            case .catalog: CatalogView()
            case .topic(let topic): CollectionView(topic: topic)
            case .drawing(let drawing): DrawingAccessView(drawing: drawing)
            case .lesson(let id): LessonAccessView(lesson: Catalog.lesson(id))
            case .interests: InterestsView(isOnboarding: false)
            case .projects: ProjectsView()
            case .photo: PhotoCreationView()
            case .ai: AICreationView()
            case .help: HelpView()
            }
        }
        .toolbarBackground(StudioTheme.paper, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
    }
}
extension View { func studioDestinations() -> some View { modifier(StudioDestinations()) } }
