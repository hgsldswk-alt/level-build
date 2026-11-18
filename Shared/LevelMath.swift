import Foundation

struct Gravity: Equatable, Codable {
    var x: Double
    var y: Double
    var z: Double
    var length: Double { sqrt(x * x + y * y + z * z) }
    static let flat = Gravity(x: 0, y: 0, z: -1)
    static func tilted(x: Double, y: Double, faceDown: Bool = false) -> Gravity {
        let tx = tan(x * .pi / 180), ty = tan(y * .pi / 180)
        let n = sqrt(1 + tx * tx + ty * ty)
        return Gravity(x: tx / n, y: ty / n, z: (faceDown ? 1 : -1) / n)
    }
}

enum Pose: String, Codable { case flat, edge }
struct PoseDetector {
    var pose: Pose = .flat
    mutating func update(_ g: Gravity) -> Pose {
        let z = abs(g.z) / max(g.length, 0.000001)
        if pose == .flat && z < 0.7 { pose = .edge }
        else if pose == .edge && z >= 0.8 { pose = .flat }
        return pose
    }
}
struct Reading: Equatable {
    var pose: Pose
    var faceDown: Bool
    var x: Double
    var y: Double
    var angle: Double
    var plumb: Double
    var frontBack: Double
    var rotation: Int
}
enum LevelMath {
    static func degrees(_ radians: Double) -> Double { radians * 180 / .pi }
    static func normalized(_ value: Double) -> Double {
        let r = (value + 180).truncatingRemainder(dividingBy: 360)
        return (r < 0 ? r + 360 : r) - 180
    }
    static func relative(_ angle: Double, zero: Double, supplementary: Bool = false) -> Double {
        let a = abs(normalized(angle - zero))
        return supplementary ? 180 - a : a
    }
    static func angleBetween(_ a: Gravity, _ b: Gravity, supplementary: Bool = false) -> Double {
        let dot = (a.x * b.x + a.y * b.y + a.z * b.z) / max(0.00000001, a.length * b.length)
        let angle = degrees(acos(max(-1, min(1, dot))))
        return supplementary ? 180 - angle : angle
    }
    static func read(_ g: Gravity, pose: Pose, offset: Offset = .zero, previousRotation: Int = 0) -> Reading {
        let length = max(g.length, 0.000001)
        let x = degrees(atan2(g.x, abs(g.z))) - offset.x
        let y = degrees(atan2(g.y, abs(g.z))) - offset.y
        let portrait = abs(g.y) >= abs(g.x)
        let edge = degrees(atan2(portrait ? g.x : -g.y, portrait ? abs(g.y) : abs(g.x))) - offset.x
        let back = degrees(atan2(g.z, hypot(g.x, g.y))) - offset.y
        let rawTilt = degrees(acos(min(1, abs(g.z) / length)))
        let tilt = offset == .zero ? rawTilt : degrees(atan(hypot(tan(x * .pi / 180), tan(y * .pi / 180))))
        var rotation = previousRotation
        if hypot(g.x, g.y) > 0.35 {
            let a = degrees(atan2(g.x, -g.y))
            let candidate = Int((a / 90).rounded()) * 90
            if abs(normalized(a - Double(previousRotation))) > 55 { rotation = candidate }
        }
        return Reading(pose: pose, faceDown: g.z > 0 && pose == .flat, x: pose == .flat ? x : edge,
                       y: pose == .flat ? y : back, angle: pose == .flat ? tilt : edge,
                       plumb: abs(edge), frontBack: back, rotation: rotation)
    }
    static func xDirection(_ x: Double) -> String { x >= 0 ? L.t("左边高") : L.t("右边高") }
    static func yDirection(_ y: Double) -> String { y <= 0 ? L.t("前面高") : L.t("后面高") }
    static func slope(_ degrees: Double) -> Double { tan(degrees * .pi / 180) * 100 }
    static func mmPerMeter(_ degrees: Double) -> Double { slope(degrees) * 10 }
    static func ratio(_ degrees: Double) -> Double? {
        let t = tan(degrees * .pi / 180)
        return abs(t) < 0.00000001 ? nil : 1 / t
    }
    static func roofPitch(_ degrees: Double) -> Double { slope(degrees) * 0.12 }
    static func bubbleRadius(_ angle: Double) -> Double {
        let d = min(10, max(0, angle))
        if d <= 2 { return d * 26 }
        if d <= 5 { return 52 + (d - 2) * 44 / 3 }
        return 96 + (d - 5) * 44 / 5
    }
}

struct Smoother {
    private(set) var value: Gravity?
    var timeConstant = 0.15
    mutating func update(_ input: Gravity, dt: Double) -> Gravity {
        guard let v = value else { value = input; return input }
        let a = 1 - exp(-max(0, dt) / timeConstant)
        let result = Gravity(x: v.x + a * (input.x - v.x), y: v.y + a * (input.y - v.y), z: v.z + a * (input.z - v.z))
        value = result
        return result
    }
}
struct StabilityWindow {
    private var samples: [(Double, Double, Double)] = []
    mutating func append(time: Double, x: Double, y: Double) {
        samples.append((time, x, y))
        samples.removeAll { $0.0 < time - 1.15 }
    }
    func isStable(window: Double = 1, tolerance: Double) -> Bool {
        guard let last = samples.last else { return false }
        let relevant = samples.filter { $0.0 >= last.0 - window - 0.03 }
        guard let first = relevant.first, last.0 - first.0 >= window else { return false }
        let xs = relevant.map { $0.1 }, ys = relevant.map { $0.2 }
        return (xs.max()! - xs.min()!) < tolerance && (ys.max()! - ys.min()!) < tolerance
    }
    mutating func reset() { samples.removeAll() }
}
