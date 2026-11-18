import Foundation

struct Entitlement: Codable, Equatable {
    var firstOpen = Date()
    var trialClaimedAt: Date?
    var purchasedPro = false
    var proStartedAt: Date?
    var trialStart: Date { trialClaimedAt ?? max(firstOpen, proStartedAt ?? firstOpen) }
    var trialEnd: Date { trialStart.addingTimeInterval(30 * 86400) }
    func isPremium(at now: Date) -> Bool { purchasedPro || (now >= trialStart.addingTimeInterval(-600) && now < trialEnd) }
    func hasPro(at now: Date, free: Bool = Launch.isFree) -> Bool { free || isPremium(at: now) }
    func canUseCamera(at now: Date) -> Bool { hasPro(at: now) }
    func canUseHanging(at now: Date) -> Bool { hasPro(at: now) }
    func canUseLeveling(at now: Date) -> Bool { hasPro(at: now) }
    func canUseVoice(at now: Date) -> Bool { hasPro(at: now) }
    func canUseTarget(at now: Date) -> Bool { hasPro(at: now) }
    func canAttachPhoto(at now: Date) -> Bool { hasPro(at: now) }
    func canMakeCode(at now: Date) -> Bool { hasPro(at: now) }
    func canHideWatermark(at now: Date) -> Bool { hasPro(at: now) }
    func canFinePrecision(at now: Date) -> Bool { hasPro(at: now) }
}
