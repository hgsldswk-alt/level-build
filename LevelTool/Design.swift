import SwiftUI

enum D {
    static func color(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: UIColor { trait in
            let hex = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
        })
    }
    static let bg = color(0xF3F1EC, 0x0E1110)
    static let card = color(0xFFFFFF, 0x171B19)
    static let ink = color(0x1D2220, 0xEDF0EE)
    static let secondary = color(0x636D68, 0x9AA29E)
    static let muted = color(0xA2A9A5, 0x5E6662)
    static let line = color(0xE2E0DA, 0x262C29)
    static let line2 = color(0xD3D1CA, 0x323935)
    static let accent = color(0x2F7A5B, 0x5FBF8F)
    static let accentSoft = color(0x7FB49A, 0x3F7F61)
    static let tint = color(0xE2EEE7, 0x18281F)
    static func digits(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: .rounded).monospacedDigit() }
}
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity).frame(minHeight: 56)
            .background(D.accent.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 16))
    }
}
extension View {
    func card() -> some View { padding(16).background(D.card, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(D.line, lineWidth: 0.5)) }
}
struct Pill: View {
    var text: String
    var active = false
    var body: some View {
        Text(text).font(.system(size: 12.5, weight: active ? .semibold : .regular)).foregroundStyle(active ? D.accent : D.secondary)
            .padding(.horizontal, 11).padding(.vertical, 6).background(active ? D.tint : D.card, in: Capsule()).overlay(Capsule().stroke(D.line, lineWidth: 0.5))
    }
}
struct MetricCard: View {
    var title: String
    var value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption).foregroundStyle(D.muted)
            Text(value).font(D.digits(20)).minimumScaleFactor(0.6).lineLimit(1)
        }.frame(maxWidth: .infinity, alignment: .leading).card()
    }
}
