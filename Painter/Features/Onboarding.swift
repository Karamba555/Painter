import SwiftUI

struct WelcomeView: View {
    @Environment(StudioLibrary.self) private var library
    var body: some View {
        StudioPage {
            HStack(spacing: 9) { StudioIcon(name: "pencil").foregroundStyle(StudioTheme.coral); Text("trace studio").font(StudioTheme.font(22, .bold)) }
            LoopVideo(name: "welcome", aspectRatio: 1.264).clipShape(RoundedRectangle(cornerRadius: 22))
            Text("Your ideas.\nMade by you.").font(StudioTheme.font(36, .bold)).lineSpacing(-2)
            Text("Look at your phone. Draw on real paper.\nTurn a photo or idea into a drawing,\none line at a time.").studioCaption()
            HStack(spacing: 8) {
                ForEach(Array(["Choose", "Trace", "Color"].enumerated()), id: \.offset) { index, title in
                    HStack(spacing: 7) { Text("\(index + 1)").foregroundStyle(StudioTheme.coral).bold(); Text(title) }.font(StudioTheme.font(13)).studioCard(padding: 11)
                }
            }
            NavigationLink { InterestsView(isOnboarding: true) } label: {
                Text("Personalize my feed").font(StudioTheme.font(16, .bold)).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 18).background(StudioTheme.coral, in: RoundedRectangle(cornerRadius: 18))
            }.accessibilityIdentifier("personalize")
            Button("Skip for now") { library.finishOnboarding(interests: []) }
                .font(StudioTheme.font(14)).foregroundStyle(StudioTheme.muted).frame(maxWidth: .infinity, minHeight: 48).accessibilityIdentifier("skipOnboarding")
            Text("Your first photo project is free. No card needed.").font(StudioTheme.font(12)).foregroundStyle(StudioTheme.muted).frame(maxWidth: .infinity).multilineTextAlignment(.center)
        }.toolbar(.hidden, for: .navigationBar)
    }
}

struct InterestsView: View {
    let isOnboarding: Bool
    @Environment(StudioLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<Topic> = []
    var body: some View {
        StudioPage {
            HStack {
                Text("MAKE IT YOURS").font(StudioTheme.font(11, .bold)).foregroundStyle(StudioTheme.coral)
                Spacer()
                if isOnboarding { Button("Skip") { library.finishOnboarding(interests: []) }.foregroundStyle(StudioTheme.muted).frame(minHeight: 44) }
            }
            Text("What would you\nlike to draw?").studioTitle()
            Text("Choose as many as you like. Or skip this step.").studioCaption()
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Topic.allCases.filter { $0 != .relax }) { topic in topicCard(topic) }
            }
            topicCard(.relax, horizontal: true)
            StudioButton(isOnboarding ? "Show my feed →" : "Save interests") {
                if isOnboarding { library.finishOnboarding(interests: selected) }
                else { library.update { $0.interests = selected }; dismiss() }
            }.accessibilityIdentifier("saveInterests")
            Text("Change your interests anytime in Profile.").font(StudioTheme.font(12)).foregroundStyle(StudioTheme.muted)
        }.onAppear { selected = library.state.interests }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(isOnboarding ? .hidden : .visible, for: .navigationBar)
    }
    private func topicCard(_ topic: Topic, horizontal: Bool = false) -> some View {
        Button {
            if selected.contains(topic) { selected.remove(topic) } else { selected.insert(topic) }
        } label: {
            Group {
                if horizontal {
                    HStack(alignment: .top, spacing: 16) {
                        Image(topic.artwork).resizable().scaledToFill().frame(width: 82, height: 82).clipShape(RoundedRectangle(cornerRadius: 18))
                        VStack(alignment: .leading, spacing: 4) { Text(topic.title).font(StudioTheme.font(14, .bold)); Text(topic.subtitle).font(StudioTheme.font(12)).foregroundStyle(StudioTheme.muted) }
                        Spacer(minLength: 0)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Image(topic.artwork).resizable().scaledToFill().frame(height: 102).frame(maxWidth: .infinity).clipped().clipShape(RoundedRectangle(cornerRadius: 18))
                        Text(topic.title).font(StudioTheme.font(14, .bold)).lineLimit(2)
                    }
                }
            }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                .background(selected.contains(topic) ? StudioTheme.peach : .white, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(selected.contains(topic) ? StudioTheme.coral : .clear, lineWidth: 1.5))
                .overlay(alignment: .topTrailing) {
                    if selected.contains(topic) { Image(systemName: "checkmark.circle.fill").foregroundStyle(.white, StudioTheme.coral).padding(10) }
                }
        }.buttonStyle(.plain).accessibilityLabel(topic.title).accessibilityAddTraits(selected.contains(topic) ? .isSelected : [])
    }
}
