import Foundation

enum ShareText {
    static var appName: String { L.t("水平仪 · 角度测量 坡度仪") }
    static var tagline: String { Launch.isFree ? L.t("打开就能量 · 没有广告") : L.t("打开就能量 · 没有广告 · 一次买断") }
    static var topics: String { L.t("#装修 #挂画 #照片墙 #DIY") }
    static var caption: String { L.t("挂画终于挂正了，用手机水平仪量的，没有广告。") + " " + topics }
    static var storeURL: URL? {
        guard let id = Bundle.main.object(forInfoDictionaryKey: "APP_STORE_ID") as? String,
              !id.isEmpty, id.allSatisfy(\.isNumber) else { return nil }
        return URL(string: "https://apps.apple.com/app/id" + id)
    }
}
