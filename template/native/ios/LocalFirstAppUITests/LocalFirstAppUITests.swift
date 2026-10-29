import XCTest

final class LocalFirstAppUITests: XCTestCase {
    private let origin = "§§deploy_your_startup.web_origin§§"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTaskSurvivesOfflineRelaunchAndNativeNavigation() throws {
        let app = XCUIApplication()
        app.launchEnvironment["WEB_ORIGIN"] = origin
        app.launch()

        let web = app.webViews.firstMatch
        let title = web.textFields["Task title"]

        XCTAssertTrue(title.waitForExistence(timeout: 120), "The web UI did not load")
        title.tap()
        title.typeText("Offline task")

        let add = web.buttons["Add task"]
        XCTAssertTrue(add.waitForExistence(timeout: 20))
        add.tap()

        XCTAssertTrue(
            web.staticTexts["Offline task"].waitForExistence(timeout: 30),
            "The task was not listed after creation"
        )

        // Initial online load has installed the service worker and written to
        // OPFS. Terminate, make the origin unreachable, then relaunch.
        app.terminate()
        try setOriginReachable(false)

        app.launch()

        XCTAssertTrue(
            web.staticTexts["Offline task"].waitForExistence(timeout: 120),
            "The cached UI or the durable task was unavailable offline"
        )

        // Native navigation pushes a second visitable; the navigation bar's
        // back button returns to the task list.
        app.navigationBars.buttons["About"].tap()
        XCTAssertTrue(
            web.staticTexts["Runtime: all available"].waitForExistence(timeout: 60),
            "The WKWebView runtime lacks a required capability"
        )

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(
            web.staticTexts["Offline task"].waitForExistence(timeout: 30),
            "Native back navigation did not return to the task list"
        )
    }

    private func setOriginReachable(_ reachable: Bool) throws {
        let action = reachable ? "online" : "offline"
        let url = try XCTUnwrap(URL(string: "\(origin)/__control/\(action)"))
        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        let finished = expectation(description: "control request \(action)")
        var result: Result<Int, Error>?

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error {
                result = .failure(error)
            } else {
                result = .success((response as? HTTPURLResponse)?.statusCode ?? 0)
            }
            finished.fulfill()
        }.resume()

        wait(for: [finished], timeout: 20)

        switch result {
        case .success(let status) where status == 200:
            return
        case .success(let status):
            XCTFail("Offline control returned HTTP \(status)")
        case .failure(let error):
            XCTFail("Offline control request failed: \(error)")
        case nil:
            XCTFail("Offline control request did not complete")
        }
    }
}
