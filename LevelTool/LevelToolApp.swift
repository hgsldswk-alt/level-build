import SwiftUI
import StoreKit

@main
struct LevelToolApp: App {
    @StateObject private var model = AppModel()
    var body: some Scene { WindowGroup { RootView().environmentObject(model).tint(D.accent) } }
}
struct RootView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview
    var body: some View {
        MeasureView()
            .sheet(item: $model.sheet) { sheet in
                NavigationStack {
                    sheetContent(sheet).toolbar { ToolbarItem(placement: .topBarTrailing) { Button(L.t("完成")) { model.sheet = nil }.accessibilityIdentifier("sheet.done") } }
                }.environmentObject(model).tint(D.accent)
            }
            .onAppear { model.active(true) }
            .onDisappear { model.active(false) }
            .onChange(of: scenePhase) { _, next in model.active(next == .active) }
            .onChange(of: model.sheet) { _, _ in model.active(scenePhase == .active) }
            .onChange(of: model.reviewSignal) { _, _ in if model.locked != nil && model.sheet == nil { requestReview() } }
            .gesture(DragGesture(minimumDistance: 65).onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                let modes = MeasureMode.allCases, i = modes.firstIndex(of: model.mode) ?? 0
                let next = i + (value.translation.width < 0 ? 1 : -1)
                if modes.indices.contains(next) { model.selectMode(modes[next]) }
            })
            .task { await model.refreshPurchases() }
    }
    @ViewBuilder private func sheetContent(_ sheet: Sheet) -> some View {
        switch sheet {
        case .settings: SettingsView()
        case .calibration: CalibrationView()
        case .hanging: HangingView()
        case .leveling: LevelingView()
        case .records: RecordsView()
        case .share: ShareView()
        case .invite: ShareView(invite: true)
        case .paywall:
            if !Launch.isFree { PaywallView() } else { EmptyView() }
        case .importCode: ImportView()
        }
    }
}
