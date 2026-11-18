import SwiftUI
import StoreKit

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.requestReview) private var requestReview
    var body: some View {
        Form {
            Section {
                Picker(L.t("单位"), selection: $model.preferences.unit) { Text("cm").tag(LengthUnit.cm); Text("in").tag(LengthUnit.inch) }.accessibilityIdentifier("settings.unit")
                Toggle(L.t("提示音"), isOn: $model.preferences.sound).accessibilityIdentifier("settings.sound")
                Toggle(L.t("语音读数"), isOn: Binding(get: { model.preferences.voice }, set: { value in if !value || model.hasPro { model.preferences.voice = value } else { model.sheet = .paywall } })).accessibilityIdentifier("settings.voice")
                Toggle(L.t("震动"), isOn: $model.preferences.haptics).accessibilityIdentifier("settings.haptics")
                Toggle(L.t("稳定 1 秒自动锁定"), isOn: $model.preferences.autoLock).accessibilityIdentifier("settings.autoLock")
            }
            Section {
                route("校准管理", "arrow.triangle.2.circlepath", .calibration)
                route("测量记录", "list.bullet.rectangle", .records)
                route("挂画助手", "photo.on.rectangle", .hanging, pro: true)
                route("调平助手", "square.split.2x2", .leveling, pro: true)
                NavigationLink(L.t("粘贴口令")) { ImportView() }.accessibilityIdentifier("settings.import")
            }
            Section {
                route("推荐给朋友", "square.and.arrow.up", .invite)
                Button(L.t("评分")) { requestReview() }.accessibilityIdentifier("settings.review")
                if !Launch.isFree {
                    route("买断解锁", "checkmark.seal", .paywall)
                    Button(L.t("恢复购买")) { Task { await model.restorePurchases() } }.accessibilityIdentifier("settings.restore")
                }
                NavigationLink(L.t("更多")) { MoreSettingsView() }.accessibilityIdentifier("settings.more")
            }
            Section(L.t("关于")) {
                Text(L.t("手机传感器校准后通常可达 ±0.1°，精密木工请用实物水平尺复核。"))
                Text(L.t("数据只在手机，没有服务器、广告或统计。记录可导出 CSV，删除 App 前请先导出。"))
            }.font(.footnote).foregroundStyle(D.secondary)
        }.navigationTitle(L.t("设置"))
    }
    private func route(_ key: String, _ icon: String, _ destination: Sheet, pro: Bool = false) -> some View {
        Button { if pro { model.requirePro(destination) } else { model.sheet = destination } } label: { Label(L.t(key), systemImage: icon) }.accessibilityIdentifier("settings." + destination.rawValue)
    }
}
struct MoreSettingsView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        Form {
            Picker(L.t("读数精度"), selection: Binding(get: { model.preferences.precision }, set: { value in if value == 0.1 || model.hasPro { model.preferences.precision = value } else { model.sheet = .paywall } })) { Text("0.1°").tag(0.1); Text("0.05°").tag(0.05) }.accessibilityIdentifier("settings.precision")
            Picker(L.t("水平容差"), selection: $model.preferences.tolerance) { ForEach([0.05, 0.1, 0.2, 0.5], id: \.self) { value in Text(L.number(value, decimals: 2) + "°").tag(value) } }.accessibilityIdentifier("settings.tolerance")
            Picker(L.t("读数字号"), selection: $model.preferences.textSize) { Text(L.t("标准")).tag(0); Text(L.t("大")).tag(1); Text(L.t("更大")).tag(2) }.accessibilityIdentifier("settings.textSize")
            Picker(L.t("姿态判断"), selection: $model.preferences.fixedPose) {
                Text(L.t("自动")).tag(Optional<Pose>.none); Text(L.t("平放")).tag(Optional(Pose.flat)); Text(L.t("靠边")).tag(Optional(Pose.edge))
            }.accessibilityIdentifier("settings.pose")
            Toggle(L.t("到达时只响一声"), isOn: $model.preferences.singleTone).accessibilityIdentifier("settings.singleTone")
        }.navigationTitle(L.t("更多"))
    }
}
struct ImportView: View {
    @EnvironmentObject var model: AppModel
    @State private var text = ""
    var body: some View {
        Form {
            Text(L.t("粘贴家人或师傅发来的完整测量口令"))
            PasteButton(payloadType: String.self) { values in if let text = values.first { model.receiveCode(text) } }.accessibilityIdentifier("import.paste")
            TextEditor(text: $text).frame(minHeight: 130).accessibilityIdentifier("import.text")
            Button(L.t("打开方案")) { model.receiveCode(text) }.accessibilityIdentifier("import.open")
            if let message = model.message { Text(message).font(.caption).foregroundStyle(D.secondary) }
        }.navigationTitle(L.t("粘贴口令"))
    }
}
