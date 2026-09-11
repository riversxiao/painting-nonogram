import XCTest

final class KanakaAppUITests: XCTestCase {
    @MainActor private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testColdStartCanReachRestoration() {
        launch(scenario: "world-intro")
        defer { app.terminate() }

        assertExists("onboarding.intro.title")
        let introTitle = element("onboarding.intro.title").label
        XCTAssertEqual(introTitle, "长夜之后")

        tap("onboarding.intro.continue")
        let advancedToAgencyIntro = waitForLabel(
            "文明修复署",
            on: element("onboarding.intro.title")
        )
        XCTAssertTrue(advancedToAgencyIntro)

        tap("onboarding.intro.continue")
        assertExists("onboarding.tutorial.board")
        tap("onboarding.tutorial.skip")

        assertExists("onboarding.route-choice.title")
        tap("onboarding.route.restoration")

        assertExists("restoration.home")
        assertExists("restoration.museum.dev-museum-cardinality")
    }

    @MainActor
    func testLockedWorkshopExplainsUnlockAndLinksToRestoration() {
        launch(scenario: "ready-workshop")
        defer { app.terminate() }

        assertExists("workshop.home")
        assertExists("workshop.artwork.dev-artwork-cardinality-1")
        tap("workshop.artwork.dev-artwork-cardinality-1")

        assertExists("workshop.locked")
        tap("workshop.locked.open-restoration")

        assertExists("restoration.home")
        assertExists("restoration.museum.dev-museum-cardinality")
    }

    @MainActor
    func testRestorationCanNavigateToPlayablePuzzle() {
        launch(scenario: "ready-restoration")
        defer { app.terminate() }

        assertExists("restoration.museum.dev-museum-cardinality")
        tap("restoration.museum.dev-museum-cardinality")
        assertExists("restoration.gallery.dev-gallery-cardinality")
        tap("restoration.gallery.dev-gallery-cardinality")
        assertExists("restoration.artwork.dev-artwork-cardinality-1")
        tap("restoration.artwork.dev-artwork-cardinality-1")
        assertExists("restoration.fragment.m1-g1-a01-f01")
        tap("restoration.fragment.m1-g1-a01-f01")

        assertExists("puzzle.status", timeout: 15)
        assertExists("puzzle.board")
        let puzzleErrorExists = element("puzzle.error").exists
        XCTAssertFalse(puzzleErrorExists)
    }

    @MainActor
    private func launch(scenario: String) {
        app = XCUIApplication()
        app.launchEnvironment["KANAKA_UI_TESTING"] = "1"
        app.launchEnvironment["KANAKA_UI_SCENARIO"] = scenario
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_Hans"]
        app.launch()
        let startupErrorExists = element("startup.error").waitForExistence(timeout: 2)
        XCTAssertFalse(startupErrorExists)
    }

    @MainActor
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    @MainActor
    private func tap(
        _ identifier: String,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let target = element(identifier)
        let predicate = NSPredicate(format: "exists == true AND hittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: target)
        guard XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed else {
            XCTFail(
                "Expected hittable accessibility identifier \(identifier)",
                file: file,
                line: line
            )
            return
        }
        target.tap()
    }

    @MainActor
    private func assertExists(
        _ identifier: String,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let didExist = element(identifier).waitForExistence(timeout: timeout)
        XCTAssertTrue(
            didExist,
            "Expected accessibility identifier \(identifier)",
            file: file,
            line: line
        )
    }

    @MainActor
    private func waitForLabel(
        _ label: String,
        on element: XCUIElement,
        timeout: TimeInterval = 10
    ) -> Bool {
        let predicate = NSPredicate(format: "label == %@", label)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
