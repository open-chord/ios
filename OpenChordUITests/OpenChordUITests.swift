import XCTest

@MainActor
final class OpenChordUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchShowsPrimaryNavigation() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.navigationBars["OpenChord"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Home"].exists)
        XCTAssertTrue(app.tabBars.buttons["Library"].exists)
    }
}
