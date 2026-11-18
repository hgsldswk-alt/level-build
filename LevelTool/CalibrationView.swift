import SwiftUI

struct CalibrationView: View {
    @EnvironmentObject var model: AppModel
    @State private var pose: Pose = .flat
    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Picker(L.t("校准姿态"), selection: $pose) { Text(L.t("平放")).tag(Pose.flat); Text(L.t("靠边")).tag(Pose.edge) }.pickerStyle(.segmented).disabled(model.calibrationStage == 1 || model.calibrationStage == 2)
                Image(systemName: model.calibrationStage == 3 ? "checkmark.circle" : "arrow.triangle.2.circlepath").font(.system(size: 60, weight: .ultraLight)).foregroundStyle(D.accent).padding(.top, 20)
                Text(stageTitle).font(.title2.weight(.semibold)).multilineTextAlignment(.center).accessibilityIdentifier("calibration.stage")
                if model.calibrationStage == 1 || model.calibrationStage == 2 {
                    ProgressView().tint(D.accent).frame(height: 40)
                    Text(L.t("保持稳定 1 秒，读数将自动记录")).foregroundStyle(D.secondary)
                }
                if let result = model.calibrationResult {
                    HStack { MetricCard(title: L.t("偏差 X"), value: L.number(result.offset.x, decimals: 2) + "°"); MetricCard(title: L.t("偏差 Y"), value: L.number(result.offset.y, decimals: 2) + "°") }
                    Text(L.f("表面倾斜 X %@° / Y %@°", L.number(result.surface.x, decimals: 2), L.number(result.surface.y, decimals: 2))).font(.caption).foregroundStyle(D.secondary)
                }
                if let good = model.accuracyGood { Text(good ? L.t("校准良好") : L.t("建议重新校准")).font(.headline).foregroundStyle(D.accent).accessibilityIdentifier("calibration.accuracy") }
                if model.calibrationStage != 1 && model.calibrationStage != 2 {
                    Button(L.t("开始")) { model.beginCalibration(pose: pose) }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("calibration.start")
                    Button(L.t("检查精度")) { model.beginCalibration(pose: pose, check: true) }.frame(minHeight: 56).accessibilityIdentifier("calibration.check")
                    if let date = model.calibration.date(for: pose) { Text(L.t("上次校准") + " · " + date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(D.secondary) }
                    Button(L.t("重置校准"), role: .destructive) { model.resetCalibration() }.accessibilityIdentifier("calibration.reset")
                }
                Text(L.t("换手机壳或换手机后请重新校准。校准只保存在这台手机。手机传感器校准后通常可达 ±0.1°，精密木工请用实物水平尺复核。"))
                    .font(.footnote).foregroundStyle(D.secondary).multilineTextAlignment(.center)
            }.padding(20)
        }.background(D.bg).navigationTitle(L.t("双面校准"))
            .onDisappear { model.calibrationStage = 0 }
    }
    private var stageTitle: String {
        switch model.calibrationStage {
        case 1: return L.t("放稳手机，正在记录第一次")
        case 2: return pose == .flat ? L.t("原地转半圈（180°），放回同一位置") : L.t("翻面 180°，将同一侧边放回原位置")
        case 3: return L.t("校准完成")
        default: return L.t("放在同一块平面上，抵消手机自身偏差")
        }
    }
}
