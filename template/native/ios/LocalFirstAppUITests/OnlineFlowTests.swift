import XCTest

/// Phase one of the simulator check: the shell loads the tunnel origin, the web
/// runtime saves a task, and native navigation works. The harness stops the
/// tunnel after this test finishes, then runs `OfflineRelaunchTests`.
final class OnlineFlowTests: XCTestCase {
    private let runtimeAvailable = NSPredicate(
        format: "label BEGINSWITH %@",
        "Runtime: all available"
    )

    override func setUp() {
        continueAfterFailure = false
    }

    func testCreatesATaskWithTheWebRuntime() {
        let app = XCUIApplication()
        app.launch()

        let webView = app.webViews.firstMatch
        let addTask = webView.buttons["Add task"]
        XCTAssertTrue(
            addTask.waitForExistence(timeout: 60),
            "the web application did not start from the configured origin"
        )

        XCTAssertTrue(webView.staticTexts["No tasks yet."].waitForExistence(timeout: 15))

        let titleField = webView.textFields["Task title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 15))

        titleField.tap()
        titleField.typeText("Buy oat milk")
        addTask.tap()

        XCTAssertTrue(
            webView.staticTexts["Buy oat milk"].waitForExistence(timeout: 15),
            "the created task is not listed"
        )

        // The visible status line reports what the actual WKWebView provides:
        // a secure context, cross-origin isolation, a controlling service
        // worker, Web Locks, OPFS and the SQLite database worker.
        XCTAssertTrue(
            webView.staticTexts.matching(runtimeAvailable).firstMatch.waitForExistence(timeout: 15),
            "the WKWebView runtime is not fully available"
        )
        XCTAssertTrue(
            webView.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", "SQLite 3.54.1 in OPFS")
            ).firstMatch.exists
        )

        assertNativeNavigation(returnsTo: app)

        app.terminate()
    }

    /// The About screen is native navigation. Tapping back must return to the
    /// web screen without losing its state.
    private func assertNativeNavigation(returnsTo app: XCUIApplication) {
        let about = app.buttons["About"]
        XCTAssertTrue(about.waitForExistence(timeout: 15), "the native About button is missing")
        about.tap()

        XCTAssertTrue(
            app.staticTexts["About this application"].waitForExistence(timeout: 10),
            "the native About screen did not appear"
        )
        XCTAssertTrue(app.staticTexts["web-origin"].exists)

        app.navigationBars.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(
            app.webViews.firstMatch.staticTexts["Buy oat milk"].waitForExistence(timeout: 15),
            "back navigation did not return to the task list"
        )
    }
}
