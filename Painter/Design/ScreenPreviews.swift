#if DEBUG
import SwiftUI

private struct ScreenPreview<Content: View>: View {
    @State private var library = StudioLibrary(defaults: UserDefaults(suiteName: "studio.preview." + UUID().uuidString)!)
    @State private var purchases = PurchaseStore()
    @ViewBuilder var content: Content
    var body: some View {
        NavigationStack { content.studioDestinations() }
            .environment(library).environment(purchases)
            .font(StudioTheme.font(15)).tint(StudioTheme.coral).preferredColorScheme(.light)
    }
}

#Preview("Welcome") { ScreenPreview { WelcomeView() } }
#Preview("Interests") { ScreenPreview { InterestsView(isOnboarding: true) } }
#Preview("Home") { ScreenPreview { HomeView() } }
#Preview("Manga") { ScreenPreview { CollectionView(topic: .manga) } }
#Preview("Lessons") { ScreenPreview { LessonsView() } }
#Preview("Modes") { ScreenPreview { ModeChooserView(drawing: Catalog.drawings[0]) } }
#Preview("Profile") { ScreenPreview { ProfileView() } }
#Preview("Paywall") { ScreenPreview { PaywallView() } }
#endif
