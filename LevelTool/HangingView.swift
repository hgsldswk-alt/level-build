import SwiftUI

struct HangingView: View {
    @EnvironmentObject var model: AppModel
    @State private var codeShown = false
    @State private var completed = false
    private var readOnly: Bool { !model.hasPro }
    private var result: Result<[NailPosition], Error> { Result { try HangingPlanner.calculate(model.hangingPlan) } }
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if readOnly { Text(L.t("收到的方案可以查看和对齐")).font(.caption).foregroundStyle(D.secondary) }
                VStack(spacing: 12) {
                    TextField(L.t("方案名称"), text: $model.hangingPlan.name).accessibilityIdentifier("hanging.name")
                    Picker(L.t("单位"), selection: Binding(get: { model.hangingPlan.unit }, set: { model.hangingPlan.convert(to: $0) })) {
                        Text("cm").tag(LengthUnit.cm); Text("in").tag(LengthUnit.inch)
                    }.pickerStyle(.segmented).accessibilityIdentifier("hanging.unit")
                    numberField("墙宽", value: $model.hangingPlan.wallWidth)
                    Stepper(L.f("%d 幅画", model.hangingPlan.frames.count), value: Binding(get: { model.hangingPlan.frames.count }, set: { count in
                        let frame = model.hangingPlan.frames.last ?? FrameSize(width: 30, height: 40)
                        if count > model.hangingPlan.frames.count { model.hangingPlan.frames.append(frame) }
                        else { model.hangingPlan.frames = Array(model.hangingPlan.frames.prefix(count)) }
                    }), in: 1...12).frame(minHeight: 44).accessibilityIdentifier("hanging.count")
                    ForEach(model.hangingPlan.frames.indices, id: \.self) { i in
                        HStack {
                            Text(String(i + 1)).foregroundStyle(D.muted)
                            numberField("画宽", value: $model.hangingPlan.frames[i].width)
                            numberField("画高", value: $model.hangingPlan.frames[i].height)
                        }
                    }
                    Toggle(L.t("自动均分间距"), isOn: Binding(get: { model.hangingPlan.gap == nil }, set: { model.hangingPlan.gap = $0 ? nil : 10 })).accessibilityIdentifier("hanging.autoGap")
                    if model.hangingPlan.gap != nil { numberField("间距", value: Binding(get: { model.hangingPlan.gap ?? 10 }, set: { model.hangingPlan.gap = $0 })) }
                    numberField("挂钩到上沿", value: $model.hangingPlan.hookDrop)
                    numberField("中心离地", value: $model.hangingPlan.centerHeight)
                }.disabled(readOnly).card()
                switch result {
                case .success(let positions):
                    HangingDiagram(plan: model.hangingPlan, positions: positions).accessibilityIdentifier("hanging.diagram")
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L.t("钉子位置")).font(.headline)
                        ForEach(positions.indices, id: \.self) { i in
                            HStack {
                                Text(String(i + 1)).frame(width: 20)
                                Text(L.f("离左边 %@ %@", L.number(positions[i].nailX), model.hangingPlan.unit.symbol))
                                Spacer()
                                Text(L.f("离地 %@ %@", L.number(positions[i].nailHeight), model.hangingPlan.unit.symbol))
                            }.font(.system(size: 13, design: .rounded)).accessibilityIdentifier("hanging.nail." + String(i))
                        }
                    }.card().accessibilityElement(children: .contain).accessibilityIdentifier("hanging.results")
                    Button(L.t("去对齐")) { model.selectMode(.level); model.importedTask = TaskPayload(kind: .hanging, hanging: model.hangingPlan); model.sheet = nil }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("hanging.align")
                    HStack {
                        Button(L.t("保存")) { model.saveMeasurement(name: model.hangingPlan.name, plan: model.hangingPlan) }.frame(maxWidth: .infinity, minHeight: 56).accessibilityIdentifier("hanging.save")
                        Button(L.t("发给家人")) {
                            model.makeCode(TaskPayload(kind: .hanging, hanging: model.hangingPlan)); codeShown = model.shareCode != nil
                        }.frame(maxWidth: .infinity, minHeight: 56).disabled(readOnly).accessibilityIdentifier("hanging.share")
                    }
                    Button(L.t("挂好了")) { model.completeWall(); completed = true }.frame(minHeight: 56).accessibilityIdentifier("hanging.complete")
                case .failure(let error):
                    Text(errorMessage(error)).foregroundStyle(D.secondary).card().accessibilityIdentifier("hanging.error")
                }
            }.padding(20)
        }.background(D.bg).navigationTitle(L.t("挂画助手"))
            .sheet(isPresented: $codeShown) {
                NavigationStack {
                    ScrollView { VStack(spacing: 16) {
                        GeometryReader { g in ShareCardView(record: shareRecord, image: nil, showBrand: true).scaleEffect(g.size.width / 390, anchor: .topLeading) }.aspectRatio(390 / 487.5, contentMode: .fit)
                        if let code = model.shareCode { Text(code).textSelection(.enabled).font(.caption).accessibilityIdentifier("code.generated"); ShareLink(item: code, subject: Text(L.t("挂画方案")), message: Text(L.t("复制整段，在水平仪 App 里打开"))).accessibilityIdentifier("code.share") }
                    }.padding() }.navigationTitle(L.t("发给家人")).toolbar { Button(L.t("完成")) { codeShown = false } }
                }
            }
            .sheet(isPresented: $completed) { NavigationStack { ShareView().navigationTitle(L.t("挂正了")).toolbar { Button(L.t("完成")) { completed = false } } }.environmentObject(model) }
    }
    private var shareRecord: Measurement { Measurement(mode: .level, primary: 0, x: 0, y: 0, slope: 0, name: model.hangingPlan.name, hanging: model.hangingPlan) }
    private func numberField(_ key: String, value: Binding<Double>) -> some View {
        HStack { Text(L.t(key)).font(.subheadline); Spacer(); TextField(L.t(key), value: value, format: .number.precision(.fractionLength(0...2))).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(maxWidth: 100).accessibilityIdentifier("hanging." + key); Text(model.hangingPlan.unit.symbol).font(.caption).foregroundStyle(D.muted) }.frame(minHeight: 38)
    }
    private func errorMessage(_ error: Error) -> String {
        if case PlannerError.insufficientWidth(let missing) = error { return L.f("墙宽还缺 %@ %@", L.number(missing), model.hangingPlan.unit.symbol) }
        return L.t("请填写有效尺寸，挂钩距离不能超过画高。")
    }
}
