import SwiftUI
import StoreKit

struct Preferences: Codable {
    var unit = LengthUnit.regional
    var sound = true
    var voice = false
    var haptics = true
    var autoLock = false
    var precision = 0.1
    var tolerance = 0.1
    var textSize = 1
    var fixedPose: Pose?
    var singleTone = false
    var voiceHintSeen = false
    var openCount = 0
    var expiredNoticeSeen = false
}
enum Sheet: String, Identifiable {
    case settings, calibration, hanging, leveling, records, share, invite, paywall, importCode
    var id: String { rawValue }
}
@MainActor
final class AppModel: ObservableObject {
    @Published var preferences: Preferences { didSet { persist(preferences, key: "preferences") } }
    @Published var calibration: Calibration
    @Published var entitlement: Entitlement
    @Published var mode: MeasureMode = .level
    @Published var reading = LevelMath.read(.flat, pose: .flat)
    @Published var raw = Offset.zero
    @Published var rawGravity = Gravity.flat
    @Published var locked: Reading?
    @Published var automaticLock = false
    @Published var sheet: Sheet?
    @Published var records: [Measurement] = []
    @Published var selectedRecord: Measurement?
    @Published var savedRecord: Measurement?
    @Published var message: String?
    @Published var milestone: String?
    @Published var reviewSignal = 0
    @Published var pasteAvailable = false
    @Published var angleZero: Gravity? { didSet { persist(angleZero, key: "angleZero") } }
    @Published var zeroAxes: Offset? { didSet { persist(zeroAxes, key: "zeroAxes") } }
    @Published var supplementary = false
    @Published var target: Double?
    @Published var angleTarget: Double?
    @Published var targetName = ""
    @Published var importedTask: TaskPayload?
    @Published var hangingPlan = HangingPlan()
    @Published var shareCode: String?
    @Published var products: [Product] = []
    @Published var purchasing = false
    @Published var now = Date()
    @Published var calibrationStage = 0
    @Published var calibrationResult: CalibrationResult?
    @Published var accuracyGood: Bool?
    var calibrationPose: Pose = .flat
    var checking = false
    private var firstCalibration: Offset?
    private var calibrationStarted: Double = 0
    private var turned = false
    private var firstRotationTravel = 0.0
    private var stability = StabilityWindow()
    private var calibrationStability = StabilityWindow()
    private var detector = PoseDetector()
    private var smoother = Smoother()
    private var lastTime: Double?
    private var lastPasteChange = -1
    private var wasReached = false
    private var lockArmed = true
    private let defaults: UserDefaults
    private var store: RecordStore?
    private var storageFailed = false
    private var milestones: Milestones
    private var reviewGate: ReviewGate
    private var source: MotionSource
    private let tone = ToneEngine()
    private let voice = VoiceReader()
    private var transactionTask: Task<Void, Never>?
    let isolated: Bool
    let demo: Bool
    var hasPro: Bool { entitlement.hasPro(at: now) }
    var current: Reading {
        if var snapshot = locked { snapshot.rotation = reading.rotation; return snapshot }
        return relativeReading(reading)
    }
    var proID: String { Bundle.main.object(forInfoDictionaryKey: "LevelProProductID") as? String ?? "com.hgsldswk.level.pro" }
    var trialID: String { Bundle.main.object(forInfoDictionaryKey: "LevelTrialProductID") as? String ?? "com.hgsldswk.level.trial" }
    var signedAngle: Double {
        guard current.pose == .flat else { return current.angle }
        let direction = abs(current.x) >= abs(current.y) ? current.x : -current.y
        return direction < 0 ? -current.angle : current.angle
    }
    var zero: Double? { angleZero == nil ? nil : 0 }
    var primary: Double {
        switch mode {
        case .slope: return LevelMath.slope(signedAngle)
        case .angle:
            if let zero = angleZero { return LevelMath.angleBetween(lockedGravity ?? rawGravity, zero, supplementary: supplementary) }
            let a = abs(current.angle)
            return supplementary ? 180 - a : a
        case .plumb: return hypot(current.plumb, current.frontBack)
        default: return abs(current.angle)
        }
    }
    private var lockedGravity: Gravity?
    var error: Double {
        if mode == .slope, let target { return abs(primary) - target }
        if mode == .angle, let angleTarget { return primary - angleTarget }
        return primary
    }
    var errorTolerance: Double { mode == .slope && target != nil ? 0.1 : preferences.tolerance }
    var direction: String {
        if abs(error) <= errorTolerance {
            if mode == .level { return L.f("误差在 ±%@° 以内", L.number(preferences.tolerance, decimals: preferences.tolerance < 0.1 ? 2 : 1)) }
            return L.t("到了")
        }
        if mode == .slope, let target { return L.f("%@ · 还差 %@%%", abs(primary) < target ? L.t("还要再低一点") : L.t("坡度再小一点"), L.number(abs(abs(primary) - target))) }
        if mode == .angle, let angleTarget { return L.f("距离目标还差 %@°", L.number(abs(primary - angleTarget))) }
        return LevelMath.xDirection(current.x) + " " + L.number(abs(current.x)) + "° · " + LevelMath.yDirection(current.y) + " " + L.number(abs(current.y)) + "°"
    }
    init() {
        let args = ProcessInfo.processInfo.arguments
        demo = args.contains("-demo")
        isolated = demo || args.contains("-uitest-fresh") || args.contains("-sim-camera")
        let localDefaults = isolated ? UserDefaults(suiteName: "LevelTool.UITests")! : .standard
        defaults = localDefaults
        if isolated { localDefaults.removePersistentDomain(forName: "LevelTool.UITests") }
        func load<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
            localDefaults.data(forKey: key).flatMap { try? JSONDecoder().decode(type, from: $0) }
        }
        preferences = load(Preferences.self, "preferences") ?? Preferences()
        calibration = Calibration.load(from: defaults)
        entitlement = load(Entitlement.self, "entitlement") ?? Entitlement()
        milestones = load(Milestones.self, "milestones") ?? Milestones()
        reviewGate = load(ReviewGate.self, "reviewGate") ?? ReviewGate()
        angleZero = load(Gravity.self, "angleZero")
        zeroAxes = load(Offset.self, "zeroAxes")
        let live = CoreMotionSource()
        let simulated = args.contains(where: { $0.hasPrefix("-sim-") }) || isolated || !live.available
        if simulated { source = SimulatedMotionSource() } else { source = live }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = base.appendingPathComponent(isolated ? "LevelTool-UITests" : "LevelTool", isDirectory: true)
        do {
            if isolated && FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
            store = try RecordStore(directory: directory); records = store!.records
        } catch { storageFailed = true; message = L.t("记录未能读取，原文件已保留。请重启后重试。") }
        now = Date()
        if preferences.unit == .inch { hangingPlan.convert(to: .inch) }
        if !Launch.isFree && entitlement.proStartedAt == nil { entitlement.proStartedAt = now }
        if args.contains("-expired") { entitlement.proStartedAt = now.addingTimeInterval(-40 * 86400); entitlement.firstOpen = entitlement.proStartedAt! }
        preferences.openCount += 1
        if args.contains("-bigtext") { preferences.textSize = 2 }
        if let mode = Launch.value("-mode").flatMap(MeasureMode.init(rawValue:)) { self.mode = mode }
        target = Launch.value("-target").flatMap(Double.init)
        if demo { installDemo() }
        if args.contains("-locked") { locked = reading; automaticLock = true }
        for candidate in [Sheet.settings, .calibration, .hanging, .leveling, .records, .share, .invite, .paywall] {
            let flag = candidate == .calibration ? "-calibrate" : "-" + candidate.rawValue
            if args.contains(flag) { sheet = candidate }
        }
        if args.contains("-import") { receiveCode(try! ShareCode.encode(TaskPayload(kind: .hanging, hanging: hangingPlan))) }
        persist(entitlement, key: "entitlement")
        if !Launch.isFree && !isolated {
            transactionTask = Task { [weak self] in
                for await result in StoreKit.Transaction.updates {
                    guard !Task.isCancelled else { return }
                    if case .verified(let t) = result { await t.finish(); await self?.refreshPurchases() }
                }
            }
        }
    }
    private func persist<T: Encodable>(_ value: T, key: String) { if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) } }
    func active(_ active: Bool) {
        now = Date()
        if active && sheet == nil {
            source.start { [weak self] g, time in self?.update(g, time: time) }
            UIApplication.shared.isIdleTimerDisabled = true
        } else {
            if active && (sheet == .calibration || sheet == .leveling) { source.start { [weak self] g, time in self?.update(g, time: time) } }
            else { source.stop() }
            tone.stop(); voice.stop(); UIApplication.shared.isIdleTimerDisabled = false
        }
        if active { checkPaste() }
        if active && sheet == nil && locked != nil { requestQualifiedReview() }
    }
    private func relativeReading(_ r: Reading) -> Reading {
        guard mode != .angle, let axes = zeroAxes else { return r }
        var v = r; v.x -= axes.x; v.y -= axes.y
        v.angle = r.pose == .flat ? hypot(v.x, v.y) : r.angle - axes.x
        v.plumb = abs(v.x); v.frontBack = v.y
        return v
    }
    func update(_ gravity: Gravity, time: Double) {
        let dt = lastTime.map { max(0, min(time - $0, 0.2)) } ?? 1.0 / 60; lastTime = time
        let g = smoother.update(gravity, dt: dt); rawGravity = g
        let pose = preferences.fixedPose ?? detector.update(g)
        let rawReading = LevelMath.read(g, pose: pose, previousRotation: reading.rotation)
        raw = Offset(x: rawReading.x, y: rawReading.y)
        reading = LevelMath.read(g, pose: pose, offset: calibration.offset(for: pose), previousRotation: reading.rotation)
        stability.append(time: time, x: reading.x, y: reading.y)
        if sheet == .calibration { updateCalibration(time: time); return }
        guard sheet == nil else { return }
        let stable = stability.isStable(tolerance: 0.05)
        if !stable { lockArmed = true }
        if preferences.autoLock && locked == nil && stable && lockArmed { toggleLock(automatic: true) }
        if locked != nil && automaticLock && lockedGravity == nil { locked = relativeReading(reading); lockedGravity = rawGravity }
        if !isolated {
            if preferences.sound && locked == nil { tone.update(error: error, tolerance: errorTolerance, time: time, single: preferences.singleTone) }
            if preferences.voice && hasPro && stable { voice.read(mode == .slope ? L.f("坡度 %@%%", L.number(primary)) : direction, value: primary) }
            let reached = abs(error) <= errorTolerance
            if reached && !wasReached && preferences.haptics { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
            wasReached = reached
        }
        if (reading.faceDown || automaticLock) && !preferences.voiceHintSeen && !isolated {
            preferences.voiceHintSeen = true; message = L.t("可以在声音菜单打开语音读数")
        }
    }
    func toggleLock(automatic: Bool = false) {
        if locked != nil { locked = nil; lockedGravity = nil; automaticLock = false; lockArmed = false; stability.reset() }
        else {
            locked = relativeReading(reading); lockedGravity = rawGravity; automaticLock = automatic
            if !isolated {
                tone.stop(); if preferences.sound { tone.beep() }
                if preferences.haptics { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
            }
            requestQualifiedReview()
            if !Launch.isFree && !hasPro && !preferences.expiredNoticeSeen { preferences.expiredNoticeSeen = true; message = L.t("试用已结束，基本测量和已有记录照常可用。") }
        }
    }
    func selectMode(_ next: MeasureMode) {
        if next == .camera && !hasPro { sheet = .paywall; return }
        if let task = importedTask {
            let compatible = (task.kind == .hanging && next == .level) || (task.kind == .slopeTarget && next == .slope) || (task.kind == .angleTarget && next == .angle)
            if !compatible { importedTask = nil }
        }
        if let simulated = source as? SimulatedMotionSource, ProcessInfo.processInfo.arguments.contains("-sim-camera") {
            if next == .camera { simulated.gravity = Gravity(x: sin(1.6 * .pi / 180), y: -cos(1.6 * .pi / 180), z: 0) }
            else { simulated.gravity = SimulatedMotionSource().gravity }
        }
        locked = nil; lockedGravity = nil; automaticLock = false; mode = next; stability.reset(); lockArmed = true; shareCode = nil
    }
    func toggleZero() {
        if mode == .angle { angleZero = angleZero == nil ? rawGravity : nil }
        else { zeroAxes = zeroAxes == nil ? Offset(x: reading.x, y: reading.y) : nil }
        locked = nil; lockedGravity = nil
    }
    func requirePro(_ destination: Sheet) { sheet = hasPro ? destination : .paywall }
    func setTarget(_ value: Double, name: String) {
        guard hasPro else { sheet = .paywall; return }
        target = value; targetName = name; importedTask = nil
    }
    func saveMeasurement(name: String = "", plan: HangingPlan? = nil) {
        guard !storageFailed, let store else { message = L.t("无法保存记录，请先重启重试。"); return }
        let r = current
        var task = importedTask
        if task == nil, mode == .slope, let target { task = TaskPayload(kind: .slopeTarget, target: target, preset: targetName) }
        if task == nil, mode == .angle, let angleTarget { task = TaskPayload(kind: .angleTarget, target: angleTarget) }
        let record = Measurement(mode: mode, primary: primary, x: r.x, y: r.y, slope: LevelMath.slope(signedAngle), name: name, hanging: plan ?? task?.hanging, task: task)
        do {
            try store.upsert(record); records = store.records; savedRecord = record; selectedRecord = record; shareCode = nil
            milestone = milestones.recordSaved(); persist(milestones, key: "milestones")
        } catch { message = L.t("保存失败，请检查剩余空间后重试。") }
    }
    func updateRecord(_ record: Measurement) {
        do { try store?.upsert(record); records = store?.records ?? records; selectedRecord = record }
        catch { message = L.t("保存失败，请检查剩余空间后重试。") }
    }
    func deleteRecord(_ id: UUID) {
        do { try store?.delete(id); records = store?.records ?? records }
        catch { message = L.t("删除失败，请重试。") }
    }
    func photo(_ record: Measurement) -> UIImage? {
        guard let name = record.photoFileName, let url = store?.photoURL(name) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
    func attachPhoto(_ image: UIImage, record: Measurement) {
        guard hasPro else { sheet = .paywall; return }
        guard let data = image.jpegData(compressionQuality: 0.9) else { return }
        do { if let result = try store?.attach(data, to: record) { records = store!.records; selectedRecord = result } }
        catch { message = L.t("照片未能保存，请重试。") }
    }
    func exportCSV() -> URL? {
        guard let data = store?.csv() else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Level-measurements.csv")
        do { try data.write(to: url, options: .atomic); return url } catch { message = L.t("导出失败，请重试。"); return nil }
    }
    func checkPaste() {
        guard !isolated else { pasteAvailable = false; return }
        let p = UIPasteboard.general
        if p.changeCount != lastPasteChange { pasteAvailable = p.hasStrings; lastPasteChange = p.changeCount }
    }
    func receiveCode(_ text: String) {
        do {
            let payload = try ShareCode.decode(text); importedTask = payload; pasteAvailable = false
            switch payload.kind {
            case .hanging: hangingPlan = payload.hanging!; sheet = .hanging
            case .slopeTarget: selectMode(.slope); target = payload.target; targetName = payload.preset ?? L.t("收到的目标"); sheet = nil
            case .angleTarget: selectMode(.angle); angleTarget = payload.target; sheet = nil
            }
        } catch { message = L.t("没有识别到有效口令，请复制完整内容后再试。") }
    }
    func makeCode(_ payload: TaskPayload) {
        guard hasPro else { sheet = .paywall; return }
        do { shareCode = try ShareCode.encode(payload) } catch { message = L.t("参数无效，无法生成口令。") }
    }
    func completeWall() {
        shareCode = nil
        milestone = milestones.wallCompleted(); persist(milestones, key: "milestones")
        reviewGate.qualify(.firstWall); persist(reviewGate, key: "reviewGate")
        selectedRecord = Measurement(mode: .level, primary: 0, x: 0, y: 0, slope: 0, name: hangingPlan.name.isEmpty ? L.t("挂正了") : hangingPlan.name, hanging: hangingPlan)
    }
    private func requestQualifiedReview() {
        guard !isolated, reviewGate.consume(locked: locked != nil) != nil else { return }
        persist(reviewGate, key: "reviewGate"); reviewSignal += 1
    }
    func beginCalibration(pose: Pose, check: Bool = false) {
        calibrationPose = pose; checking = check; calibrationStage = 1; calibrationResult = nil; accuracyGood = nil
        calibrationStarted = 0; firstCalibration = nil; turned = false; calibrationStability.reset()
    }
    private func updateCalibration(time: Double) {
        guard calibrationStage == 1 || calibrationStage == 2 else { return }
        let g = rawGravity
        let r = LevelMath.read(g, pose: calibrationPose, offset: checking ? calibration.offset(for: calibrationPose) : .zero)
        if calibrationStage == 2 {
            if abs(source.rotationTravel - firstRotationTravel) > .pi * 0.8 { turned = true }
            guard turned, time - calibrationStarted > 1 else { return }
        }
        guard preferences.fixedPose == calibrationPose || detector.update(g) == calibrationPose else { calibrationStability.reset(); return }
        calibrationStability.append(time: time, x: r.x, y: r.y)
        guard calibrationStability.isStable(tolerance: 0.03) else { return }
        if calibrationStage == 1 {
            firstCalibration = Offset(x: r.x, y: r.y); firstRotationTravel = source.rotationTravel
            calibrationStage = 2; calibrationStarted = time; calibrationStability.reset()
            if let simulated = source as? SimulatedMotionSource {
                simulated.gravity = Gravity(x: -g.x, y: -g.y, z: g.z)
                simulated.rotationTravel += .pi
            }
            if !isolated && preferences.sound { tone.beep() }
        } else if let first = firstCalibration {
            let second = Offset(x: r.x, y: r.y)
            if checking {
                accuracyGood = Calibration.checkAccuracy(first, second)
                if accuracyGood == true && calibration.date(for: calibrationPose) != nil { reviewGate.qualify(.accurateCalibration); persist(reviewGate, key: "reviewGate") }
            } else {
                let result = Calibration.solve(first, second); calibrationResult = result
                calibration.set(result.offset, pose: calibrationPose)
                do { try calibration.save(to: defaults) } catch { message = L.t("校准未能保存，请重试。") }
            }
            calibrationStage = 3
            if !isolated && preferences.sound { tone.beep(duration: 0.3) }
        }
    }
    func resetCalibration() { calibration = Calibration(); try? calibration.save(to: defaults); calibrationStage = 0 }
    private func installDemo() {
        calibration.set(Offset(x: 0, y: 0), pose: .flat); calibration.set(.zero, pose: .edge)
        hangingPlan.name = L.t("客厅照片墙")
        for i in 0..<12 {
            var r = Measurement(mode: i % 3 == 0 ? .slope : .level, primary: i % 3 == 0 ? 1.8 : 0.3, x: 0.21, y: -0.18, slope: 1.8, name: i % 2 == 0 ? L.t("客厅搁板") : L.t("客厅照片墙"), date: now.addingTimeInterval(Double(-i) * 3600))
            if i < 2 { r.hanging = hangingPlan }
            try? store?.upsert(r)
            if i < 2, let data = UIImage(named: "DemoWall")?.jpegData(compressionQuality: 0.9) { _ = try? store?.attach(data, to: r) }
        }
        records = store?.records ?? []; selectedRecord = records.first
    }
    func loadProducts() async {
        guard !isolated, !Launch.isFree else { return }
        do { products = try await Product.products(for: [proID, trialID]) }
        catch { message = L.t("暂时无法加载商品，请稍后重试。") }
    }
    func refreshPurchases() async {
        guard !isolated, !Launch.isFree else { return }
        var pro = false
        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let t) = result, t.revocationDate == nil else { continue }
            if t.productID == proID { pro = true }
            if t.productID == trialID { entitlement.trialClaimedAt = min(entitlement.trialClaimedAt ?? t.originalPurchaseDate, t.originalPurchaseDate) }
        }
        entitlement.purchasedPro = pro; now = Date(); persist(entitlement, key: "entitlement")
    }
    func purchase(_ id: String) async {
        guard !purchasing, let product = products.first(where: { $0.id == id }), !isolated, !Launch.isFree else { return }
        purchasing = true; defer { purchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let result):
                guard case .verified(let t) = result else { message = L.t("购买未通过验证，请稍后恢复购买。"); return }
                await t.finish(); await refreshPurchases()
            case .pending: message = L.t("购买正在等待确认。")
            case .userCancelled: break
            @unknown default: break
            }
        } catch { message = L.t("购买未完成，请稍后重试。") }
    }
    func restorePurchases() async {
        guard !isolated, !Launch.isFree else { return }
        do { try await AppStore.sync(); await refreshPurchases() } catch { message = L.t("恢复购买未完成，请稍后重试。") }
    }
}
