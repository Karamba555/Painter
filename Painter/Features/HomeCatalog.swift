import SwiftUI

struct HomeView: View {
    @Environment(StudioLibrary.self) private var library
    @State private var showPaywall = false
    @State private var showCatalog = false
    @State private var editInterests = false
    private var lesson: Lesson { Catalog.challenge[library.state.challengeDay - 1] }
    var body: some View {
        StudioPage {
            HStack {
                Text("trace studio").font(StudioTheme.font(25, .bold))
                Spacer()
                Button { showPaywall = true } label: { Badge(text: "✦ PRO", color: StudioTheme.coral, background: StudioTheme.peach) }.frame(minHeight: 44)
            }
            Text("What will you make today?").studioCaption()
            HStack(spacing: 12) {
                createCard("Use a Photo", subtitle: "Your photo, a new sketch", icon: "photo", color: StudioTheme.peach, route: .photo)
                createCard("Create with AI", subtitle: "An idea becomes art", icon: "spark", color: StudioTheme.sage, route: .ai)
            }
            NavigationLink(value: Route.lesson(lesson.id)) { ChallengeBanner(lesson: lesson) }.buttonStyle(.plain)
            SectionHeading(title: "Trending", actionTitle: "Explore") { showCatalog = true }
            HStack(spacing: 12) {
                collectionPreview("Pet Portraits", asset: "pet", topic: .animals)
                collectionPreview("Botanical calm", asset: "flowers", topic: .flowers)
            }
            SectionHeading(title: "For You", actionTitle: "Edit interests") { editInterests = true }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(library.state.interests.isEmpty ? [.flowers, .manga, .relax] : Topic.allCases.filter { library.state.interests.contains($0) }) { topic in
                        NavigationLink(value: Route.topic(topic)) { Badge(text: topic.title + " ↗", color: StudioTheme.ink, background: topic == .manga ? StudioTheme.lavender : StudioTheme.peach) }.frame(minHeight: 44)
                    }
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(Array(Catalog.feed(interests: library.state.interests).prefix(3))) { drawing in
                    NavigationLink(value: Route.drawing(drawing)) {
                        VStack(alignment: .leading, spacing: 7) {
                            Artwork(drawing: drawing).frame(height: 104).clipped().clipShape(RoundedRectangle(cornerRadius: 18))
                            Text(drawing.title).font(StudioTheme.font(11)).lineLimit(2)
                        }
                    }.buttonStyle(.plain)
                }
            }
        }.toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .navigationDestination(isPresented: $showCatalog) { CatalogView() }
            .navigationDestination(isPresented: $editInterests) { InterestsView(isOnboarding: false) }
    }
    private func createCard(_ title: String, subtitle: String, icon: String, color: Color, route: Route) -> some View {
        NavigationLink(value: route) {
            VStack(alignment: .leading, spacing: 9) {
                StudioIcon(name: icon).foregroundStyle(icon == "photo" ? StudioTheme.coral : StudioTheme.green)
                Text(title).font(StudioTheme.font(17, .bold))
                Text(subtitle).font(StudioTheme.font(11)).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, alignment: .leading).studioCard(color)
        }.buttonStyle(.plain)
    }
    private func collectionPreview(_ title: String, asset: String, topic: Topic) -> some View {
        NavigationLink(value: Route.topic(topic)) {
            VStack(alignment: .leading, spacing: 6) {
                Image(asset).resizable().scaledToFill().frame(height: 104).clipped().clipShape(RoundedRectangle(cornerRadius: 18))
                Text(title).font(StudioTheme.font(14, .bold))
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.buttonStyle(.plain)
    }
}

struct ChallengeBanner: View {
    let lesson: Lesson
    @Environment(StudioLibrary.self) private var library
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text("A LITTLE EVERY DAY"); Spacer(); Text("DAY \(lesson.day ?? 1) / 7") }.font(StudioTheme.font(10, .medium))
            Text("7-Day Drawing Challenge").font(StudioTheme.font(20, .bold))
            HStack {
                ForEach(1...7, id: \.self) { day in Capsule().fill(day <= (lesson.day ?? 1) ? StudioTheme.peach : Color.white.opacity(0.3)).frame(width: 12, height: 6) }
                Spacer(minLength: 4)
                Text(actionTitle + " →").font(StudioTheme.font(12, .bold))
            }
        }.foregroundStyle(.white).studioCard(StudioTheme.ink)
    }
    private var actionTitle: String {
        if library.state.completedLessons.contains(lesson.id) { return "Review Day \(lesson.day ?? 1)" }
        return (library.state.lessonSteps[lesson.id] == nil ? "Start" : "Continue") + " Day \(lesson.day ?? 1)"
    }
}

struct CatalogView: View {
    var body: some View {
        StudioPage {
            Text("Find your next drawing.").studioTitle()
            Text("Something for every kind of maker. Each collection has a free drawing.").studioCaption()
            ForEach(Topic.allCases) { topic in
                NavigationLink(value: Route.topic(topic)) {
                    HStack(spacing: 16) {
                        Image(topic.artwork).resizable().scaledToFill().frame(width: 86, height: 86).clipShape(RoundedRectangle(cornerRadius: 16))
                        VStack(alignment: .leading, spacing: 6) { Text(topic.title).font(StudioTheme.font(19, .bold)); Text(topic.subtitle).studioCaption() }
                        Spacer(minLength: 0); Image(systemName: "chevron.right")
                    }.studioCard(padding: 10)
                }.buttonStyle(.plain)
            }
        }.navigationTitle("Collections")
    }
}

struct CollectionView: View {
    let topic: Topic
    @State private var difficulty: Difficulty?
    private var drawings: [Drawing] { Catalog.drawings.filter { $0.topic == topic && (difficulty == nil || $0.difficulty == difficulty) } }
    var body: some View {
        StudioPage {
            Text(topic.title).studioTitle()
            Text(topic.subtitle).studioCaption()
            DifficultyFilter(selection: $difficulty)
            if drawings.isEmpty { ContentUnavailableView("More drawings soon", systemImage: "pencil.tip.crop.circle", description: Text("Try another difficulty to find your next drawing.")) }
            DrawingGrid(drawings: drawings)
            Label("Try a free drawing in all 3 tracing modes. AR needs a supported device.", systemImage: "checkmark").font(StudioTheme.font(12)).foregroundStyle(StudioTheme.green).studioCard(StudioTheme.sage)
        }.navigationTitle("Collections")
    }
}

struct DrawingGrid: View {
    let drawings: [Drawing]
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 14) {
            ForEach(drawings) { DrawingCard(drawing: $0) }
        }
    }
}

struct DrawingCard: View {
    let drawing: Drawing
    @Environment(StudioLibrary.self) private var library
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink(value: Route.drawing(drawing)) {
                Artwork(drawing: drawing).frame(height: 156).clipped().clipShape(RoundedRectangle(cornerRadius: 18))
            }.buttonStyle(.plain)
                .overlay(alignment: .topLeading) { Badge(text: drawing.isFree ? "FREE" : "PRO", color: drawing.isFree ? StudioTheme.green : .white, background: drawing.isFree ? StudioTheme.sage : StudioTheme.ink).padding(9).allowsHitTesting(false) }
                .overlay(alignment: .topTrailing) {
                    Button { library.toggleFavorite(drawing) } label: {
                        Image(systemName: library.state.favorites.contains(drawing.id) ? "heart.fill" : "heart")
                            .foregroundStyle(library.state.favorites.contains(drawing.id) ? StudioTheme.coral : StudioTheme.ink)
                            .frame(width: 44, height: 44).background(.white.opacity(0.65), in: Circle())
                    }.accessibilityLabel(library.state.favorites.contains(drawing.id) ? "Remove \(drawing.title) from favorites" : "Save \(drawing.title) to favorites")
                }
            NavigationLink(value: Route.drawing(drawing)) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(drawing.title).font(StudioTheme.font(14, .bold))
                    Text("\(drawing.difficulty.rawValue) · \(drawing.minutes) min").font(StudioTheme.font(11)).foregroundStyle(StudioTheme.muted)
                }.padding(13).frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.plain)
        }.background(.white, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct FavoritesView: View {
    var isRoot = true
    @Environment(StudioLibrary.self) private var library
    private var drawings: [Drawing] { Catalog.drawings.filter { library.state.favorites.contains($0.id) } }
    var body: some View {
        StudioPage {
            Text("Your favorites.").studioTitle()
            Text("A little inspiration, saved for later.").studioCaption()
            if drawings.isEmpty {
                ContentUnavailableView("Make room for inspiration", systemImage: "heart", description: Text("Tap the heart on any drawing to keep it here."))
                NavigationLink("Explore drawings", value: Route.catalog).buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
            } else { DrawingGrid(drawings: drawings) }
        }.toolbar(isRoot ? .hidden : .visible, for: .navigationBar)
    }
}
