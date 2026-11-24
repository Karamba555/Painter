import Foundation
import Observation

struct SavedProject: Codable, Identifiable, Hashable {
    let id: UUID
    var drawing: Drawing
    var createdAt: Date
    var isComplete: Bool
    var workPhoto: String?
    var traceSettings: TraceSettings?
}

struct TraceSettings: Codable, Hashable {
    var mode: String = "camera"
    var scale: Double = 0.8
    var offsetX: Double = 0
    var offsetY: Double = 0
    var opacity: Double = 0.7
    var rotation: Double = 0
    var mirrored: Bool = false
}

struct StudioState: Codable {
    var hasOnboarded = false
    var interests: Set<Topic> = []
    var favorites: Set<String> = []
    var lessonSteps: [String: Int] = [:]
    var completedLessons: Set<String> = []
    var projects: [SavedProject] = []
    var freePhotoID: String?
    var activeSeconds: Double = 0
    var drawingDays: Set<String> = []

    func canOpen(_ drawing: Drawing, isPro: Bool) -> Bool {
        if drawing.isPhoto { return isPro || freePhotoID == nil || freePhotoID == drawing.id }
        return drawing.isFree || isPro
    }
    var challengeDay: Int { (1...7).first { !completedLessons.contains(Catalog.challenge[$0 - 1].id) } ?? 7 }
    var completedDrawings: Int { projects.filter(\.isComplete).count }
}

@Observable @MainActor
final class StudioLibrary {
    private(set) var state: StudioState
    private(set) var saveError: String?
    @ObservationIgnored private let defaults: UserDefaults
    private static let key = "trace-studio.state.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key), let saved = try? JSONDecoder().decode(StudioState.self, from: data) {
            state = saved
        } else { state = StudioState() }
    }
    func update(_ change: (inout StudioState) -> Void) {
        change(&state)
        do { defaults.set(try JSONEncoder().encode(state), forKey: Self.key); saveError = nil }
        catch { saveError = "Your changes could not be saved. Please try again." }
    }
    func finishOnboarding(interests: Set<Topic>) { update { $0.interests = interests; $0.hasOnboarded = true } }
    func toggleFavorite(_ drawing: Drawing) {
        update { if $0.favorites.contains(drawing.id) { $0.favorites.remove(drawing.id) } else { $0.favorites.insert(drawing.id) } }
    }
    func savedStep(_ lesson: Lesson) -> Int { min(max(state.lessonSteps[lesson.id] ?? 0, 0), lesson.steps.count - 1) }
    func saveStep(_ step: Int, lesson: Lesson) { update { $0.lessonSteps[lesson.id] = min(max(step, 0), lesson.steps.count - 1) } }
    func completeLesson(_ lesson: Lesson) { update { $0.completedLessons.insert(lesson.id); $0.lessonSteps[lesson.id] = lesson.steps.count - 1 } }
    @discardableResult func startProject(_ drawing: Drawing, isPro: Bool) -> UUID? {
        guard state.canOpen(drawing, isPro: isPro) else { return nil }
        if let draft = state.projects.first(where: { $0.drawing.id == drawing.id && !$0.isComplete }) { return draft.id }
        let project = SavedProject(id: UUID(), drawing: drawing, createdAt: .now, isComplete: false)
        update {
            $0.projects.insert(project, at: 0)
            if drawing.isPhoto && !isPro && $0.freePhotoID == nil { $0.freePhotoID = drawing.id }
        }
        return project.id
    }
    func finishProject(_ id: UUID, workPhoto: String? = nil) {
        update { state in
            guard let index = state.projects.firstIndex(where: { $0.id == id }) else { return }
            state.projects[index].isComplete = true
            if let workPhoto { state.projects[index].workPhoto = workPhoto }
        }
    }
    func saveTraceSettings(_ settings: TraceSettings, projectID: UUID) {
        update { state in
            guard let index = state.projects.firstIndex(where: { $0.id == projectID }) else { return }
            state.projects[index].traceSettings = settings
        }
    }
    func renameProject(_ id: UUID, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        update { state in
            guard let index = state.projects.firstIndex(where: { $0.id == id }) else { return }
            let original = state.projects[index].drawing
            state.projects[index].drawing = Drawing(id: original.id, title: String(trimmed.prefix(80)), asset: original.asset, topic: original.topic, difficulty: original.difficulty, minutes: original.minutes, isFree: original.isFree, localImage: original.localImage, origin: original.origin)
        }
    }
    func removeProject(_ id: UUID) { update { $0.projects.removeAll { $0.id == id } } }
    func recordActivity(seconds: Double, date: Date = .now) {
        guard seconds > 0 else { return }
        let day = ISO8601DateFormatter.string(from: Calendar.current.startOfDay(for: date), timeZone: .current, formatOptions: [.withFullDate])
        update { $0.activeSeconds += seconds; $0.drawingDays.insert(day) }
    }
    func reset() { update { $0 = StudioState() } }
}
