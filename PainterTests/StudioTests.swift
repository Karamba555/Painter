import XCTest
@testable import Painter

final class StudioTests: XCTestCase {
    func testDefaultFeedAndPersonalization() {
        XCTAssertEqual(Array(Catalog.feed(interests: []).prefix(3)).map(\.topic), [.flowers, .manga, .relax])
        XCTAssertEqual(Array(Catalog.feed(interests: [.animals, .portraits]).prefix(2)).map(\.topic), [.animals, .portraits])
        XCTAssertEqual(Set(Catalog.feed(interests: [.animals]).map(\.id)).count, Catalog.drawings.count)
    }
    func testEveryTopicAndDifficultyHasFreeContent() {
        for topic in Topic.allCases { XCTAssertTrue(Catalog.drawings.contains { $0.topic == topic && $0.isFree }) }
        for level in Difficulty.allCases { XCTAssertTrue(Catalog.lessons.contains { $0.difficulty == level && $0.isFree }) }
        XCTAssertEqual(Catalog.challenge.count, 7)
        XCTAssertTrue(Catalog.challenge[0].isFree)
        XCTAssertTrue(Catalog.challenge.dropFirst().allSatisfy { !$0.isFree })
    }
    @MainActor func testPhotoQuotaAllowsResumingOriginal() throws {
        let store = makeStore()
        let first = photo("first"), second = photo("second")
        XCTAssertTrue(store.state.canOpen(first, isPro: false))
        let id = try XCTUnwrap(store.startProject(first, isPro: false))
        XCTAssertEqual(store.state.freePhotoID, first.id)
        XCTAssertEqual(store.startProject(first, isPro: false), id)
        XCTAssertFalse(store.state.canOpen(second, isPro: false))
        XCTAssertNil(store.startProject(second, isPro: false))
        XCTAssertNotNil(store.startProject(second, isPro: true))
        XCTAssertEqual(store.state.completedDrawings, 0)
        store.finishProject(id)
        XCTAssertEqual(store.state.completedDrawings, 1)
    }
    @MainActor func testStateRoundTripAndLessonResume() {
        let defaults = UserDefaults(suiteName: "test." + UUID().uuidString)!
        let library = StudioLibrary(defaults: defaults)
        library.finishOnboarding(interests: [.manga, .flowers])
        library.toggleFavorite(Catalog.drawings[0])
        library.saveStep(2, lesson: Catalog.lessons[0])
        let restored = StudioLibrary(defaults: defaults)
        XCTAssertTrue(restored.state.hasOnboarded)
        XCTAssertEqual(restored.state.interests, [.manga, .flowers])
        XCTAssertEqual(restored.savedStep(Catalog.lessons[0]), 2)
        XCTAssertTrue(restored.state.favorites.contains(Catalog.drawings[0].id))
        restored.completeLesson(Catalog.lessons[0])
        restored.completeLesson(Catalog.lessons[0])
        XCTAssertEqual(restored.state.completedLessons.count, 1)
        XCTAssertEqual(restored.state.challengeDay, 2)
    }
    @MainActor func testActivityAndStepBounds() {
        let store = makeStore(), lesson = Catalog.lessons[0]
        store.saveStep(999, lesson: lesson)
        XCTAssertEqual(store.savedStep(lesson), lesson.steps.count - 1)
        store.saveStep(-2, lesson: lesson)
        XCTAssertEqual(store.savedStep(lesson), 0)
        store.recordActivity(seconds: -1)
        store.recordActivity(seconds: 30)
        store.recordActivity(seconds: 45)
        XCTAssertEqual(store.state.activeSeconds, 75)
        XCTAssertEqual(store.state.drawingDays.count, 1)
    }
    @MainActor private func makeStore() -> StudioLibrary { StudioLibrary(defaults: UserDefaults(suiteName: "test." + UUID().uuidString)!) }
    private func photo(_ id: String) -> Drawing { Drawing(id: id, title: id, asset: "", topic: .portraits, difficulty: .easy, minutes: 10, isFree: true, localImage: id + ".jpg") }
}
