import Foundation

extension GameSession {
    public mutating func acceptRecommendation(_ proposal: AIRecommendation, action: AIAction, replaceBoss: Bool = false, now: Date = Date(), calendar: Calendar = .current) throws {
        let calendar = gameCalendar(calendar)
        let plan = try proposal.validated(action: action)
        guard !recommendations.contains(where: { $0.id == plan.id && $0.accepted }), !quests.contains(where: { $0.proposalID == plan.id }) else { throw GameError.alreadyCompleted }
        var next = self
        let due = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now)!
        if action == .weeklyBoss {
            let week = calendar.dateInterval(of: .weekOfYear, for: now)!
            let existing = bosses.filter { !$0.monthly }
            for boss in existing {
                guard let quest = quests.first(where: { $0.id == boss.questID }), week.contains(quest.deadline) else { continue }
                guard quest.status != .completed, replaceBoss else { throw GameError.alreadyCompleted }
                if let index = next.quests.firstIndex(where: { $0.id == quest.id }) { next.quests[index].status = .archived }
            }
        } else if action == .recovery {
            guard !recoveries.contains(where: { calendar.isDate($0.date, inSameDayAs: now) }) else { throw GameError.alreadyCompleted }
        } else if action == .dailyPlan {
            for index in next.quests.indices where next.quests[index].origin == "template" && next.quests[index].status == .active && calendar.isDate(next.quests[index].deadline, inSameDayAs: now) { next.quests[index].status = .archived }
        } else { throw GameError.invalidInput }
        for item in plan.quests {
            if action == .dailyPlan {
                let existing = next.todayQuests(now: now, calendar: calendar).filter { $0.priority != .optional && $0.type != .recovery }
                if item.priority != .optional && (existing.count >= 3 || (item.priority == .main && existing.contains { $0.priority == .main })) { continue }
            }
            let recovery = action == .recovery, boss = action == .weeklyBoss
            var quest = Quest(title: item.title, details: item.details, domain: item.domain, type: recovery ? .recovery : boss ? .boss : item.domain == .health ? .health : .outcome, priority: boss ? .optional : item.priority, difficulty: recovery ? 0.5 : boss ? 1.5 : 1, impact: recovery ? 0.5 : boss ? 1.5 : 1, baseXP: recovery ? 40 : boss ? 250 : item.priority == .main ? config.mainQuestXP : config.standardQuestXP, coinReward: recovery ? 10 : boss ? 100 : item.priority == .main ? config.mainQuestCoins : config.standardQuestCoins, estimatedMinutes: item.minutes, deadline: boss ? calendar.dateInterval(of: .weekOfYear, for: now)!.end.addingTimeInterval(-1) : due, createdAt: now)
            quest.origin = "AI proposal"; quest.proposalID = plan.id
            try next.addQuest(quest, now: now, calendar: calendar)
            if recovery { next.recoveries.append(RecoverySession(questID: quest.id, date: now)) }
            if boss { next.bosses.append(BossFight(questID: quest.id, monthly: false, objective: profile.objective)) }
        }
        if let index = next.recommendations.firstIndex(where: { $0.id == plan.id }) { next.recommendations[index].accepted = true }
        else { var accepted = plan; accepted.accepted = true; next.recommendations.append(accepted) }
        self = next
    }
}
