import SwiftUI

struct LessonsView: View {
    @Environment(StudioLibrary.self) private var library
    @State private var difficulty: Difficulty?
    private var current: Lesson { Catalog.challenge[library.state.challengeDay - 1] }
    var body: some View {
        StudioPage {
            Text("Learn to draw.").studioTitle()
            Text("One drawing at a time. At your pace.").studioCaption()
            VStack(alignment: .leading, spacing: 12) {
                Text("7-Day Drawing Challenge").font(StudioTheme.font(21, .bold))
                HStack(spacing: 6) {
                    ForEach(Catalog.challenge) { lesson in
                        NavigationLink(value: Route.lesson(lesson.id)) {
                            Text(library.state.completedLessons.contains(lesson.id) ? "✓" : "\(lesson.day ?? 1)")
                                .font(StudioTheme.font(13, .bold)).frame(maxWidth: .infinity, minHeight: 40)
                                .foregroundStyle(lesson.id == current.id ? .white : StudioTheme.muted)
                                .background(lesson.id == current.id ? StudioTheme.green : .white, in: Circle())
                        }.accessibilityLabel("Day \(lesson.day ?? 1)" + (lesson.isFree ? ", free" : ", Pro"))
                    }
                }
                NavigationLink(value: Route.lesson(current.id)) {
                    Text(challengeAction).font(StudioTheme.font(16, .bold)).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 18).background(StudioTheme.green, in: RoundedRectangle(cornerRadius: 18))
                }
                Text("\(progressText)\nDay 1 is free · Days 2–7 are Pro").font(StudioTheme.font(12)).foregroundStyle(StudioTheme.green)
            }.studioCard(StudioTheme.sage, padding: 18)
            Text("Find your next lesson").font(StudioTheme.font(21, .bold))
            DifficultyFilter(selection: $difficulty)
            ForEach(Catalog.lessons.filter { difficulty == nil || $0.difficulty == difficulty }) { lesson in
                NavigationLink(value: Route.lesson(lesson.id)) { LessonRow(lesson: lesson) }.buttonStyle(.plain)
            }
        }.toolbar(.hidden, for: .navigationBar)
    }
    private var challengeAction: String {
        let verb = library.state.completedLessons.contains(current.id) ? "Review" : library.state.lessonSteps[current.id] == nil ? "Start" : "Continue"
        return "\(verb) Day \(current.day ?? 1) →"
    }
    private var progressText: String {
        library.state.lessonSteps[current.id] == nil ? "A few minutes. A little more confidence." : "Step \(library.savedStep(current) + 1) of \(current.steps.count) · your place is saved"
    }
}

struct LessonRow: View {
    let lesson: Lesson
    var body: some View {
        HStack(spacing: 14) {
            Artwork(drawing: lesson.drawing).frame(width: 76, height: 76).clipped().clipShape(RoundedRectangle(cornerRadius: 18))
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(lesson.difficulty.rawValue.uppercased() + (lesson.day == 1 ? " · DAY 1" : "")).font(StudioTheme.font(10, .bold)).foregroundStyle(StudioTheme.muted)
                    Badge(text: lesson.isFree ? "FREE" : "PRO")
                }
                Text(lesson.title).font(StudioTheme.font(15, .bold))
                Text("\(lesson.minutes) min · \(lesson.steps.count) steps · full lesson").font(StudioTheme.font(11)).foregroundStyle(StudioTheme.muted)
            }
            Spacer(minLength: 0)
        }.studioCard(padding: 12)
    }
}

struct LessonAccessView: View {
    let lesson: Lesson
    @Environment(PurchaseStore.self) private var purchases
    var body: some View {
        if lesson.isFree || purchases.isPro { LessonDetailView(lesson: lesson) }
        else { PaywallView(isPushed: true) }
    }
}

struct LessonDetailView: View {
    let lesson: Lesson
    @Environment(StudioLibrary.self) private var library
    @State private var step = 0
    @State private var complete = false
    var body: some View {
        StudioPage {
            HStack { Badge(text: lesson.difficulty.rawValue.uppercased()); Spacer(); Text("Step \(step + 1) of \(lesson.steps.count)").font(StudioTheme.font(13, .semibold)).accessibilityIdentifier("lessonStep") }
            Text(lesson.title).studioTitle()
            ProgressView(value: Double(step + 1), total: Double(lesson.steps.count)).tint(StudioTheme.green)
            Artwork(drawing: lesson.drawing).frame(height: 280).clipped().clipShape(RoundedRectangle(cornerRadius: 24))
            Text("YOUR NEXT LINE").font(StudioTheme.font(11, .bold)).foregroundStyle(StudioTheme.coral)
            Text(lesson.steps[step]).font(StudioTheme.font(19, .medium)).fixedSize(horizontal: false, vertical: true)
            Text("Take your time. Your place is saved automatically.").studioCaption()
            StudioButton(step == lesson.steps.count - 1 ? "Finish lesson" : "Next step →", color: StudioTheme.green) {
                if step == lesson.steps.count - 1 { library.completeLesson(lesson); complete = true }
                else { step += 1; library.saveStep(step, lesson: lesson) }
            }.accessibilityIdentifier("nextLessonStep")
            Button("Previous step") { step = max(step - 1, 0); library.saveStep(step, lesson: lesson) }.disabled(step == 0).frame(maxWidth: .infinity, minHeight: 44)
            NavigationLink("Trace this drawing", value: Route.drawing(lesson.drawing)).font(StudioTheme.font(15, .bold)).frame(maxWidth: .infinity, minHeight: 44)
        }.navigationTitle(lesson.day.map { "Day \($0)" } ?? "Lesson")
            .onAppear { step = library.savedStep(lesson); library.saveStep(step, lesson: lesson) }
            .modifier(ActivityTracking())
            .alert("A little more confident.", isPresented: $complete) { Button("Keep creating", role: .cancel) {} } message: { Text("Lesson complete. Your progress is saved in Your Studio.") }
    }
}

struct ActivityTracking: ViewModifier {
    var isActive = true
    @Environment(StudioLibrary.self) private var library
    @Environment(\.scenePhase) private var scenePhase
    @State private var started: Date?
    func body(content: Content) -> some View {
        content.onAppear { if scenePhase == .active && isActive { started = .now } }
            .onDisappear { pause() }
            .onChange(of: isActive) { _, active in
                if active && scenePhase == .active { started = .now } else { pause() }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active && isActive { started = .now } else { pause() }
            }
    }
    private func pause() {
        if let started { library.recordActivity(seconds: Date.now.timeIntervalSince(started)) }
        started = nil
    }
}
