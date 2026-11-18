import SwiftUI
import CoreImage.CIFilterBuiltins

struct ActivityView: UIViewControllerRepresentable {
    var items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) { }
}
enum QR {
    static func image(_ text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator(); filter.message = Data(text.utf8)
        guard let output = filter.outputImage, let cg = CIContext().createCGImage(output.transformed(by: CGAffineTransform(scaleX: 8, y: 8)), from: output.extent.applying(CGAffineTransform(scaleX: 8, y: 8))) else { return nil }
        return UIImage(cgImage: cg)
    }
}
struct ShareCardView: View {
    var record: Measurement
    var image: UIImage?
    var showBrand: Bool
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if let image { Image(uiImage: image).resizable().scaledToFill().frame(width: 390, height: 300).clipped() }
                else if let plan = record.hanging, let positions = try? HangingPlanner.calculate(plan) {
                    VStack(spacing: 4) {
                        HangingDiagram(plan: plan, positions: positions, height: 145)
                        Text(L.t("钉子：离左边 / 离地")).font(.system(size: 10)).foregroundStyle(D.secondary)
                        Grid(horizontalSpacing: 12, verticalSpacing: 4) {
                            ForEach(0..<((positions.count + 1) / 2), id: \.self) { row in
                                GridRow {
                                    ForEach(0..<2, id: \.self) { column in
                                        let index = row * 2 + column
                                        if index < positions.count {
                                            Text(String(index + 1) + ": " + L.number(positions[index].nailX) + " / " + L.number(positions[index].nailHeight) + " " + plan.unit.symbol).font(.system(size: 10, design: .rounded))
                                        } else { Text("") }
                                    }
                                }
                            }
                        }
                    }.padding(20).frame(width: 390, height: 300).background(D.tint)
                } else {
                    VStack(spacing: 20) {
                        DialView(x: record.x, y: record.y, reached: abs(record.primary) <= 0.1).frame(width: 160, height: 160)
                        Text(record.displayValue).font(D.digits(54)).foregroundStyle(D.accent)
                    }.frame(width: 390, height: 300).background(D.bg)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(record.displayValue).font(D.digits(40)).foregroundStyle(D.accent)
                    Text(record.name.isEmpty ? record.mode.title : record.name).font(.system(size: 15, weight: .semibold)).lineLimit(2)
                }
                Text(info).font(.system(size: 12)).foregroundStyle(D.secondary)
                if showBrand {
                    Divider().padding(.vertical, 2)
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(ShareText.appName).font(.system(size: 14, weight: .semibold))
                            Text(ShareText.tagline).font(.system(size: 12)).foregroundStyle(D.secondary)
                            Text(ShareText.topics).font(.system(size: 11)).foregroundStyle(D.muted)
                        }
                        Spacer(minLength: 0)
                        if let url = ShareText.storeURL, let qr = QR.image(url.absoluteString) { Image(uiImage: qr).interpolation(.none).resizable().frame(width: 64, height: 64) }
                    }
                }
                Spacer(minLength: 0)
            }.padding(.horizontal, 24).padding(.top, 18).frame(width: 390, height: 187, alignment: .topLeading).background(.white)
        }.frame(width: 390, height: 487.5).background(.white).foregroundStyle(Color(red: 29 / 255, green: 34 / 255, blue: 32 / 255)).environment(\.colorScheme, .light)
    }
    private var info: String {
        let date = record.date.formatted(date: .abbreviated, time: .omitted)
        if let p = record.hanging { return L.f("%d 幅画", p.frames.count) + " · " + L.f("中心离地 %@ %@", L.number(p.centerHeight), p.unit.symbol) + " · " + date }
        return date
    }
}
struct InviteCardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Image(systemName: "level").font(.system(size: 50, weight: .ultraLight)).foregroundStyle(D.accent)
            Text(L.t("一个不弹广告的水平仪")).font(.system(size: 30, weight: .semibold))
            ForEach([L.t("打开即用"), L.t("能校准镜头凸起"), ShareText.tagline], id: \.self) { text in Label(text, systemImage: "checkmark").font(.headline) }
            Spacer()
            if let url = ShareText.storeURL, let qr = QR.image(url.absoluteString) { Image(uiImage: qr).interpolation(.none).resizable().frame(width: 100, height: 100) }
            Text(ShareText.appName).font(.headline)
            Text(ShareText.topics).font(.caption).foregroundStyle(D.secondary)
        }.padding(32).frame(width: 390, height: 487.5).background(D.bg).foregroundStyle(D.ink).environment(\.colorScheme, .light)
    }
}
struct ShareView: View {
    @EnvironmentObject var model: AppModel
    var invite = false
    @State private var hideBrand = false
    @State private var items: [Any] = []
    @State private var activity = false
    @State private var photoSaved = false
    @State private var saveFailed = false
    private var record: Measurement { model.selectedRecord ?? Measurement(mode: model.mode, primary: model.primary, x: model.current.x, y: model.current.y, slope: model.primary) }
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                GeometryReader { g in
                    card.scaleEffect(g.size.width / 390, anchor: .topLeading)
                }.aspectRatio(390 / 487.5, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 20)).accessibilityIdentifier("share.card")
                if let code = model.shareCode, !invite {
                    Text(code).font(.caption).textSelection(.enabled).accessibilityIdentifier("code.generated")
                    ShareLink(item: code + "\n" + L.t("复制整段，在水平仪 App 里打开")).accessibilityIdentifier("code.share")
                }
                if !invite { Toggle(L.t("隐藏底部 App 栏"), isOn: Binding(get: { hideBrand }, set: { value in if model.hasPro { hideBrand = value } else { model.sheet = .paywall } })).accessibilityIdentifier("share.hideBrand") }
                Button(L.t("分享图片")) {
                    guard let image = render() else { saveFailed = true; return }
                    items = [image, invite ? ShareText.tagline : ShareText.caption]
                    if let url = ShareText.storeURL { items.append(url) }
                    if let code = model.shareCode { items.append(code) }
                    activity = true
                }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("share.export")
                Button(photoSaved ? L.t("已保存到相册") : L.t("保存到相册")) {
                    guard let image = render() else { saveFailed = true; return }
                    Task { do { try await PhotoSaver.save(image); photoSaved = true } catch { saveFailed = true } }
                }.frame(minHeight: 56).accessibilityIdentifier("share.savePhoto")
            }.padding(20)
        }.background(D.bg).navigationTitle(invite ? L.t("推荐给朋友") : L.t("分享图"))
            .sheet(isPresented: $activity) { ActivityView(items: items) }
            .alert(L.t("图片未能保存，请检查相册权限后重试。"), isPresented: $saveFailed) { Button(L.t("完成"), role: .cancel) {} }
    }
    @ViewBuilder private var card: some View {
        if invite { InviteCardView() }
        else { ShareCardView(record: record, image: model.photo(record), showBrand: !hideBrand || !model.hasPro) }
    }
    @MainActor private func render() -> UIImage? {
        let renderer = ImageRenderer(content: card.frame(width: 390, height: 487.5))
        renderer.scale = 1080 / 390
        return renderer.uiImage
    }
}
