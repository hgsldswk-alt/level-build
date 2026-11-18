import Foundation

struct Milestones: Codable {
    var savedCount = 0
    var walls = 0
    var shown: Set<String> = []
    mutating func recordSaved() -> String? { savedCount += 1; return consume("records", savedCount, [10, 50, 100]) }
    mutating func wallCompleted() -> String? { walls += 1; return consume("walls", walls, [1, 5, 10]) }
    private mutating func consume(_ type: String, _ count: Int, _ values: [Int]) -> String? {
        let key = type + ":" + String(count)
        guard values.contains(count), shown.insert(key).inserted else { return nil }
        return type == "walls" ? L.f("你已经用它挂正了 %d 面墙", count) : L.f("已保存 %d 条测量记录", count)
    }
}
enum ReviewCondition: String, Codable { case accurateCalibration, firstWall }
struct ReviewGate: Codable {
    var requested: Set<ReviewCondition> = []
    var pending: Set<ReviewCondition> = []
    mutating func qualify(_ condition: ReviewCondition) { if !requested.contains(condition) { pending.insert(condition) } }
    mutating func consume(locked: Bool) -> ReviewCondition? {
        guard locked, let condition = pending.sorted(by: { $0.rawValue < $1.rawValue }).first else { return nil }
        pending.remove(condition); requested.insert(condition); return condition
    }
}
