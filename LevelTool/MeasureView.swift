import SwiftUI

struct MeasureView: View {
    @EnvironmentObject var model: AppModel
    @State private var customTarget = false
    @State private var customValue = "2"
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 10) {
                header
                if model.pasteAvailable { CodeImportBanner() }
                if model.mode == .camera {
                    CameraView().frame(maxHeight: .infinity)
                } else {
                    status
                    ScrollView {
                        VStack(spacing: 10) {
                            if model.mode == .level {
                                VStack(spacing: 10) { instrument(available: geometry.size.height) }.frame(maxWidth: .infinity).contentShape(Rectangle()).onTapGesture { model.toggleLock() }.accessibilityElement(children: .contain).accessibilityIdentifier("measurement.area")
                            } else { instrument(available: geometry.size.height) }
                            if model.current.faceDown { Text(L.t("屏幕朝下，读数用声音播报")).font(.caption).foregroundStyle(D.secondary) }
                        }.frame(maxWidth: .infinity)
                    }.scrollIndicators(.hidden)
                    if !model.isolated && model.preferences.openCount <= 3 && model.calibration.date(for: model.current.pose) == nil {
                        Button(L.t("平放或靠边都能量 · 先校准更准")) { model.sheet = .calibration }.font(.caption).accessibilityIdentifier("calibration.hint")
                    }
                    if let saved = model.savedRecord {
                        HStack {
                            Button(L.t("已保存 · 加名称或照片")) { model.selectedRecord = saved; model.sheet = .records }.accessibilityIdentifier("saved.edit")
                            Spacer()
                            Button(L.t("分享")) { model.selectedRecord = saved; model.sheet = .share }.accessibilityIdentifier("saved.share")
                        }.font(.caption).padding(10).background(D.tint, in: RoundedRectangle(cornerRadius: 12))
                    }
                    if let milestone = model.milestone { MilestoneBar(text: milestone) }
                    if let message = model.message {
                        HStack { Text(message).font(.caption); Spacer(); Button { model.message = nil } label: { Image(systemName: "xmark") }.accessibilityIdentifier("message.close") }.padding(10).background(D.tint, in: RoundedRectangle(cornerRadius: 12))
                    }
                    bottomBar
                }
            }.padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 8)
        }.background(D.bg).foregroundStyle(D.ink)
            .alert(L.t("自定义目标"), isPresented: $customTarget) {
                TextField(L.t("坡度 %"), text: $customValue).keyboardType(.decimalPad)
                Button(L.t("设置")) { if let value = Double(customValue.replacingOccurrences(of: ",", with: ".")), value >= 0 && value <= 1000 { model.setTarget(value, name: L.t("自定义")) } }
                Button(L.t("取消"), role: .cancel) { }
            }
    }
    private var header: some View {
        HStack(spacing: 10) {
            HStack(spacing: 2) {
                ForEach(MeasureMode.allCases, id: \.self) { mode in
                    Button { model.selectMode(mode) } label: {
                        Text(mode.title).font(.system(size: 14, weight: model.mode == mode ? .semibold : .regular)).lineLimit(1).minimumScaleFactor(0.6)
                            .frame(maxWidth: .infinity).frame(minHeight: 40).background(model.mode == mode ? D.ink : .clear, in: RoundedRectangle(cornerRadius: 11))
                            .foregroundStyle(model.mode == mode ? D.bg : D.secondary)
                    }.accessibilityIdentifier("mode." + mode.rawValue)
                }
            }.padding(3).background(D.card, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(D.line, lineWidth: 0.6))
            Button { model.sheet = .settings } label: { Image(systemName: "gearshape").font(.system(size: 20)).frame(width: 44, height: 44).background(D.card, in: Circle()).overlay(Circle().stroke(D.line, lineWidth: 0.6)) }.accessibilityIdentifier("settings")
        }
    }
    private var status: some View {
        HStack(spacing: 6) {
            Pill(text: model.current.pose == .flat ? L.t("平放") : L.t("靠边"))
            Button { model.sheet = .calibration } label: {
                Pill(text: model.calibration.date(for: model.current.pose).map { L.t("已校准") + " · " + $0.formatted(.dateTime.month().day()) } ?? L.t("未校准 · 点此校准"))
            }.accessibilityIdentifier("calibration.status")
            if model.locked != nil { Pill(text: model.automaticLock ? L.t("已锁定 · 自动") : L.t("已锁定 · 手动"), active: true).accessibilityIdentifier("locked.status") }
        }.minimumScaleFactor(0.7).lineLimit(1)
    }
    @ViewBuilder private func instrument(available: CGFloat) -> some View {
        switch model.mode {
        case .level:
            if model.current.pose == .flat {
                DialView(x: model.current.x, y: model.current.y, reached: abs(model.error) <= model.errorTolerance).frame(maxWidth: min(350, max(220, available * 0.40)))
                readout
                HStack(spacing: 10) {
                    MetricCard(title: L.t("左右 X"), value: L.number(model.current.x, decimals: 2) + "°")
                    MetricCard(title: L.t("前后 Y"), value: L.number(model.current.y, decimals: 2) + "°")
                }.padding(.horizontal, 25)
            } else {
                Spacer().frame(height: 24); Text(L.t("水平")).font(.subheadline).foregroundStyle(D.secondary)
                readout.padding(.vertical, 15)
                VialView(angle: model.current.angle, reached: abs(model.error) <= model.errorTolerance)
                Text(L.t("提示音、语音读数与震动可分别设置")).font(.caption).foregroundStyle(D.secondary)
            }
        case .slope: SlopePanel(customTarget: $customTarget)
        case .angle: AnglePanel()
        case .plumb: PlumbPanel()
        case .camera: EmptyView()
        }
    }
    private var readout: some View {
        VStack(spacing: 4) {
            Text(L.number((model.primary / effectivePrecision).rounded() * effectivePrecision, decimals: effectivePrecision == 0.05 ? 2 : 1) + "°")
                .font(D.digits(readingSize)).foregroundStyle(abs(model.error) <= model.errorTolerance ? D.accent : D.ink).minimumScaleFactor(0.5).lineLimit(1).accessibilityIdentifier("reading.primary")
            Text(model.direction).font(.system(size: 14)).foregroundStyle(D.secondary).multilineTextAlignment(.center)
        }.rotationEffect(.degrees(Double(model.current.rotation))).frame(minHeight: 125)
    }
    private var effectivePrecision: Double { model.hasPro ? model.preferences.precision : 0.1 }
    private var readingSize: CGFloat { CGFloat([72, model.current.pose == .edge ? 104 : 88, 112][max(0, min(2, model.preferences.textSize))]) }
    private var bottomBar: some View {
        HStack(spacing: 8) {
            barButton(L.t("校准"), "arrow.triangle.2.circlepath", id: "calibrate") { model.sheet = .calibration }
            barButton(model.locked == nil ? L.t("锁定") : L.t("解锁"), model.locked == nil ? "lock" : "lock.open", id: "lock", selected: model.locked != nil) { model.toggleLock() }
            if model.locked != nil {
                Button { model.saveMeasurement() } label: { Label(L.t("保存这次读数"), systemImage: "square.and.arrow.down").font(.system(size: 14)).frame(maxWidth: .infinity).frame(minHeight: 64) }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("save")
            } else {
                barButton(L.t("声音"), model.preferences.sound ? "speaker.wave.2" : "speaker.slash", id: "sound", selected: model.preferences.sound) { model.preferences.sound.toggle() }
                    .contextMenu {
                        Toggle(L.t("提示音"), isOn: $model.preferences.sound)
                        Button { if model.hasPro { model.preferences.voice.toggle() } else { model.sheet = .paywall } } label: { Label(L.t("语音读数"), systemImage: model.preferences.voice ? "checkmark" : "waveform") }
                        Toggle(L.t("震动"), isOn: $model.preferences.haptics)
                    }
                if model.mode == .slope {
                    barButton(L.t("发给师傅"), "square.and.arrow.up", id: "slope.share") {
                        model.makeCode(TaskPayload(kind: .slopeTarget, target: model.target ?? abs(model.primary), preset: model.targetName)); if model.hasPro { model.sheet = .share }
                    }
                } else {
                    barButton(model.zero != nil || model.zeroAxes != nil ? L.t("清除零点") : L.t("设为零点"), "plus.circle", id: "zero") { model.toggleZero() }
                }
            }
        }
    }
    private func barButton(_ title: String, _ icon: String, id: String, selected: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 7) { Image(systemName: icon).font(.system(size: 21)); Text(title).font(.system(size: 11)).lineLimit(1).minimumScaleFactor(0.65) }
                .frame(maxWidth: .infinity).frame(minHeight: 64).background(selected ? D.ink : D.card, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(selected ? D.bg : D.secondary).overlay(RoundedRectangle(cornerRadius: 16).stroke(D.line, lineWidth: 0.6))
        }.accessibilityIdentifier(id)
    }
}

struct SlopePanel: View {
    @EnvironmentObject var model: AppModel
    @Binding var customTarget: Bool
    @State private var format = 0
    private var angle: Double { model.signedAngle }
    private var value: String {
        switch format {
        case 1: return L.number(abs(LevelMath.mmPerMeter(angle))) + " mm/m"
        case 2: return LevelMath.ratio(angle).map { "1 : " + L.number(abs($0), decimals: 0) } ?? "1 : ∞"
        case 3: return L.number(abs(LevelMath.roofPitch(angle))) + "/12"
        case 4: return L.number(abs(angle)) + "°"
        default: return L.number(abs(model.primary)) + "%"
        }
    }
    var body: some View {
        VStack(spacing: 12) {
            SlopeDiagram(slope: model.primary)
            Text(L.t("坡度")).font(.subheadline).foregroundStyle(D.secondary)
            Button { format = (format + 1) % 5 } label: { Text(value).font(D.digits(88)).lineLimit(1).minimumScaleFactor(0.4).foregroundStyle(abs(model.error) <= model.errorTolerance ? D.accent : D.ink) }.rotationEffect(.degrees(Double(model.current.rotation))).accessibilityIdentifier("reading.primary")
            Text(model.direction).font(.system(size: 14)).foregroundStyle(D.secondary).accessibilityIdentifier("slope.delta")
            HStack(spacing: 8) {
                MetricCard(title: L.t("每米高差"), value: L.number(abs(model.primary) * 10, decimals: 0) + " mm")
                MetricCard(title: L.t("比例"), value: LevelMath.ratio(angle).map { "1 : " + L.number(abs($0), decimals: 0) } ?? "∞")
                MetricCard(title: L.t("角度"), value: L.number(abs(angle), decimals: 2) + "°")
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(model.target.map { L.f("目标 %@%%", L.number($0)) } ?? L.t("目标坡度")).font(.headline)
                    Spacer(); Text(model.targetName).font(.caption).foregroundStyle(D.secondary)
                    if model.target != nil { Button { model.target = nil; model.targetName = ""; model.importedTask = nil } label: { Image(systemName: "xmark.circle").accessibilityLabel(L.t("清除目标")) }.accessibilityIdentifier("target.clear") }
                }
                if let target = model.target { TargetTrack(current: abs(model.primary), target: target) }
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        preset("阳台 1%", 1); preset("地漏 2%", 2); preset("坡道 1:12", 100 / 12); preset("屋顶 4/12", 100 / 3)
                        Button { if model.hasPro { customTarget = true } else { model.sheet = .paywall } } label: { Pill(text: L.t("自定义")) }.accessibilityIdentifier("target.custom")
                    }
                }.scrollIndicators(.hidden)
            }.card()
        }
    }
    private func preset(_ key: String, _ value: Double) -> some View {
        Button { model.setTarget(value, name: L.t(key)) } label: { Pill(text: L.t(key), active: model.target == value) }.accessibilityIdentifier("target." + String(Int(value)))
    }
}
struct TargetTrack: View {
    var current: Double
    var target: Double
    var body: some View {
        GeometryReader { g in
            let maximum = max(4, target * 2), width = g.size.width
            ZStack(alignment: .leading) {
                Rectangle().fill(D.line2).frame(height: 2)
                Capsule().fill(D.tint).overlay(Capsule().stroke(D.accentSoft, lineWidth: 1)).frame(width: max(15, width * 0.3 / maximum), height: 14).offset(x: width * CGFloat(target / maximum) - 7)
                Capsule().fill(D.ink).frame(width: 3, height: 26).offset(x: width * CGFloat(min(maximum, current) / maximum))
            }.frame(height: 34)
        }.frame(height: 34)
    }
}
struct AnglePanel: View {
    @EnvironmentObject var model: AppModel
    @State private var targetInput = "22.5"
    @State private var targetEditor = false
    var body: some View {
        VStack(spacing: 24) {
            DialView(x: model.current.x, y: model.current.y, reached: abs(model.error) <= model.errorTolerance).frame(maxWidth: 280)
            Text(L.number(model.primary) + "°").font(D.digits(88)).minimumScaleFactor(0.5).rotationEffect(.degrees(Double(model.current.rotation))).onTapGesture { model.toggleLock() }.accessibilityIdentifier("reading.primary")
            Text(model.zero == nil ? L.t("相对水平") : L.t("相对零点")).foregroundStyle(D.secondary)
            Toggle(L.t("显示补角"), isOn: $model.supplementary).accessibilityIdentifier("angle.supplementary").card()
            HStack {
                Button(model.angleTarget.map { L.f("目标 %@°", L.number($0)) } ?? L.t("目标角度")) { if model.hasPro { targetEditor = true } else { model.sheet = .paywall } }.accessibilityIdentifier("angle.target")
                if model.angleTarget != nil { Text(model.direction).font(.caption).foregroundStyle(D.accent); Button(L.t("清除目标")) { model.angleTarget = nil; model.importedTask = nil }.font(.caption).accessibilityIdentifier("angle.clearTarget") }
            }
            Button(L.t("发给师傅")) { model.makeCode(TaskPayload(kind: .angleTarget, target: model.angleTarget ?? model.primary)); if model.hasPro { model.sheet = .share } }.accessibilityIdentifier("angle.share")
        }.padding(.top, 15)
            .alert(L.t("目标角度"), isPresented: $targetEditor) {
                TextField(L.t("角度"), text: $targetInput).keyboardType(.decimalPad)
                Button(L.t("设置")) { if let value = Double(targetInput.replacingOccurrences(of: ",", with: ".")), (0...180).contains(value) { model.angleTarget = value; model.importedTask = nil } }
                Button(L.t("取消"), role: .cancel) {}
            }
    }
}
struct PlumbPanel: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(spacing: 18) {
            Text(L.t("偏离垂直")).foregroundStyle(D.secondary).padding(.top, 25)
            Text(L.number(model.primary) + "°").font(D.digits(88)).foregroundStyle(model.primary <= model.preferences.tolerance ? D.accent : D.ink).accessibilityIdentifier("reading.primary")
            Text(L.t("手机侧边贴住门框或墙面")).font(.caption).foregroundStyle(D.secondary)
            Text(L.t("左右")).font(.caption); VialView(angle: model.current.plumb, reached: model.current.plumb <= model.preferences.tolerance)
            Text(L.t("前后")).font(.caption); VialView(angle: model.current.frontBack, reached: abs(model.current.frontBack) <= model.preferences.tolerance)
        }.rotationEffect(.degrees(Double(model.current.rotation)))
    }
}
struct CodeImportBanner: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        HStack {
            Text(L.t("打开收到的测量方案？")).font(.caption)
            Spacer()
            PasteButton(payloadType: String.self) { values in if let text = values.first { model.receiveCode(text) } }.labelStyle(.iconOnly).accessibilityIdentifier("code.paste")
            Button { model.pasteAvailable = false } label: { Image(systemName: "xmark").font(.caption) }.accessibilityIdentifier("code.dismiss")
        }.padding(10).background(D.tint, in: RoundedRectangle(cornerRadius: 12))
    }
}
struct MilestoneBar: View {
    @EnvironmentObject var model: AppModel
    var text: String
    var body: some View {
        HStack {
            Button(text) { model.sheet = .share }.font(.caption).accessibilityIdentifier("milestone.share")
            Spacer(); Button { model.milestone = nil } label: { Image(systemName: "xmark") }.accessibilityIdentifier("milestone.close")
        }.padding(10).background(D.tint, in: RoundedRectangle(cornerRadius: 12))
    }
}
