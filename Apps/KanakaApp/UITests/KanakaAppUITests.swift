import XCTest

final class KanakaAppUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testColdStartCanReachRestoration() {
        launch(scenario: "world-intro")

        assertExists("onboarding.intro.title")
        XCTAssertEqual(element("onboarding.intro.title").label, "长夜之后")

        tap("onboarding.intro.continue")
        XCTAssertTrue(waitForLabel("文明修复署", on: element("onboarding.intro.title")))

        tap("onboarding.intro.continue")
        assertExists("onboarding.tutorial.board")
        tap("onboarding.tutorial.skip")

        assertExists("onboarding.route-choice.title")
        tap("onboarding.route.restoration")

        assertExists("restoration.home")
        assertExists("restoration.museum.dev-museum-cardinality")
    }

    func testLockedWorkshopExplainsUnlockAndLinksToRestoration() {
        launch(scenario: "ready-workshop")

        assertExists("workshop.home")
        assertExists("workshop.artwork.dev-artwork-cardinality-1")
        tap("workshop.artwork.dev-artwork-cardinality-1")

        assertExists("workshop.locked")
        tap("workshop.locked.open-restoration")

        assertExists("restoration.home")
        assertExists("restoration.museum.dev-museum-cardinality")
    }

    func testRestorationCanNavigateToPlayablePuzzle() {
        launch(scenario: "ready-restoration")

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
        XCTAssertFalse(element("puzzle.error").exists)
    }

    private func launch(scenario: String) {
        app = XCUIApplication()
        app.launchEnvironment["KANAKA_UI_TESTING"] = "1"
        app.launchEnvironment["KANAKA_UI_SCENARIO"] = scenario
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_Hans"]
        app.launch()
        XCTAssertFalse(element("startup.error").waitForExistence(timeout: 2))
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

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

    private func assertExists(
        _ identifier: String,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            element(identifier).waitForExistence(timeout: timeout),
            "Expected accessibility identifier \(identifier)",
            file: file,
            line: line
        )
    }

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
