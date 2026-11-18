import Foundation

struct Offset: Codable, Equatable {
    var x: Double
    var y: Double
    static let zero = Offset(x: 0, y: 0)
}
struct CalibrationResult: Equatable {
    var offset: Offset
    var surface: Offset
}
struct Calibration: Codable {
    var flat: Offset = .zero
    var edge: Offset = .zero
    var flatDate: Date?
    var edgeDate: Date?
    func offset(for pose: Pose) -> Offset { pose == .flat ? flat : edge }
    func date(for pose: Pose) -> Date? { pose == .flat ? flatDate : edgeDate }
    static func solve(_ r1: Offset, _ r2: Offset) -> CalibrationResult {
        CalibrationResult(offset: Offset(x: (r1.x + r2.x) / 2, y: (r1.y + r2.y) / 2),
                          surface: Offset(x: (r1.x - r2.x) / 2, y: (r1.y - r2.y) / 2))
    }
    static func checkAccuracy(_ r1: Offset, _ r2: Offset) -> Bool {
        max(abs(r1.x + r2.x), abs(r1.y + r2.y)) <= 0.10000001
    }
    mutating func set(_ offset: Offset, pose: Pose, date: Date = Date()) {
        if pose == .flat { flat = offset; flatDate = date } else { edge = offset; edgeDate = date }
    }
    func save(to defaults: UserDefaults) throws { defaults.set(try JSONEncoder().encode(self), forKey: "calibration") }
    static func load(from defaults: UserDefaults) -> Calibration {
        guard let d = defaults.data(forKey: "calibration"), let value = try? JSONDecoder().decode(Calibration.self, from: d) else { return Calibration() }
        return value
    }
}
