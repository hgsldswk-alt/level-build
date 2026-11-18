import Foundation

enum MeasureMode: String, Codable, CaseIterable {
    case level, slope, angle, plumb, camera
    var title: String {
        switch self {
        case .level: return L.t("水平")
        case .slope: return L.t("坡度")
        case .angle: return L.t("角度")
        case .plumb: return L.t("铅垂")
        case .camera: return L.t("取景")
        }
    }
}
struct Measurement: Codable, Equatable, Identifiable {
    var id = UUID()
    var mode: MeasureMode
    var primary: Double
    var x: Double
    var y: Double
    var slope: Double
    var name = ""
    var notes = ""
    var photoFileName: String?
    var date = Date()
    var hanging: HangingPlan?
    var task: TaskPayload?
    var displayValue: String { L.number(primary) + (mode == .slope ? "%" : "°") }
}
final class RecordStore {
    let directory: URL
    private(set) var records: [Measurement]
    init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("records.json")
        records = FileManager.default.fileExists(atPath: file.path) ? try JSONDecoder().decode([Measurement].self, from: Data(contentsOf: file)) : []
    }
    private func persist(_ next: [Measurement]) throws {
        try JSONEncoder().encode(next).write(to: directory.appendingPathComponent("records.json"), options: .atomic)
        records = next
    }
    func upsert(_ record: Measurement) throws {
        var next = records.filter { $0.id != record.id }; next.append(record)
        try persist(next.sorted { $0.date > $1.date })
    }
    func delete(_ id: UUID) throws {
        let photo = records.first { $0.id == id }?.photoFileName
        try persist(records.filter { $0.id != id })
        if let photo, let url = photoURL(photo) { try? FileManager.default.removeItem(at: url) }
    }
    func search(_ query: String) -> [Measurement] {
        records.filter { query.isEmpty || ($0.name + " " + $0.notes + " " + $0.mode.title).localizedCaseInsensitiveContains(query) }.sorted { $0.date > $1.date }
    }
    func photoURL(_ name: String) -> URL? {
        guard name == URL(fileURLWithPath: name).lastPathComponent, name.hasSuffix(".jpg") else { return nil }
        return directory.appendingPathComponent(name)
    }
    func attach(_ jpg: Data, to record: Measurement) throws -> Measurement {
        var updated = record
        let name = UUID().uuidString + ".jpg"
        let url = directory.appendingPathComponent(name)
        try jpg.write(to: url, options: .atomic)
        updated.photoFileName = name
        do { try upsert(updated) } catch { try? FileManager.default.removeItem(at: url); throw error }
        if let old = record.photoFileName, let oldURL = photoURL(old) { try? FileManager.default.removeItem(at: oldURL) }
        return updated
    }
    func csv() -> Data {
        func quote(_ value: String) -> String {
            var safe = value
            if let first = safe.first, "=+-@\t\r".contains(first) { safe = "'" + safe }
            return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        let header = ["id", "mode", "primary", "x", "y", "slope_percent", "name", "notes", "date"]
        let iso = ISO8601DateFormatter()
        let rows = records.map { r in [r.id.uuidString, r.mode.rawValue, String(r.primary), String(r.x), String(r.y), String(r.slope), r.name, r.notes, iso.string(from: r.date)].map(quote).joined(separator: ",") }
        return Data((["\u{FEFF}" + header.joined(separator: ",")] + rows).joined(separator: "\r\n").utf8)
    }
}
