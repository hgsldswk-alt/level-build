import XCTest
import Foundation

final class LevelMathTests: XCTestCase {
    func testFlatQuadrantsAndPhysicalDirections() {
        for x in [-8.0, -0.2, 0, 0.2, 8] {
            for y in [-8.0, -0.2, 0, 0.2, 8] {
                let g = Gravity.tilted(x: x, y: y)
                let r = LevelMath.read(g, pose: .flat)
                XCTAssertEqual(r.x, x, accuracy: 0.000001)
                XCTAssertEqual(r.y, y, accuracy: 0.000001)
                XCTAssertEqual(r.angle, LevelMath.degrees(acos(abs(g.z))), accuracy: 0.000001)
            }
        }
        XCTAssertEqual(LevelMath.xDirection(2), L.t("左边高"))
        XCTAssertEqual(LevelMath.xDirection(-2), L.t("右边高"))
        XCTAssertEqual(LevelMath.yDirection(-2), L.t("前面高"))
        XCTAssertEqual(LevelMath.yDirection(2), L.t("后面高"))
    }
    func testFaceDownUsesAbsoluteZWithoutSpurious180Degrees() {
        for down in [false, true] {
            let r = LevelMath.read(.tilted(x: 2, y: -3, faceDown: down), pose: .flat)
            XCTAssertEqual(r.x, 2, accuracy: 1e-8); XCTAssertEqual(r.y, -3, accuracy: 1e-8)
            XCTAssertEqual(r.faceDown, down)
            XCTAssertLessThan(r.angle, 4)
        }
        XCTAssertEqual(LevelMath.read(Gravity(x: 0, y: 0, z: 1), pose: .flat).angle, 0)
    }
    func testEdgePortraitLandscapeAndFrontBack() {
        for angle in [-15.0, 0, 15] {
            let a = angle * .pi / 180
            let portrait = LevelMath.read(Gravity(x: sin(a), y: -cos(a), z: 0), pose: .edge)
            let landscape = LevelMath.read(Gravity(x: -cos(a), y: -sin(a), z: 0), pose: .edge)
            XCTAssertEqual(portrait.angle, angle, accuracy: 1e-8)
            XCTAssertEqual(landscape.angle, angle, accuracy: 1e-8)
            XCTAssertEqual(portrait.plumb, abs(angle), accuracy: 1e-8)
        }
        XCTAssertEqual(LevelMath.read(Gravity(x: 0, y: -cos(.pi / 18), z: sin(.pi / 18)), pose: .edge).frontBack, 10, accuracy: 1e-8)
    }
    func testConversionsAndRelativeAngle() {
        XCTAssertEqual(LevelMath.slope(45), 100, accuracy: 1e-9)
        XCTAssertEqual(LevelMath.mmPerMeter(45), 1000, accuracy: 1e-9)
        XCTAssertEqual(LevelMath.ratio(45)!, 1, accuracy: 1e-9)
        XCTAssertEqual(LevelMath.roofPitch(45), 12, accuracy: 1e-9)
        XCTAssertNil(LevelMath.ratio(0))
        XCTAssertEqual(LevelMath.slope(-45), -100, accuracy: 1e-9)
        XCTAssertTrue(LevelMath.slope(90).isFinite)
        XCTAssertEqual(LevelMath.normalized(370), 10)
        XCTAssertEqual(LevelMath.normalized(-190), 170)
        XCTAssertEqual(LevelMath.relative(-170, zero: 170), 20)
        XCTAssertEqual(LevelMath.relative(30, zero: 10, supplementary: true), 160)
        XCTAssertEqual(LevelMath.relative(180, zero: 0), 180)
        XCTAssertEqual(LevelMath.angleBetween(.flat, Gravity(x: 0, y: -1, z: 0)), 90, accuracy: 1e-8)
        XCTAssertEqual(LevelMath.angleBetween(.flat, Gravity(x: 0, y: 0, z: 1)), 180, accuracy: 1e-8)
        XCTAssertEqual(LevelMath.angleBetween(.tilted(x: 22.5, y: 0), .flat), 22.5, accuracy: 1e-8)
        XCTAssertEqual(LevelMath.bubbleRadius(1), 26)
        XCTAssertEqual(LevelMath.bubbleRadius(2), 52)
        XCTAssertEqual(LevelMath.bubbleRadius(5), 96)
        XCTAssertEqual(LevelMath.bubbleRadius(30), 140)
    }
    func testPoseHysteresisAndRotation() {
        var detector = PoseDetector()
        XCTAssertEqual(detector.update(Gravity(x: sqrt(1 - 0.75 * 0.75), y: 0, z: -0.75)), .flat)
        XCTAssertEqual(detector.update(Gravity(x: sqrt(1 - 0.69 * 0.69), y: 0, z: -0.69)), .edge)
        XCTAssertEqual(detector.update(Gravity(x: 0.6, y: 0, z: -0.8)), .flat)
        let side = LevelMath.read(Gravity(x: 1, y: 0, z: 0), pose: .edge)
        XCTAssertEqual(side.rotation, 90)
        XCTAssertEqual(LevelMath.read(Gravity(x: 0, y: 1, z: 0), pose: .edge).rotation, 180)
    }
    func testSmoothingIsIndependentOfSampleRateAndStabilityUsesWholeSecond() {
        var a = Smoother(), b = Smoother()
        _ = a.update(.flat, dt: 0); _ = b.update(.flat, dt: 0)
        let input = Gravity(x: 1, y: 0, z: 0)
        for _ in 0..<60 { _ = a.update(input, dt: 1.0 / 60) }
        for _ in 0..<30 { _ = b.update(input, dt: 1.0 / 30) }
        XCTAssertEqual(a.value!.x, b.value!.x, accuracy: 1e-10)
        var window = StabilityWindow()
        for i in 0...50 { window.append(time: Double(i) / 60, x: 0.01, y: 0) }
        XCTAssertFalse(window.isStable(tolerance: 0.05))
        for i in 51...65 { window.append(time: Double(i) / 60, x: 0.01, y: 0) }
        XCTAssertTrue(window.isStable(tolerance: 0.05))
        window.append(time: 1.1, x: 0.2, y: 0)
        XCTAssertFalse(window.isStable(tolerance: 0.05))
    }
}
final class CalibrationTests: XCTestCase {
    func testDeterministicRandomSurfaceAndDeviceBiasSeparation() {
        var seed: UInt64 = 12345
        func random() -> Double { seed = seed &* 6364136223846793005 &+ 1; return Double(seed % 10000) / 1000 - 5 }
        for _ in 0..<1000 {
            let sx = random(), sy = random(), dx = random(), dy = random()
            let result = Calibration.solve(Offset(x: sx + dx, y: sy + dy), Offset(x: -sx + dx, y: -sy + dy))
            XCTAssertEqual(result.offset.x, dx, accuracy: 1e-10); XCTAssertEqual(result.offset.y, dy, accuracy: 1e-10)
            XCTAssertEqual(result.surface.x, sx, accuracy: 1e-10); XCTAssertEqual(result.surface.y, sy, accuracy: 1e-10)
        }
    }
    func testAccuracyComparesAfterUndoing180DegreeSurfaceSignAndPersistsTwoPoses() throws {
        XCTAssertTrue(Calibration.checkAccuracy(Offset(x: 2, y: -1), Offset(x: -2.05, y: 1.05)))
        XCTAssertFalse(Calibration.checkAccuracy(Offset(x: 2, y: -1), Offset(x: -1.8, y: 1)))
        let name = "LevelTest." + UUID().uuidString, defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        var c = Calibration(); c.set(Offset(x: 0.3, y: -0.2), pose: .flat); c.set(Offset(x: 1, y: 2), pose: .edge)
        try c.save(to: defaults)
        let read = Calibration.load(from: defaults)
        XCTAssertEqual(read.flat, c.flat); XCTAssertEqual(read.edge, c.edge); XCTAssertNotNil(read.flatDate)
    }
}
final class PlannerTests: XCTestCase {
    func testSingleFrameCenteredAndNailHeight() throws {
        let p = HangingPlan(wallWidth: 200, frames: [FrameSize(width: 40, height: 60)], hookDrop: 5, centerHeight: 145)
        let r = try HangingPlanner.calculate(p)[0]
        XCTAssertEqual(r.left, 80); XCTAssertEqual(r.nailX, 100); XCTAssertEqual(r.top, 175); XCTAssertEqual(r.nailHeight, 170)
    }
    func testThreeEqualSpacesAndSpecifiedGap() throws {
        var p = HangingPlan(wallWidth: 200, frames: Array(repeating: FrameSize(width: 40, height: 60), count: 3))
        let automatic = try HangingPlanner.calculate(p)
        XCTAssertEqual(automatic.map(\.left), [20, 80, 140])
        p.gap = 10
        XCTAssertEqual(try HangingPlanner.calculate(p).map(\.left), [30, 80, 130])
        p.wallWidth = 100
        XCTAssertThrowsError(try HangingPlanner.calculate(p)) { XCTAssertEqual($0 as? PlannerError, .insufficientWidth(40)) }
    }
    func testInchesConversionAndInvalidFrames() throws {
        var p = HangingPlan(wallWidth: 100, frames: [FrameSize(width: 20, height: 30)])
        let original = try HangingPlanner.calculate(p)[0]
        p.convert(to: .inch)
        XCTAssertEqual(try HangingPlanner.calculate(p)[0].nailX * 2.54, original.nailX, accuracy: 1e-8)
        p.frames[0].width = -.infinity
        XCTAssertThrowsError(try HangingPlanner.calculate(p))
    }
    func testFourFootCorrectionsBothStrategiesAndInches() throws {
        let x = LevelMath.degrees(atan(0.01))
        let minimum = try LevelingPlanner.calculate(length: 600, width: 600, x: x, y: 0, strategy: .minimum)
        for (value, expected) in zip(minimum.map(\.amount), [-3.0, 3, -3, 3]) { XCTAssertEqual(value, expected, accuracy: 1e-8) }
        let raise = try LevelingPlanner.calculate(length: 600, width: 600, x: x, y: 0, strategy: .raiseOnly)
        for (value, expected) in zip(raise.map(\.amount), [0.0, 6, 0, 6]) { XCTAssertEqual(value, expected, accuracy: 1e-8) }
        let inches = try LevelingPlanner.calculate(length: 600, width: 600, x: x, y: 0, strategy: .raiseOnly, inches: true)
        XCTAssertEqual(inches[1].amount * 25.4, 6, accuracy: 1e-8)
        let frontHigh = try LevelingPlanner.calculate(length: 600, width: 600, x: 0, y: -x, strategy: .raiseOnly)
        for (value, expected) in zip(frontHigh.map(\.amount), [0.0, 0, 6, 6]) { XCTAssertEqual(value, expected, accuracy: 1e-8) }
        XCTAssertThrowsError(try LevelingPlanner.calculate(length: 0, width: 600, x: 0, y: 0, strategy: .minimum))
    }
}
final class DataTests: XCTestCase {
    func testTaskCodesAllKindsLanguagesNoiseAndPrivacy() throws {
        let tasks = [TaskPayload(kind: .hanging, hanging: HangingPlan(name: "Living room")), TaskPayload(kind: .slopeTarget, target: 2, preset: "Drain"), TaskPayload(kind: .angleTarget, target: 22.5)]
        for task in tasks { for prefix in ShareCode.prefixes {
            let code = try ShareCode.encode(task, prefix: prefix)
            XCTAssertEqual(try ShareCode.decode("Here is your plan:\n" + code + "\nCopy this."), task)
            let token = code.components(separatedBy: prefix)[1].trimmingCharacters(in: .whitespaces)
            let spaced = token.enumerated().map { index, char in String(char) + (index % 12 == 0 ? " \n" : "") }.joined()
            XCTAssertEqual(try ShareCode.decode(prefix + " " + spaced), task)
            let json = String(data: try JSONEncoder().encode(task), encoding: .utf8)!
            XCTAssertFalse(json.contains("photo")); XCTAssertFalse(json.contains("notes"))
        } }
        XCTAssertThrowsError(try ShareCode.decode("invalid"))
        XCTAssertThrowsError(try ShareCode.encode(TaskPayload(kind: .angleTarget, target: 181)))
        XCTAssertThrowsError(try ShareCode.encode(TaskPayload(version: 2, kind: .slopeTarget, target: 2)))
    }
    func testZlibChecksumAndLimit() throws {
        let data = Data("abc你好".utf8), compressed = try XCTUnwrap(Zlib.pack(data))
        XCTAssertEqual(Zlib.unpack(compressed), data)
        var damaged = compressed; damaged[damaged.count - 1] ^= 1
        XCTAssertNil(Zlib.unpack(damaged)); XCTAssertNil(Zlib.pack(Data(repeating: 0, count: Zlib.maxJSONLength + 1)))
    }
    func testRecordCRUDSearchAtomicReloadPhotoAndCSV() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try RecordStore(directory: directory)
        var r = Measurement(mode: .slope, primary: 1.8, x: 1, y: 0, slope: 1.8, name: "=SUM(1)", notes: "a,\"b\"\r\nnext")
        try store.upsert(r)
        XCTAssertEqual(store.search("sum").count, 1)
        r.name = "Shelf"; try store.upsert(r)
        XCTAssertEqual(store.records.count, 1)
        r = try store.attach(Data([1, 2, 3]), to: r)
        XCTAssertNotNil(r.photoFileName)
        XCTAssertNil(store.photoURL("../secret.jpg"))
        let csv = store.csv()
        XCTAssertEqual(Array(csv.prefix(3)), [0xef, 0xbb, 0xbf])
        XCTAssertTrue(String(data: csv, encoding: .utf8)!.contains("a,\"\"b\"\"\r\nnext"))
        XCTAssertEqual(try RecordStore(directory: directory).records, [r])
        try store.delete(r.id); XCTAssertTrue(store.records.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.photoURL(r.photoFileName!)!.path))
    }
}
final class EntitlementTests: XCTestCase {
    func testTrialToleranceExpiryRestorationAndFreePeriod() {
        let date = Date(timeIntervalSince1970: 100_000)
        var e = Entitlement(firstOpen: date)
        XCTAssertTrue(e.isPremium(at: date.addingTimeInterval(-600)))
        XCTAssertFalse(e.isPremium(at: date.addingTimeInterval(-601)))
        XCTAssertTrue(e.isPremium(at: date.addingTimeInterval(30 * 86400 - 1)))
        XCTAssertFalse(e.isPremium(at: date.addingTimeInterval(30 * 86400)))
        XCTAssertTrue(e.hasPro(at: .distantFuture, free: true))
        XCTAssertFalse(e.hasPro(at: .distantFuture, free: false))
        e.proStartedAt = date.addingTimeInterval(50 * 86400)
        XCTAssertTrue(e.isPremium(at: e.proStartedAt!))
        e.trialClaimedAt = date
        XCTAssertFalse(e.isPremium(at: e.proStartedAt!))
        e.purchasedPro = true; XCTAssertTrue(e.isPremium(at: .distantFuture))
    }
    func testLaunchDefaultsToPaidMode() {
        XCTAssertFalse(Launch.isFree(arguments: []))
        for flag in ["-paid-mode", "-expired", "-paywall"] { XCTAssertFalse(Launch.isFree(arguments: [flag])) }
        XCTAssertEqual(Launch.value("-mode", in: ["App", "-mode", "slope"]), "slope")
    }
    func testReviewNeverDuringUnlockedMeasurementAndConditionsOnlyOnce() {
        var gate = ReviewGate(); gate.qualify(.accurateCalibration)
        XCTAssertNil(gate.consume(locked: false))
        XCTAssertEqual(gate.consume(locked: true), .accurateCalibration)
        gate.qualify(.accurateCalibration); XCTAssertNil(gate.consume(locked: true))
        gate.qualify(.firstWall); XCTAssertEqual(gate.consume(locked: true), .firstWall)
    }
    func testMilestonesOnlyAtThresholdsAndPersist() throws {
        var m = Milestones(), seen: [Int] = []
        for i in 1...101 { if m.recordSaved() != nil { seen.append(i) } }
        XCTAssertEqual(seen, [10, 50, 100])
        var walls: [Int] = []
        for i in 1...11 { if m.wallCompleted() != nil { walls.append(i) } }
        XCTAssertEqual(walls, [1, 5, 10])
        let restored = try JSONDecoder().decode(Milestones.self, from: JSONEncoder().encode(m))
        XCTAssertEqual(restored.shown, m.shown)
    }
}
