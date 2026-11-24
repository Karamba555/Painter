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
    func testCatalogModesAndPaywall() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-state"]
        app.launch()
        app.buttons["skipOnboarding"].tap()
        app.buttons["Explore"].tap()
        app.buttons.containing(.staticText, identifier: "Manga").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Lucky kitten"].waitForExistence(timeout: 5))
        screenshot("07-Manga")
        app.buttons.containing(.staticText, identifier: "Lucky kitten").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["How will you trace?"].waitForExistence(timeout: 5))
        screenshot("08-Choose-mode")
        app.buttons["Screen Trace. Trace through thin paper on your screen."].tap()
        XCTAssertTrue(app.buttons["Lock outline"].waitForExistence(timeout: 5))
        app.buttons["Lock outline"].tap()
        XCTAssertTrue(app.buttons["Unlock"].exists)
        screenshot("09-Screen-trace")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons.containing(.staticText, identifier: "Flower girl").firstMatch.tap()
        XCTAssertTrue(app.buttons["subscribe"].waitForExistence(timeout: 5))
        screenshot("10-Paywall")
        app.buttons["Close paywall"].tap()
        XCTAssertTrue(app.staticTexts["Lucky kitten"].waitForExistence(timeout: 5))
    }
    func testFinishedProjectResumesAfterRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-state"]
        app.launch()
        app.buttons["skipOnboarding"].tap()
        app.buttons["Explore"].tap()
        app.buttons.containing(.staticText, identifier: "Manga").firstMatch.tap()
        app.buttons.containing(.staticText, identifier: "Lucky kitten").firstMatch.tap()
        app.buttons["Screen Trace. Trace through thin paper on your screen."].tap()
        let size = app.sliders["Outline size"]
        XCTAssertTrue(size.waitForExistence(timeout: 5))
        size.adjust(toNormalizedSliderPosition: 0.7)
        let savedSize = size.value as? String
        XCTAssertTrue(app.buttons["finishDrawing"].isHittable)
        app.buttons["finishDrawing"].tap()
        XCTAssertTrue(app.staticTexts["Made by you."].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments = []
        app.launch()
        app.tabBars.buttons["Profile"].tap()
        app.buttons["View all"].tap()
        app.buttons.containing(.staticText, identifier: "Lucky kitten").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["FINISHED"].waitForExistence(timeout: 5))
        app.buttons["Continue drawing →"].tap()
        XCTAssertTrue(app.sliders["Outline size"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.sliders["Outline size"].value as? String, savedSize)
        XCTAssertTrue(app.navigationBars["Screen Trace"].exists)
        screenshot("11-Resumed-project")
    }
    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }
}
