import SwiftUI
import AVFoundation
import Photos

final class CameraController: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "LevelTool.camera")
    @Published var denied = false
    @Published var unavailable = false
    @Published var image: UIImage?
    private var configured = false
    private var desiredRunning = false
    func start() {
        queue.async { self.desiredRunning = true }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted { self.configure() } else { DispatchQueue.main.async { self.denied = true } }
            }
        default: denied = true
        }
    }
    private func configure() {
        queue.async {
            guard self.desiredRunning else { return }
            if !self.configured {
                guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                      let input = try? AVCaptureDeviceInput(device: camera) else { DispatchQueue.main.async { self.unavailable = true }; return }
                self.session.beginConfiguration(); self.session.sessionPreset = .photo
                guard self.session.canAddInput(input), self.session.canAddOutput(self.output) else {
                    self.session.commitConfiguration(); DispatchQueue.main.async { self.unavailable = true }; return
                }
                self.session.addInput(input); self.session.addOutput(self.output); self.session.commitConfiguration(); self.configured = true
            }
            if !self.session.isRunning { self.session.startRunning() }
        }
    }
    func stop() { queue.async { self.desiredRunning = false; if self.session.isRunning { self.session.stopRunning() } } }
    func capture() {
        queue.async {
            guard self.session.isRunning else { return }
            let settings = AVCapturePhotoSettings(); settings.flashMode = .off
            self.output.capturePhoto(with: settings, delegate: self)
        }
    }
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { return }
        DispatchQueue.main.async { self.image = image }
    }
}
private final class PreviewLayerView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var preview: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> UIView {
        let view = PreviewLayerView(); view.preview.session = session; view.preview.videoGravity = .resizeAspectFill; return view
    }
    func updateUIView(_ uiView: UIView, context: Context) { }
}
enum PhotoSaver {
    static func save(_ image: UIImage) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw PhotoError.denied }
        try await PHPhotoLibrary.shared().performChanges { _ = PHAssetChangeRequest.creationRequestForAsset(from: image) }
    }
    static func watermarked(_ image: UIImage, text: String) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { ctx in
            image.draw(in: CGRect(origin: .zero, size: image.size))
            let font = UIFont.monospacedDigitSystemFont(ofSize: max(18, image.size.width / 45), weight: .semibold)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white]
            let size = (text as NSString).size(withAttributes: attrs)
            let rect = CGRect(x: image.size.width - size.width - 42, y: image.size.height - size.height - 42, width: size.width + 24, height: size.height + 16)
            UIColor.black.withAlphaComponent(0.6).setFill(); UIBezierPath(roundedRect: rect, cornerRadius: 10).fill()
            (text as NSString).draw(at: CGPoint(x: rect.minX + 12, y: rect.minY + 8), withAttributes: attrs)
        }
    }
    enum PhotoError: Error { case denied }
}
struct CameraView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.scenePhase) private var phase
    @StateObject private var camera = CameraController()
    @State private var horizontal = true
    @State private var vertical = true
    @State private var grid = true
    @State private var watermark = true
    @State private var captured: UIImage?
    @State private var saved = false
    @State private var saveError = false
    private var simulated: Bool { model.isolated || ProcessInfo.processInfo.arguments.contains("-sim-camera") }
    private var roll: Double {
        let g = model.rawGravity
        return hypot(g.x, g.y) < 0.05 ? 0 : LevelMath.degrees(atan2(g.x, -g.y))
    }
    var body: some View {
        ZStack {
            if simulated { Image("DemoWall").resizable().scaledToFill().clipped() }
            else { CameraPreview(session: camera.session) }
            CameraOverlay(roll: roll, horizontal: horizontal, vertical: vertical, grid: grid)
            VStack(spacing: 16) {
                VStack(spacing: 5) {
                    Text(L.number(abs(roll)) + "°").font(D.digits(30))
                    Text(abs(roll) <= model.preferences.tolerance ? L.t("到了") : L.t("绿线是真水平 · 把画框边对齐绿线")).font(.caption)
                }.padding(12).background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
                if camera.denied || camera.unavailable {
                    Button(L.t("需要相机权限 · 去设置")) { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }.padding(12).background(.black.opacity(0.55), in: Capsule()).accessibilityIdentifier("camera.settings")
                }
                Spacer()
                if saved || captured != nil {
                    Button(L.t("分享这张照片")) {
                        model.saveMeasurement(name: L.t("取景照片"))
                        if let record = model.savedRecord, let captured { model.attachPhoto(captured, record: record) }
                        model.sheet = .share
                    }.padding(12).background(.black.opacity(0.55), in: Capsule()).accessibilityIdentifier("camera.share")
                }
                HStack(spacing: 6) {
                    cameraToggle("水平线", value: $horizontal); cameraToggle("垂直线", value: $vertical); cameraToggle("网格", value: $grid)
                    Button { if model.hasPro { watermark.toggle() } else { model.sheet = .paywall } } label: { Text(L.t("读数水印")).font(.caption).padding(9).background(watermark ? D.accent.opacity(0.75) : .black.opacity(0.55), in: Capsule()) }.accessibilityIdentifier("camera.watermark")
                }
                Button {
                    if simulated { process(UIImage(named: "DemoWall") ?? UIImage()) } else { camera.capture() }
                } label: { Circle().fill(.white).frame(width: 58, height: 58).padding(6).overlay(Circle().stroke(.white, lineWidth: 3)) }.accessibilityIdentifier("camera.shutter").padding(.bottom, 20)
            }.padding(.top, 20).padding(.horizontal, 8)
        }.foregroundStyle(.white).background(.black).clipped().clipShape(RoundedRectangle(cornerRadius: 20))
            .onAppear { if !simulated { camera.start() } }
            .onDisappear { camera.stop() }
            .onChange(of: phase) { _, next in if !simulated { if next == .active && model.sheet == nil { camera.start() } else { camera.stop() } } }
            .onChange(of: model.sheet) { _, sheet in if !simulated { if sheet == nil && phase == .active { camera.start() } else { camera.stop() } } }
            .onChange(of: camera.image) { _, image in if let image { process(image) } }
            .alert(L.t("未能存入相册，可在设置中允许添加照片。"), isPresented: $saveError) { Button(L.t("完成"), role: .cancel) {} }
    }
    private func cameraToggle(_ title: String, value: Binding<Bool>) -> some View {
        Button { value.wrappedValue.toggle() } label: { Text(L.t(title)).font(.caption).padding(9).background(value.wrappedValue ? D.accent.opacity(0.75) : .black.opacity(0.55), in: Capsule()) }.accessibilityIdentifier("camera." + title)
    }
    private func process(_ image: UIImage) {
        let final = watermark ? PhotoSaver.watermarked(image, text: L.number(abs(roll)) + "° · " + L.t("水平")) : image
        captured = final
        if !simulated { Task { do { try await PhotoSaver.save(final); saved = true } catch { saveError = true } } }
    }
}
struct CameraOverlay: View {
    var roll: Double
    var horizontal: Bool
    var vertical: Bool
    var grid: Bool
    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height, center = CGPoint(x: w / 2, y: h / 2)
            func line(_ a: CGPoint, _ b: CGPoint, _ color: Color, dash: [CGFloat] = []) {
                var p = Path(); p.move(to: a); p.addLine(to: b); context.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: 1.3, dash: dash))
            }
            if grid {
                for fraction in [1.0 / 3, 2.0 / 3] {
                    line(CGPoint(x: w * CGFloat(fraction), y: 0), CGPoint(x: w * CGFloat(fraction), y: h), .white.opacity(0.28))
                    line(CGPoint(x: 0, y: h * CGFloat(fraction)), CGPoint(x: w, y: h * CGFloat(fraction)), .white.opacity(0.28))
                }
            }
            line(CGPoint(x: 20, y: h / 2), CGPoint(x: w - 20, y: h / 2), .white, dash: [6, 6])
            context.translateBy(x: center.x, y: center.y); context.rotate(by: .degrees(-roll))
            let color = abs(roll) < 0.1 ? D.accent : D.accentSoft
            if horizontal { line(CGPoint(x: -w, y: 0), CGPoint(x: w, y: 0), color) }
            if vertical { line(CGPoint(x: 0, y: -h), CGPoint(x: 0, y: h), color) }
            context.stroke(Path(ellipseIn: CGRect(x: -26, y: -26, width: 52, height: 52)), with: .color(.white), lineWidth: 1.2)
            context.fill(Path(ellipseIn: CGRect(x: -3, y: -3, width: 6, height: 6)), with: .color(.white))
        }.allowsHitTesting(false).accessibilityIdentifier("camera.overlay")
    }
}
