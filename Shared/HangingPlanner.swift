import Foundation

enum LengthUnit: String, Codable, CaseIterable {
    case cm, inch
    var symbol: String { self == .cm ? "cm" : "in" }
    var mm: Double { self == .cm ? 10 : 25.4 }
    static var regional: LengthUnit { Locale.current.region?.identifier == "US" ? .inch : .cm }
}
struct FrameSize: Codable, Equatable { var width: Double; var height: Double }
struct HangingPlan: Codable, Equatable {
    var wallWidth: Double = 240
    var frames: [FrameSize] = Array(repeating: FrameSize(width: 30, height: 40), count: 4)
    var gap: Double?
    var hookDrop: Double = 5
    var centerHeight: Double = 145
    var unit: LengthUnit = .cm
    var name: String = ""
    mutating func convert(to unit: LengthUnit) {
        let factor = self.unit.mm / unit.mm
        wallWidth *= factor; hookDrop *= factor; centerHeight *= factor
        gap = gap.map { $0 * factor }
        frames = frames.map { FrameSize(width: $0.width * factor, height: $0.height * factor) }
        self.unit = unit
    }
}
struct NailPosition: Equatable {
    var left: Double
    var top: Double
    var nailX: Double
    var nailHeight: Double
}
enum PlannerError: Error, Equatable { case invalidInput; case insufficientWidth(Double) }
enum HangingPlanner {
    static func calculate(_ p: HangingPlan) throws -> [NailPosition] {
        let numbers: [Double] = [p.wallWidth, p.hookDrop, p.centerHeight] + p.frames.flatMap { [$0.width, $0.height] } + [p.gap ?? 0]
        guard numbers.allSatisfy({ $0.isFinite && $0 >= 0 && $0 < 1_000_000 }), p.wallWidth > 0,
              !p.frames.isEmpty, p.frames.count <= 50, p.frames.allSatisfy({ $0.width > 0 && $0.height > 0 && p.hookDrop <= $0.height }) else { throw PlannerError.invalidInput }
        let total = p.frames.reduce(0) { $0 + $1.width }
        let count = Double(p.frames.count)
        let used = total + (p.gap ?? 0) * (count - 1)
        guard used <= p.wallWidth else { throw PlannerError.insufficientWidth(used - p.wallWidth) }
        let gap = p.gap ?? (p.wallWidth - total) / (count + 1)
        var left = p.gap == nil ? gap : (p.wallWidth - used) / 2
        return p.frames.map { frame in
            let top = p.centerHeight + frame.height / 2
            let result = NailPosition(left: left, top: top, nailX: left + frame.width / 2, nailHeight: top - p.hookDrop)
            left += frame.width + gap
            return result
        }
    }
}
