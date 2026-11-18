import Foundation

enum TaskKind: String, Codable { case hanging, slopeTarget, angleTarget }
struct TaskPayload: Codable, Equatable {
    var version = 1
    var kind: TaskKind
    var hanging: HangingPlan?
    var target: Double?
    var preset: String?
    func validate() throws {
        guard version == 1 else { throw CodeError.invalid }
        switch kind {
        case .hanging:
            guard let plan = hanging, plan.name.count <= 100 else { throw CodeError.invalid }
            _ = try HangingPlanner.calculate(plan)
        case .slopeTarget:
            guard let target, target.isFinite, target >= 0, target <= 1000 else { throw CodeError.invalid }
        case .angleTarget:
            guard let target, target.isFinite, (0...180).contains(target) else { throw CodeError.invalid }
        }
        guard (preset?.count ?? 0) <= 100 else { throw CodeError.invalid }
    }
}
enum CodeError: Error { case invalid }
enum ShareCode {
    static let prefixes = ["水平仪·测量口令", "水平儀·測量口令", "Level · Task code"]
    static func encode(_ value: TaskPayload, prefix: String? = nil) throws -> String {
        try value.validate()
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        guard let packed = Zlib.pack(try encoder.encode(value)) else { throw CodeError.invalid }
        let token = packed.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        return (prefix ?? L.t("水平仪·测量口令")) + " " + token
    }
    static func decode(_ text: String) throws -> TaskPayload {
        guard text.count < 40000 else { throw CodeError.invalid }
        for prefix in prefixes {
            guard let range = text.range(of: prefix) else { continue }
            let rest = text[range.upperBound...]
            var token = ""
            var boundaries: Set<Int> = []
            for char in rest {
                if char.isWhitespace { if token.count >= 8 { boundaries.insert(token.count) }; continue }
                if char.isASCII && (char.isLetter || char.isNumber || char == "-" || char == "_") { token.append(char) }
                else if !token.isEmpty { break }
            }
            guard token.count >= 8, token.count <= 32768 else { continue }
            boundaries.insert(token.count)
            for length in boundaries.sorted().prefix(4096) {
                let candidate = String(token.prefix(length)).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
                let padded = candidate + String(repeating: "=", count: (4 - candidate.count % 4) % 4)
                guard let data = Data(base64Encoded: padded), let json = Zlib.unpack(data), let payload = try? JSONDecoder().decode(TaskPayload.self, from: json) else { continue }
                try payload.validate(); return payload
            }
        }
        throw CodeError.invalid
    }
}
