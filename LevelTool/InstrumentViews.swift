import SwiftUI

struct DialView: View {
    var x: Double
    var y: Double
    var reached: Bool
    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height), scale = side / 350
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            func point(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: center.x + CGFloat(x) * scale, y: center.y + CGFloat(y) * scale) }
            func circle(_ radius: Double) -> Path { Path(ellipseIn: CGRect(x: center.x - CGFloat(radius) * scale, y: center.y - CGFloat(radius) * scale, width: CGFloat(radius * 2) * scale, height: CGFloat(radius * 2) * scale)) }
            func line(_ a: CGPoint, _ b: CGPoint, _ color: Color, width: CGFloat = 0.7) {
                var path = Path(); path.move(to: a); path.addLine(to: b); context.stroke(path, with: .color(color), lineWidth: width)
            }
            context.fill(circle(166), with: .color(D.card)); context.stroke(circle(166), with: .color(D.line), lineWidth: 0.7)
            for i in stride(from: 0, to: 360, by: 2) {
                let a = Double(i) * .pi / 180, long = i % 30 == 0, middle = i % 10 == 0
                let r = long ? 150.0 : middle ? 155.0 : 159.0
                line(point(cos(a) * 163, sin(a) * 163), point(cos(a) * r, sin(a) * r), long ? D.secondary : D.line2, width: long ? 1.2 : 0.7)
            }
            context.fill(circle(26), with: .color(D.tint))
            for (label, radius) in [(1, 26.0), (2, 52.0), (5, 96.0), (10, 140.0)] {
                context.stroke(circle(radius), with: .color(label == 1 ? D.accent : D.line2), lineWidth: label == 1 ? 1.2 : 0.7)
                context.draw(Text(String(label) + "°").font(.system(size: 10)).foregroundStyle(D.muted), at: point(radius * 0.707 + 8, -radius * 0.707 - 8))
            }
            line(point(-140, 0), point(140, 0), D.line2); line(point(0, -140), point(0, 140), D.line2)
            for k in stride(from: -140, through: 140, by: 14) where k != 0 {
                line(point(Double(k), -3), point(Double(k), 3), D.line2)
                line(point(-3, Double(k)), point(3, Double(k)), D.line2)
            }
            for (label, px, py) in [(L.t("前"), 0.0, -118.0), (L.t("后"), 0, 128), (L.t("左"), -124, 0), (L.t("右"), 124, 0)] {
                context.draw(Text(label).font(.system(size: 11)).foregroundStyle(D.muted), at: point(px, py))
            }
            let tilt = hypot(x, y), r = LevelMath.bubbleRadius(tilt)
            let bx = tilt > 0.00001 ? -x / tilt * r : 0, by = tilt > 0.00001 ? y / tilt * r : 0
            let bubbleColor = D.accent
            func bubble(_ radius: Double, dx: Double = 0, dy: Double = 0) -> Path {
                let p = point(bx + dx, by + dy)
                return Path(ellipseIn: CGRect(x: p.x - CGFloat(radius) * scale, y: p.y - CGFloat(radius) * scale, width: CGFloat(radius * 2) * scale, height: CGFloat(radius * 2) * scale))
            }
            context.fill(bubble(22), with: .color(bubbleColor.opacity(0.16)))
            context.fill(bubble(17), with: .color(bubbleColor.opacity(0.9)))
            context.stroke(bubble(17), with: .color(.white.opacity(0.8)), lineWidth: 1.2)
            context.fill(bubble(5, dx: -5, dy: -6), with: .color(.white.opacity(0.45)))
        }.aspectRatio(1, contentMode: .fit).animation(.spring(response: 0.28, dampingFraction: 0.84), value: x).animation(.spring(response: 0.28, dampingFraction: 0.84), value: y)
            .accessibilityLabel(L.t("双轴气泡水平仪"))
    }
}
struct VialView: View {
    var angle: Double
    var reached = false
    var body: some View {
        Canvas { context, size in
            let w = size.width, mid = w / 2, cy = size.height / 2
            let rect = CGRect(x: 4, y: cy - 35, width: w - 8, height: 70)
            context.fill(Path(roundedRect: rect, cornerRadius: 35), with: .color(D.card))
            context.stroke(Path(roundedRect: rect, cornerRadius: 35), with: .color(D.line2), lineWidth: 0.8)
            context.fill(Path(roundedRect: rect.insetBy(dx: 10, dy: 10), cornerRadius: 25), with: .color(D.tint.opacity(0.55)))
            let step = (w - 50) / 10
            for i in -10...10 {
                let px = mid + CGFloat(i) * step / 2, long = i % 2 == 0
                var p = Path(); p.move(to: CGPoint(x: px, y: cy - (long ? 53 : 47))); p.addLine(to: CGPoint(x: px, y: cy - 39))
                p.move(to: CGPoint(x: px, y: cy + 39)); p.addLine(to: CGPoint(x: px, y: cy + (long ? 53 : 47)))
                context.stroke(p, with: .color(i == 0 ? D.accent : D.line2), lineWidth: i == 0 ? 2 : 0.8)
                if long && i != 0 { context.draw(Text(String(abs(i / 2)) + "°").font(.system(size: 10)).foregroundStyle(D.muted), at: CGPoint(x: px, y: cy + 67)) }
            }
            var limits = Path()
            for dx in [-15.0, 15.0] { limits.move(to: CGPoint(x: mid + CGFloat(dx), y: cy - 29)); limits.addLine(to: CGPoint(x: mid + CGFloat(dx), y: cy + 29)) }
            context.stroke(limits, with: .color(D.accent), lineWidth: 1.4)
            let px = mid - CGFloat(max(-5, min(5, angle))) * step
            context.fill(Path(ellipseIn: CGRect(x: px - 38, y: cy - 20, width: 76, height: 40)), with: .color(reached ? D.accent : D.ink))
            context.fill(Path(ellipseIn: CGRect(x: px - 23, y: cy - 12, width: 28, height: 10)), with: .color(.white.opacity(0.35)))
        }.frame(height: 150).animation(.spring(response: 0.28, dampingFraction: 0.85), value: angle)
    }
}
struct SlopeDiagram: View {
    var slope: Double
    var body: some View {
        Canvas { context, size in
            let w = size.width, middle = size.height * 0.6
            let delta = CGFloat(max(-30, min(30, slope * 9)))
            var baseline = Path(); baseline.move(to: CGPoint(x: 10, y: middle)); baseline.addLine(to: CGPoint(x: w - 10, y: middle))
            context.stroke(baseline, with: .color(D.line2), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            var surface = Path(); surface.move(to: CGPoint(x: 10, y: middle - delta)); surface.addLine(to: CGPoint(x: w - 10, y: middle + delta)); surface.addLine(to: CGPoint(x: w - 10, y: middle + 35)); surface.addLine(to: CGPoint(x: 10, y: middle + 35)); surface.closeSubpath()
            context.fill(surface, with: .color(D.tint))
            var line = Path(); line.move(to: CGPoint(x: 10, y: middle - delta)); line.addLine(to: CGPoint(x: w - 10, y: middle + delta))
            context.stroke(line, with: .color(D.accent), lineWidth: 2)
            var phone = context; phone.translateBy(x: w / 2, y: middle - 9); phone.rotate(by: .radians(atan2(Double(delta * 2), Double(w - 20))))
            phone.fill(Path(roundedRect: CGRect(x: -70, y: -6, width: 140, height: 12), cornerRadius: 6), with: .color(D.ink))
            context.draw(Text(L.t("示意（坡度放大显示）")).font(.system(size: 11)).foregroundStyle(D.muted), at: CGPoint(x: w / 2, y: 18))
            context.draw(Text(L.t("高")).font(.caption).foregroundStyle(D.secondary), at: CGPoint(x: 18, y: middle - delta - 16))
            context.draw(Text(L.f("每米高差 %@ mm", L.number(abs(slope) * 10, decimals: 0))).font(.caption).foregroundStyle(D.secondary), at: CGPoint(x: w - 10, y: size.height - 12), anchor: .trailing)
        }.frame(height: 175)
    }
}
struct HangingDiagram: View {
    var plan: HangingPlan
    var positions: [NailPosition]
    var height: CGFloat = 180
    var body: some View {
        Canvas { context, size in
            let scale = (size.width - 24) / CGFloat(max(1, plan.wallWidth))
            let maxHeight = plan.frames.map(\.height).max() ?? 40
            let hscale = min(scale, (size.height - 45) / CGFloat(maxHeight))
            context.fill(Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 12), with: .color(D.tint))
            for i in positions.indices {
                let frame = plan.frames[i], pos = positions[i]
                let rect = CGRect(x: 12 + CGFloat(pos.left) * scale, y: 22, width: CGFloat(frame.width) * scale, height: CGFloat(frame.height) * hscale)
                context.fill(Path(rect), with: .color(D.card)); context.stroke(Path(rect), with: .color(D.ink), lineWidth: 2)
                let nail = CGPoint(x: 12 + CGFloat(pos.nailX) * scale, y: 22 + CGFloat(plan.hookDrop) * hscale)
                context.fill(Path(ellipseIn: CGRect(x: nail.x - 3, y: nail.y - 3, width: 6, height: 6)), with: .color(D.accent))
                context.draw(Text(String(i + 1)).font(.caption).foregroundStyle(D.secondary), at: CGPoint(x: rect.midX, y: rect.maxY + 14))
            }
        }.frame(height: height)
    }
}
