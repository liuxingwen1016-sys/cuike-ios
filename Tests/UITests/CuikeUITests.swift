import XCTest

final class CuikeUITests: XCTestCase {
    @MainActor func testBrewToTastingFlow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.buttons["prepareRecipe"].waitForExistence(timeout: 10))
        app.buttons["prepareRecipe"].tap()
        XCTAssertTrue(app.staticTexts["targetWater"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["targetWater"].label, "240g")
        app.steppers["doseStepper"].buttons.element(boundBy: 1).tap()
        app.steppers["doseStepper"].buttons.element(boundBy: 1).tap()
        app.steppers["doseStepper"].buttons.element(boundBy: 1).tap()
        XCTAssertEqual(app.staticTexts["targetWater"].label, "288g")
        reveal(app.buttons["startBrew"], app: app)
        app.buttons["startBrew"].tap()
        XCTAssertTrue(app.buttons["finishEarly"].waitForExistence(timeout: 5))
        reveal(app.buttons["finishEarly"], app: app)
        app.buttons["finishEarly"].tap()
        app.buttons["confirmFinishEarly"].tap()
        XCTAssertTrue(app.buttons["rating5"].waitForExistence(timeout: 5))
        app.buttons["rating5"].tap()
        reveal(app.buttons["saveTasting"], app: app)
        app.buttons["saveTasting"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "4.5")).firstMatch.waitForExistence(timeout: 5))
    }
    @MainActor func testManualBeanRequiresName() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.tabBars.buttons["豆档案"].tap()
        app.buttons["addBean"].tap()
        reveal(app.buttons["manualBean"], app: app)
        app.buttons["manualBean"].tap()
        app.buttons["saveBean"].tap()
        XCTAssertTrue(app.staticTexts["beanError"].waitForExistence(timeout: 3))
        app.textFields["beanName"].tap()
        app.textFields["beanName"].typeText("Test Coffee")
        app.buttons["saveBean"].tap()
        XCTAssertTrue(app.staticTexts["Test Coffee"].waitForExistence(timeout: 5))
    }
    @MainActor private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<5 { if element.isHittable { return }; app.swipeUp() }
    }
}
