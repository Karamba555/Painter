import XCTest

final class PainterUITests: XCTestCase {
    func testOnboardingPersonalizationAndTabs() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-state"]
        app.launch()
        XCTAssertTrue(app.buttons["personalize"].waitForExistence(timeout: 10))
        screenshot("01-Welcome")
        app.buttons["personalize"].tap()
        app.buttons["Manga"].tap()
        app.buttons["Animals & Pets"].tap()
        screenshot("02-Interests")
        app.buttons["saveInterests"].tap()
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["For You"].exists)
        screenshot("03-Home")
        app.tabBars.buttons["Lessons"].tap()
        XCTAssertTrue(app.staticTexts["Learn to draw."].waitForExistence(timeout: 5))
        screenshot("04-Lessons")
        app.tabBars.buttons["Favorites"].tap()
        XCTAssertTrue(app.staticTexts["Make room for inspiration"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Profile"].tap()
        XCTAssertTrue(app.staticTexts["Your studio"].waitForExistence(timeout: 5))
        screenshot("05-Profile")
    }
    func testSkipAndLessonResume() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-state"]
        app.launch()
        app.buttons["skipOnboarding"].tap()
        app.tabBars.buttons["Lessons"].tap()
        app.buttons["Start Day 1 →"].tap()
        XCTAssertTrue(app.staticTexts["Step 1 of 6"].waitForExistence(timeout: 5))
        app.buttons["nextLessonStep"].tap()
        XCTAssertTrue(app.staticTexts["Step 2 of 6"].exists)
        app.terminate()
        app.launchArguments = []
        app.launch()
        app.tabBars.buttons["Lessons"].tap()
        app.buttons["Continue Day 1 →"].tap()
        XCTAssertTrue(app.staticTexts["Step 2 of 6"].waitForExistence(timeout: 5))
        screenshot("06-Lesson")
    }
    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }
}
