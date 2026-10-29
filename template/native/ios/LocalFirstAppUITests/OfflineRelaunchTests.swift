import XCTest

/// Phase two of the simulator check. The harness has already stopped the tunnel
/// and confirmed the configured origin is unreachable, so this launch proves
/// the cached UI and the durable OPFS database reopen without network access.
final class OfflineRelaunchTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testReopensTheSavedTaskWithoutTheOrigin() {
        let app = XCUIApplication()
        app.launch()

        let webView = app.webViews.firstMatch
        XCTAssertTrue(
            webView.staticTexts["Buy oat milk"].waitForExistence(timeout: 60),
            "the saved task was not loaded from the cached UI and OPFS after relaunch"
        )
        XCTAssertFalse(
            webView.staticTexts["No tasks yet."].exists,
            "the relaunch started from an empty database"
        )

        XCTAssertTrue(
            webView.staticTexts.matching(
                NSPredicate(format: "label BEGINSWITH %@", "Runtime: all available")
            ).firstMatch.waitForExistence(timeout: 15),
            "the cached runtime is not fully available after relaunch"
        )
    }
}
