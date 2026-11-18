import SwiftUI
import PhotosUI

struct RecordsView: View {
    @EnvironmentObject var model: AppModel
    @State private var query = ""
    @State private var detail: Measurement?
    @State private var export: URL?
    private var results: [Measurement] { model.records.filter { query.isEmpty || ($0.name + $0.notes + $0.mode.title).localizedCaseInsensitiveContains(query) }.sorted { $0.date > $1.date } }
    var body: some View {
        List {
            if let saved = model.selectedRecord, model.records.contains(where: { $0.id == saved.id }) {
                Button(L.t("编辑刚保存的读数")) { detail = saved }.accessibilityIdentifier("records.editRecent")
            }
            ForEach(results) { record in
                Button { detail = record } label: {
                    HStack(spacing: 12) {
                        if let image = model.photo(record) { Image(uiImage: image).resizable().scaledToFill().frame(width: 48, height: 48).clipped().clipShape(RoundedRectangle(cornerRadius: 8)) }
                        VStack(alignment: .leading, spacing: 5) {
                            Text(record.name.isEmpty ? record.mode.title : record.name).foregroundStyle(D.ink)
                            Text(record.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(D.secondary)
                        }
                        Spacer(); Text(record.displayValue).font(D.digits(22)).foregroundStyle(D.accent)
                    }.frame(minHeight: 56)
                }.accessibilityIdentifier("record." + record.id.uuidString)
            }.onDelete { indices in for index in indices { model.deleteRecord(results[index].id) } }
        }.searchable(text: $query, prompt: Text(L.t("搜索名称或备注"))).navigationTitle(L.t("测量记录")).accessibilityIdentifier("records.list")
            .overlay { if results.isEmpty { ContentUnavailableView(L.t("还没有记录"), systemImage: "tray", description: Text(L.t("锁定读数后，点保存即可记录。"))) } }
            .toolbar { ToolbarItem(placement: .bottomBar) { Button(L.t("导出 CSV")) { export = model.exportCSV() }.accessibilityIdentifier("records.export") } }
            .sheet(item: $detail) { record in NavigationStack { RecordDetailView(record: record).toolbar { Button(L.t("完成")) { detail = nil } } }.environmentObject(model) }
            .sheet(isPresented: Binding(get: { export != nil }, set: { if !$0 { export = nil } })) { if let export { ActivityView(items: [export]) } }
    }
}
struct RecordDetailView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State var record: Measurement
    @State private var photoItem: PhotosPickerItem?
    @State private var sharing = false
    @State private var takingPhoto = false
    @State private var paywall = false
    var body: some View {
        Form {
            Section {
                Text(record.displayValue).font(D.digits(60)).foregroundStyle(D.accent)
                Text(record.mode.title + " · " + record.date.formatted(date: .abbreviated, time: .shortened)).font(.caption)
                TextField(L.t("名称"), text: $record.name).accessibilityIdentifier("record.name")
                TextField(L.t("备注"), text: $record.notes, axis: .vertical).accessibilityIdentifier("record.notes")
                LabeledContent(L.t("左右 X"), value: L.number(record.x, decimals: 2) + "°")
                LabeledContent(L.t("前后 Y"), value: L.number(record.y, decimals: 2) + "°")
            }
            if let image = model.photo(record) { Image(uiImage: image).resizable().scaledToFit() }
            Section {
                if model.hasPro {
                    PhotosPicker(L.t("添加照片"), selection: $photoItem, matching: .images).accessibilityIdentifier("record.photo")
                    Button(L.t("拍照")) { takingPhoto = true }.accessibilityIdentifier("record.camera")
                } else { Button(L.t("添加照片")) { paywall = true }.accessibilityIdentifier("record.photo") }
                Button(L.t("分享图")) { model.updateRecord(record); model.selectedRecord = record; sharing = true }.accessibilityIdentifier("record.share")
                if let plan = record.hanging { Button(L.t("查看挂画方案")) { model.hangingPlan = plan; dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { model.sheet = .hanging } }.accessibilityIdentifier("record.hanging") }
                if let task = record.task, task.kind != .hanging {
                    Text(task.kind == .slopeTarget ? L.f("目标 %@%%", L.number(task.target ?? 0)) : L.f("目标 %@°", L.number(task.target ?? 0)))
                    Button(L.t("打开方案")) {
                        if let code = try? ShareCode.encode(task) { dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { model.receiveCode(code) } }
                    }.accessibilityIdentifier("record.task")
                }
                Button(L.t("删除记录"), role: .destructive) { model.deleteRecord(record.id); dismiss() }.accessibilityIdentifier("record.delete")
            }
        }.navigationTitle(L.t("记录详情"))
            .onChange(of: record.name) { _, _ in model.updateRecord(record) }
            .onChange(of: record.notes) { _, _ in model.updateRecord(record) }
            .onChange(of: photoItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        model.attachPhoto(image, record: record); record = model.selectedRecord ?? record
                    }
                }
            }
            .sheet(isPresented: $sharing) { NavigationStack { ShareView().toolbar { Button(L.t("完成")) { sharing = false } } }.environmentObject(model) }
            .sheet(isPresented: $paywall) { NavigationStack { PaywallView().toolbar { Button(L.t("完成")) { paywall = false } } }.environmentObject(model) }
            .sheet(isPresented: $takingPhoto) { RecordPhotoCapture { image in
                model.attachPhoto(image, record: record); record = model.selectedRecord ?? record; takingPhoto = false
            } }
    }
}
struct RecordPhotoCapture: View {
    var receive: (UIImage) -> Void
    @StateObject private var camera = CameraController()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    var body: some View {
        ZStack(alignment: .bottom) {
            CameraPreview(session: camera.session).ignoresSafeArea()
            VStack {
                if camera.denied || camera.unavailable { Button(L.t("需要相机权限 · 去设置")) { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } } }
                Button(L.t("拍照")) { camera.capture() }.buttonStyle(PrimaryButtonStyle())
                Button(L.t("取消")) { dismiss() }.frame(minHeight: 56)
            }.padding()
        }.onAppear { camera.start() }.onDisappear { camera.stop() }
            .onChange(of: phase) { _, next in if next == .active { camera.start() } else { camera.stop() } }
            .onChange(of: camera.image) { _, image in if let image { receive(image) } }
    }
}
