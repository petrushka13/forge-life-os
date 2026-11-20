import Foundation

public struct ForgeNotice: Sendable {
    public let id: String; public let body: String; public let date: Date
}
public enum NotificationPlan {
    public static func notices(session: GameSession, now: Date = Date(), calendar: Calendar = .current) -> [ForgeNotice] {
        let day = Int(calendar.startOfDay(for: now).timeIntervalSince1970)
        var result: [ForgeNotice] = []
        if session.todayQuests(now:now,calendar:calendar).contains(where: { $0.priority == .main && $0.status == .active && $0.type != .recovery }) {
            let risk = calendar.date(bySettingHour:17,minute:0,second:0,of:now)!
            result.append(ForgeNotice(id:"forge.risk.\(day)",body:"Main Quest untouched. Recovery is available.",date:max(risk,now.addingTimeInterval(5))))
        }
        if let boss = session.quests.filter({ $0.type == .boss && $0.status == .active && calendar.isDate($0.deadline,inSameDayAs:now) }).first {
            result.append(ForgeNotice(id:"forge.boss.\(boss.id)",body:"Your boss deadline is tonight. Record proof or defer honestly.",date:max(now.addingTimeInterval(5),boss.deadline.addingTimeInterval(-3*3600))))
        }
        if let reward = session.rewards.sorted(by: { $0.cost < $1.cost }).first, session.coins >= reward.cost {
            result.append(ForgeNotice(id:"forge.reward.\(day)",body:"You have enough Coins for \(reward.title).",date:now.addingTimeInterval(5)))
        }
        return result
    }
}
