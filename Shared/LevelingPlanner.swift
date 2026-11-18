import Foundation

enum LevelingStrategy: String, CaseIterable { case minimum, raiseOnly }
struct FootAdjustment: Equatable { var corner: Int; var amount: Double }
enum LevelingPlanner {
    static func calculate(length: Double, width: Double, x: Double, y: Double, strategy: LevelingStrategy, inches: Bool = false) throws -> [FootAdjustment] {
        guard [length, width, x, y].allSatisfy(\.isFinite), length > 0, width > 0, abs(x) < 89, abs(y) < 89 else { throw PlannerError.invalidInput }
        let tx = tan(x * .pi / 180), ty = tan(y * .pi / 180)
        let heights = [tx * width / 2 - ty * length / 2, -tx * width / 2 - ty * length / 2,
                       tx * width / 2 + ty * length / 2, -tx * width / 2 + ty * length / 2]
        let reference = strategy == .raiseOnly ? heights.max()! : 0
        return heights.enumerated().map { FootAdjustment(corner: $0.offset, amount: (reference - $0.element) / (inches ? 25.4 : 1)) }
    }
}
