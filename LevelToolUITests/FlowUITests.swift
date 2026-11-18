import XCTest

final class FlowUITests: XCTestCase {
    private enum StoreLanguage: String, CaseIterable {
        case simplifiedChinese = "zh-Hans"
        case english = "en"
        case traditionalChinese = "zh-Hant"

        var locale: String {
            switch self {
            case .simplifiedChinese: return "zh_CN"
            case .english: return "en_US"
            case .traditionalChinese: return "zh_TW"
            }
        }

        var calibrationComplete: String {
            switch self {
            case .simplifiedChinese: return "校准完成"
            case .english: return "Calibration complete"
            case .traditionalChinese: return "校準完成"
            }
        }
    }

    private var app: XCUIApplication!
    override func setUp() { continueAfterFailure = false; app = XCUIApplication() }
    private func launch(_ args: [String] = [], language: StoreLanguage = .simplifiedChinese) {
        app.launchArguments = ["-uitest-fresh", "-AppleLanguages", "(\(language.rawValue))", "-AppleLocale", language.locale] + args
        app.launch()
    }
    private func tap(_ id: String) {
        let button = app.buttons[id].firstMatch
        for _ in 0..<6 { if button.exists && button.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(button.waitForExistence(timeout: 8), id); XCTAssertTrue(button.isHittable, id); button.tap()
    }
    private func shot(_ name: String) throws {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        if let path = ProcessInfo.processInfo.environment["SHOTS_DIR"] ?? ProcessInfo.processInfo.environment["TEST_RUNNER_SHOTS_DIR"] {
            let directory = URL(fileURLWithPath: path, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try screenshot.pngRepresentation.write(to: directory.appendingPathComponent(name + ".png"))
        }
    }
    func testFreshStartsImmediatelyAndFiveModes() throws {
        for language in StoreLanguage.allCases {
            launch(["-sim-tilt", "0.21,0.18", "-sim-camera"], language: language)
            XCTAssertTrue(app.staticTexts["reading.primary"].waitForExistence(timeout: 8))
            XCTAssertEqual(app.alerts.count, 0); XCTAssertFalse(app.staticTexts["paywall.title"].exists)
            try shot("\(language.rawValue)-01-home-light")
            for mode in ["slope", "angle", "plumb", "camera"] { tap("mode." + mode) }
            XCTAssertTrue(app.buttons["camera.shutter"].waitForExistence(timeout: 8))
            try shot("\(language.rawValue)-04-camera")
        }
    }
    func testLockSaveAndRecords() throws {
        launch(["-sim-tilt", "0.21,0.18"])
        let area = app.otherElements["measurement.area"].firstMatch
        XCTAssertTrue(area.waitForExistence(timeout: 8)); area.tap()
        tap("save"); tap("saved.edit")
        XCTAssertTrue(app.buttons["records.editRecent"].waitForExistence(timeout: 8)); try shot("07-records")
        tap("records.editRecent"); let field = app.textFields["record.name"]
        XCTAssertTrue(field.waitForExistence(timeout: 8)); field.tap(); field.typeText("Shelf")
    }
    func testAutomaticCalibration() throws {
        for language in StoreLanguage.allCases {
            launch(["-sim-tilt", "0.21,0.18", "-calibrate"], language: language)
            tap("calibration.start")
            let done = app.staticTexts["calibration.stage"]
            let predicate = NSPredicate(format: "label == %@", language.calibrationComplete)
            expectation(for: predicate, evaluatedWith: done); waitForExpectations(timeout: 15)
            try shot("\(language.rawValue)-09-calibration-result")
            tap("calibration.check")
            XCTAssertTrue(app.staticTexts["calibration.accuracy"].waitForExistence(timeout: 15))
        }
    }
    func testHangingCodeAndImport() throws {
        for language in [StoreLanguage.english, .traditionalChinese] {
            launch(["-hanging"], language: language)
            XCTAssertTrue(app.otherElements["hanging.results"].waitForExistence(timeout: 8))
            try shot("\(language.rawValue)-05-hanging-results")
        }
        launch(["-hanging"])
        XCTAssertTrue(app.otherElements["hanging.results"].waitForExistence(timeout: 8))
        try shot("zh-Hans-05-hanging-results"); tap("hanging.share")
        XCTAssertTrue(app.staticTexts["code.generated"].waitForExistence(timeout: 8))
        try shot("06-hanging-code")
        launch(["-import"])
        XCTAssertTrue(app.otherElements["hanging.results"].waitForExistence(timeout: 8))
        tap("hanging.align"); XCTAssertTrue(app.staticTexts["reading.primary"].waitForExistence(timeout: 8))
    }
    func testSlopeTarget() throws {
        for language in StoreLanguage.allCases {
            launch(["-sim-slope", "1.8", "-mode", "slope"], language: language)
            tap("target.2")
            let delta = app.staticTexts["slope.delta"]
            let predicate = NSPredicate(format: "label CONTAINS %@", "0.2")
            expectation(for: predicate, evaluatedWith: delta); waitForExpectations(timeout: 8)
            try shot("\(language.rawValue)-03-slope-target")
        }
    }
    func testPaidAndExpiredRemainMeasurable() throws {
        launch(["-paid-mode", "-paywall"])
        XCTAssertTrue(app.staticTexts["paywall.title"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["paywall.trial"].exists)
        XCTAssertTrue(app.buttons["paywall.restore"].exists); try shot("10-paywall")
        launch(["-expired", "-sim-tilt", "0.21,0.18"])
        XCTAssertTrue(app.staticTexts["reading.primary"].waitForExistence(timeout: 8))
        tap("lock"); XCTAssertTrue(app.buttons["save"].exists)
        tap("mode.camera")
        XCTAssertTrue(app.staticTexts["paywall.title"].waitForExistence(timeout: 8))
    }
    func testOtherScreenshotsAndAutomaticLock() throws {
        launch(["-sim-edge", "0.0", "-locked", "-AppleInterfaceStyle", "Dark"])
        XCTAssertTrue(app.buttons["save"].waitForExistence(timeout: 8)); try shot("02-edge-locked-dark")
        launch(["-demo", "-share"]); XCTAssertTrue(app.buttons["share.export"].waitForExistence(timeout: 8)); try shot("06-share-card")
        launch(["-demo", "-settings"]); try shot("08-settings")
        launch(["-leveling"]); XCTAssertTrue(app.otherElements["leveling.results"].waitForExistence(timeout: 8)); try shot("11-leveling")
        launch(["-sim-tilt", "0.21,0.18", "-settings"])
        let autoLock = app.switches["settings.autoLock"]
        XCTAssertTrue(autoLock.waitForExistence(timeout: 8))
        autoLock.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        XCTAssertEqual(autoLock.value as? String, "1"); tap("sheet.done")
        XCTAssertTrue(app.buttons["save"].waitForExistence(timeout: 8))
    }
}
