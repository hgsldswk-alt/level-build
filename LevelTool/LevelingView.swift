import SwiftUI

struct LevelingView: View {
    @EnvironmentObject var model: AppModel
    @State private var length = 60.0
    @State private var width = 60.0
    @State private var unit = LengthUnit.cm
    @State private var strategy = LevelingStrategy.minimum
    private let corners = ["左前脚", "右前脚", "左后脚", "右后脚"]
    private var adjustments: [FootAdjustment]? {
        try? LevelingPlanner.calculate(length: length * unit.mm, width: width * unit.mm, x: model.reading.x, y: model.reading.y, strategy: strategy, inches: unit == .inch)
    }
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text(L.t("将手机平放在被调物中央")).font(.headline)
                if model.reading.pose != .flat { Text(L.t("请先平放手机")).foregroundStyle(D.accent) }
                VStack(spacing: 16) {
                    Picker(L.t("单位"), selection: $unit) { Text("cm").tag(LengthUnit.cm); Text("in").tag(LengthUnit.inch) }.pickerStyle(.segmented)
                    HStack { Text(L.t("前后脚距")); TextField(L.t("长度"), value: $length, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing).accessibilityIdentifier("leveling.length") }
                    HStack { Text(L.t("左右脚距")); TextField(L.t("宽度"), value: $width, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing).accessibilityIdentifier("leveling.width") }
                    Picker(L.t("调整方案"), selection: $strategy) { Text(L.t("最少调整")).tag(LevelingStrategy.minimum); Text(L.t("只垫高")).tag(LevelingStrategy.raiseOnly) }.pickerStyle(.segmented).accessibilityIdentifier("leveling.strategy")
                }.card()
                if let adjustments {
                    VStack(spacing: 55) {
                        HStack { foot(adjustments[0]); Spacer(); foot(adjustments[1]) }
                        Image(systemName: "iphone").font(.system(size: 50, weight: .ultraLight)).foregroundStyle(D.muted)
                        HStack { foot(adjustments[2]); Spacer(); foot(adjustments[3]) }
                    }.padding(25).background(D.tint, in: RoundedRectangle(cornerRadius: 20)).accessibilityElement(children: .contain).accessibilityIdentifier("leveling.results")
                } else { Text(L.t("请填写有效尺寸，并将手机平放。")) }
                Text(L.t("车内台面本身可能不平，先在地面上测量更准。调整后请再次测量。" )).font(.footnote).foregroundStyle(D.secondary)
            }.padding(20)
        }.background(D.bg).navigationTitle(L.t("调平助手"))
            .onAppear { unit = model.preferences.unit }
            .onChange(of: unit) { old, next in let factor = old.mm / next.mm; length *= factor; width *= factor }
    }
    private func foot(_ foot: FootAdjustment) -> some View {
        VStack(spacing: 6) {
            Text(L.t(corners[foot.corner])).font(.caption).foregroundStyle(D.secondary)
            Text(L.number(abs(foot.amount)) + " " + (unit == .cm ? "mm" : "in")).font(D.digits(22)).foregroundStyle(D.accent)
            Text(abs(foot.amount) < 0.05 ? L.t("保持") : (foot.amount > 0 ? L.t("升高") : L.t("降低"))).font(.caption)
        }
    }
}
