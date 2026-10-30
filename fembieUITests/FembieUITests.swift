//
//  FembieUITests.swift
//  FembieUITests
//
//  Created by Eva Xeon on 02.10.26.
//

import XCTest

final class FembieUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testOpeningNotificationColdLaunchesIntoWellbeing() async throws {
        let app = XCUIApplication()
        app.launchArguments.append("--schedule-notification-navigation-test")
        app.launch()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allowButton = springboard.alerts.buttons["Allow"]
        if allowButton.waitForExistence(timeout: 2) {
            allowButton.tap()
        }

        // Give the app time to register the request before terminating it.
        try await Task.sleep(for: .seconds(1))
        app.terminate()
        springboard.activate()

        let notification = springboard.staticTexts["Fembie Notification Navigation Test"]
        XCTAssertTrue(
            notification.waitForExistence(timeout: 10),
            "The test notification was not delivered."
        )
        notification.tap()

        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 5),
            "Tapping the notification did not cold-launch the app."
        )
        let wellbeingTab = app.tabBars.buttons["Wellbeing"]
        XCTAssertTrue(
            wellbeingTab.waitForExistence(timeout: 5),
            "The app did not display its tab bar after notification launch."
        )
        XCTAssertTrue(
            wellbeingTab.isSelected,
            "The notification did not navigate to the Wellbeing tab."
        )
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)]) {
            XCUIApplication().launch()
        }
    }
}
