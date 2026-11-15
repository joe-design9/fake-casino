import XCTest

final class PlaythroughUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testOpenEveryGameSpinGambleAndAutoplay() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()

        for identifier in ["spiel-fruchtfeuer", "spiel-sphinx", "spiel-joker"] {
            let tile = app.buttons[identifier]
            XCTAssertTrue(tile.waitForExistence(timeout: 8), identifier)
            tile.tap()

            let start = app.buttons["start-button"]
            XCTAssertTrue(start.waitForExistence(timeout: 8))

            for index in 0..<4 {
                dismissOverlays(app)
                waitUntilLabel(start, "START", timeout: 60)
                start.tap()
                if index == 1 {
                    RunLoop.current.run(until: Date().addingTimeInterval(0.12))
                    if start.label == "STOP" {
                        start.tap()
                    }
                }
            }
            dismissOverlays(app)

            let risiko = app.buttons["risiko-button"]
            if risiko.exists && risiko.isEnabled {
                risiko.tap()
                if app.buttons["RISIKOLEITER"].waitForExistence(timeout: 3) {
                    app.buttons["RISIKOLEITER"].tap()
                }
                if app.buttons["ANNEHMEN"].waitForExistence(timeout: 3) {
                    app.buttons["ANNEHMEN"].tap()
                } else if app.buttons["EINSAMMELN"].exists {
                    app.buttons["EINSAMMELN"].tap()
                }
            }

            dismissOverlays(app)
            let auto = app.buttons["auto-button"]
            XCTAssertTrue(auto.waitForExistence(timeout: 8))
            waitUntilEnabled(auto, timeout: 20)
            auto.tap()
            let ten = app.buttons["10 DREHUNGEN"]
            XCTAssertTrue(ten.waitForExistence(timeout: 4))
            ten.tap()

            let started = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label BEGINSWITH 'STOP'"),
                object: auto
            )
            XCTAssertEqual(XCTWaiter().wait(for: [started], timeout: 8), .completed)
            let returned = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label == 'AUTO' AND enabled == true"),
                object: auto
            )
            XCTAssertEqual(XCTWaiter().wait(for: [returned], timeout: 120), .completed)

            app.buttons["back-button"].tap()
            XCTAssertTrue(app.buttons["spiel-fruchtfeuer"].waitForExistence(timeout: 8))
        }
    }

    private func dismissOverlays(_ app: XCUIApplication) {
        let labels = ["EINSAMMELN", "ANNEHMEN", "SCHLIESSEN", "ABBRECHEN"]
        for label in labels {
            let button = app.buttons[label]
            if button.exists && button.isHittable {
                button.tap()
            }
        }
    }

    private func waitUntilLabel(_ element: XCUIElement, _ label: String, timeout: TimeInterval) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@ AND enabled == true AND hittable == true", label),
            object: element
        )
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: timeout), .completed)
    }

    private func waitUntilEnabled(_ element: XCUIElement, timeout: TimeInterval) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "enabled == true AND hittable == true"),
            object: element
        )
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: timeout), .completed)
    }
}
