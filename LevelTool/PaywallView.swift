import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "level").font(.system(size: 56, weight: .ultraLight)).foregroundStyle(D.accent)
                Text(L.t("一次买断，继续精细测量")).font(.largeTitle.weight(.semibold)).accessibilityIdentifier("paywall.title")
                Text(L.t("取景、挂画、调平、语音读数和目标值。基本测量、校准、记录与 CSV 永远免费。"))
                if model.hasPro { Text(L.t("功能已解锁")).foregroundStyle(D.accent) }
                if let product = model.products.first(where: { $0.id == model.proID }) {
                    Button(L.f("买断 %@", product.displayPrice)) { Task { await model.purchase(model.proID) } }.buttonStyle(PrimaryButtonStyle()).disabled(model.purchasing).accessibilityIdentifier("paywall.buy")
                } else { Text(L.t("正在加载商品，请稍后重试。")); Button(L.t("重新加载")) { Task { await model.loadProducts() } }.accessibilityIdentifier("paywall.reload") }
                if model.entitlement.trialClaimedAt == nil {
                    Button(L.t("领取 30 天试用")) { Task { await model.purchase(model.trialID) } }.frame(minHeight: 56).disabled(model.purchasing || !model.products.contains(where: { $0.id == model.trialID })).accessibilityIdentifier("paywall.trial")
                }
                Button(L.t("恢复购买")) { Task { await model.restorePurchases() } }.frame(minHeight: 56).accessibilityIdentifier("paywall.restore")
                Text(L.t("无订阅。购买随 Apple ID 恢复。到期不影响基本测量和已有记录。" )).font(.footnote).foregroundStyle(D.secondary)
                if let message = model.message { Text(message).font(.footnote).foregroundStyle(D.secondary) }
            }.padding(24)
        }.background(D.bg).navigationTitle(L.t("解锁功能")).task { await model.loadProducts() }
    }
}
