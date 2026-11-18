import Foundation
import CoreMotion

protocol MotionSource: AnyObject {
    var rotationTravel: Double { get }
    func start(_ receive: @escaping (Gravity, Double) -> Void)
    func stop()
}
final class CoreMotionSource: MotionSource {
    private let manager = CMMotionManager()
    private(set) var rotationTravel = 0.0
    private var previousTime: Double?
    var available: Bool { manager.isDeviceMotionAvailable }
    func start(_ receive: @escaping (Gravity, Double) -> Void) {
        previousTime = nil
        manager.deviceMotionUpdateInterval = 1.0 / 60
        manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let dt = self.previousTime.map { max(0, min(0.2, motion.timestamp - $0)) } ?? 0
            let rate = motion.rotationRate, g = motion.gravity
            let n = max(0.000001, sqrt(g.x * g.x + g.y * g.y + g.z * g.z))
            self.rotationTravel += (rate.x * g.x + rate.y * g.y + rate.z * g.z) / n * dt
            self.previousTime = motion.timestamp
            receive(Gravity(x: motion.gravity.x, y: motion.gravity.y, z: motion.gravity.z), motion.timestamp)
        }
    }
    func stop() { manager.stopDeviceMotionUpdates() }
    deinit { stop() }
}
final class SimulatedMotionSource: MotionSource {
    var gravity: Gravity
    var rotationTravel = 0.0
    private var timer: Timer?
    private var ticks = 0
    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        if let edge = Launch.value("-sim-edge", in: arguments).flatMap(Double.init) {
            gravity = Gravity(x: sin(edge * .pi / 180), y: -cos(edge * .pi / 180), z: 0)
        } else if let slope = Launch.value("-sim-slope", in: arguments).flatMap(Double.init) {
            gravity = .tilted(x: LevelMath.degrees(atan(slope / 100)), y: 0)
        } else if let pair = Launch.value("-sim-tilt", in: arguments)?.split(separator: ","), pair.count == 2,
                  let x = Double(pair[0]), let y = Double(pair[1]) { gravity = .tilted(x: x, y: -y) }
        else if Launch.value("-mode", in: arguments) == "camera", arguments.contains("-sim-camera") {
            gravity = Gravity(x: sin(1.6 * .pi / 180), y: -cos(1.6 * .pi / 180), z: 0)
        } else { gravity = .flat }
    }
    func start(_ receive: @escaping (Gravity, Double) -> Void) {
        stop(); ticks = 0
        receive(gravity, Date.timeIntervalSinceReferenceDate)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.ticks += 1
            let noise = sin(Double(self.ticks) * 0.08) * 0.000002
            let g = self.gravity
            receive(Gravity(x: g.x + noise, y: g.y + noise, z: g.z), Date.timeIntervalSinceReferenceDate)
        }
    }
    func stop() { timer?.invalidate(); timer = nil }
    deinit { stop() }
}
