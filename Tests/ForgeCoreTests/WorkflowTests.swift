import XCTest
@testable import ForgeCore

final class WorkflowTests: XCTestCase {
    var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    var now: Date { Date(timeIntervalSince1970: 1_750_032_000) }
    func session() -> GameSession { var s = GameSession(); s.onboard(profile: UserProfile(), now: now, calendar: calendar); return s }
    func testFreshInstallCompletionRelaunchAndSettlement() throws {
        var s = session()
        XCTAssertEqual(s.lifeMMR, 1000); XCTAssertEqual(s.todayQuests(now: now, calendar: calendar).count, 3)
        let main = s.todayQuests(now: now, calendar: calendar).first!
        let result = try s.completeQuest(main.id, proof: .init(questID: main.id, note: "Contacted ten qualified buyers", timestamp: now), now: now, calendar: calendar)
        XCTAssertGreaterThan(result.xp, 0); XCTAssertGreaterThan(s.coins, 0); XCTAssertGreaterThan(s.lifeMMR, 1000)
        XCTAssertThrowsError(try s.completeQuest(main.id, proof: .init(questID: main.id, note: "Duplicate"), now: now, calendar: calendar))
        let data = try JSONEncoder().encode(s); var restored = try JSONDecoder().decode(GameSession.self, from: data)
        XCTAssertEqual(restored.totalXP, s.totalXP); XCTAssertEqual(restored.ledger.count, 3)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        restored.advanceDay(now: tomorrow, calendar: calendar)
        XCTAssertEqual(restored.ratings[.business], s.ratings[.business])
        XCTAssertEqual(restored.ratings[.builder], 967)
        let count = restored.ledger.count; restored.advanceDay(now: tomorrow, calendar: calendar)
        XCTAssertEqual(restored.ledger.count, count); XCTAssertEqual(restored.totalXP, s.totalXP)
        XCTAssertEqual(restored.todayQuests(now: tomorrow, calendar: calendar).count, 3)
    }
    func testRevenueCapsAndCurrency() throws {
        var s = session()
        try s.addRevenue(.init(amount: 1_000_000, client: "A", date: now), now: now, calendar: calendar)
        try s.addRevenue(.init(amount: 1_000_000, client: "B", date: now), now: now, calendar: calendar)
        XCTAssertEqual(s.ratings[.business], 1020); XCTAssertEqual(s.monthlyRevenue(now: now, calendar: calendar), 2_000_000)
        try s.addRevenue(.init(amount: 100, currency: "USD", client: "C", date: now), now: now, calendar: calendar)
        XCTAssertEqual(s.monthlyRevenue(now: now, calendar: calendar), 2_000_000)
        XCTAssertThrowsError(try s.addRevenue(.init(amount: .nan, client: "A", date: now), now: now, calendar: calendar))
    }
    func testRecoveryRestAndCoinLedger() throws {
        var s = session(); s.startRecovery(now: now, calendar: calendar); s.startRecovery(now: now, calendar: calendar)
        XCTAssertEqual(s.recoveries.count, 1)
        let id = s.recoveries[0].questID
        _ = try s.completeQuest(id, proof: .init(questID: id, note: "Sent one real offer", timestamp: now), now: now, calendar: calendar)
        XCTAssertEqual(s.ratings[.business], 1000)
        XCTAssertEqual(s.streaks(now: now, calendar: calendar).first(where: { $0.title == "No Zero Day" })?.current, 1)
        try s.planRest(now: now, calendar: calendar)
        s.advanceDay(now: calendar.date(byAdding: .day, value: 1, to: now)!, calendar: calendar)
        XCTAssertEqual(s.ratings[.health], 1000); XCTAssertEqual(s.ratings[.business], 983)
        XCTAssertThrowsError(try s.redeem(s.rewards[2].id, now: now))
        s.ledger.append(.init(kind: .coins, amount: 100, reason: "Test", timestamp: now))
        let before = s.coins; try s.redeem(s.rewards[2].id, now: now)
        XCTAssertEqual(s.coins, before - 80)
    }
    func testSkillsRequirePrerequisitesAndProofAndDontFarmXP() throws {
        var s = session(); let first = s.skills[0], second = s.skills[1]
        XCTAssertEqual(s.state(for: second), .locked)
        XCTAssertThrowsError(try s.updateSkill(second.id, state: .verified, proof: "Working module", now: now))
        XCTAssertThrowsError(try s.updateSkill(first.id, state: .verified, proof: "", now: now))
        try s.updateSkill(first.id, state: .verified, proof: "Working tested script", now: now)
        XCTAssertEqual(s.state(for: second), .learning); XCTAssertEqual(s.totalXP, 0)
    }
    func testAIValidationAndProposalHasNoScoringFields() throws {
        XCTAssertThrowsError(try AIRecommendation(message: "", quests: []).validated())
        XCTAssertThrowsError(try AIRecommendation(message: "Plan", quests: [.init(title: "Invalid", details: "", domain: .business, priority: .main, minutes: -1)]).validated())
        let context = AIContext(session: session(), now: now)
        let data = try JSONEncoder().encode(context)
        XCTAssertLessThan(data.count, 4000)
    }
    func testOptionalWorkNeverCausesDailyLossAndBossBonusIsBounded() throws {
        var s = session()
        let main = s.todayQuests(now: now, calendar: calendar).first!
        let optional = Quest(title: "Extra product work", domain: .business, priority: .optional, difficulty: 2, impact: 2, deadline: main.deadline, createdAt: now)
        try s.addQuest(optional, now: now, calendar: calendar)
        _ = try s.completeQuest(main.id, proof: .init(questID: main.id, note: "Real buyers contacted", timestamp: now), now: now, calendar: calendar)
        for n in 0..<4 {
            let boss = Quest(title: "External outcome \(n)", domain: .business, type: .boss, priority: .optional, deadline: now.addingTimeInterval(5 * 86400), createdAt: now)
            try s.addQuest(boss, now: now, calendar: calendar)
            _ = try s.completeQuest(boss.id, proof: .init(questID: boss.id, note: "Customer problem demonstrated", timestamp: now), now: now, calendar: calendar)
        }
        XCTAssertEqual(s.ratings[.business], 1034)
        s.advanceDay(now: now.addingTimeInterval(86400), calendar: calendar)
        XCTAssertEqual(s.ratings[.business], 1034)
    }
    func testRepeatedTitlesStopMintingRewards() throws {
        var s = session()
        for n in 0..<3 {
            let quest = Quest(title: "Repeat exercise", domain: .builder, type: .skill, priority: .optional, deadline: now.addingTimeInterval(3600), createdAt: now)
            try s.addQuest(quest, now: now, calendar: calendar)
            let reward = try s.completeQuest(quest.id, proof: .init(questID: quest.id, note: "Exercise evidence \(n)", timestamp: now), now: now, calendar: calendar)
            if n == 2 { XCTAssertEqual(reward, QuestReward(xp: 0, coins: 0)) }
        }
    }
    func testFutureCommitmentSettlesEvenWhenAppWasClosedOnDeadline() throws {
        var s = session()
        let due = now.addingTimeInterval(2 * 86400)
        let quest = Quest(title: "Future endpoint", domain: .builder, priority: .main, deadline: due, createdAt: now)
        try s.addQuest(quest, now: now, calendar: calendar)
        let optional = Quest(title: "Optional network boss", domain: .network, type: .boss, priority: .optional, deadline: due, createdAt: now)
        try s.addQuest(optional, now: now, calendar: calendar)
        s.advanceDay(now: now.addingTimeInterval(3 * 86400), calendar: calendar)
        XCTAssertEqual(s.quests.first { $0.id == quest.id }?.status, .missed)
        XCTAssertEqual(s.ratings[.builder], 934)
        XCTAssertEqual(s.ratings[.health], 967)
        XCTAssertEqual(s.quests.first { $0.id == optional.id }?.status, .missed)
        XCTAssertEqual(s.ratings[.network], 1000)
    }
    func testAIIdentitySurvivesPersistenceAndRemoteJSONNeedsNoID() throws {
        let remote = Data(#"{"message":"Work on a real offer","quests":[{"title":"Talk to a buyer","details":"Describe the problem","domain":"business","priority":"main","minutes":30}]}"#.utf8)
        let recommendation = try JSONDecoder().decode(AIRecommendation.self, from: remote).validated()
        let restored = try JSONDecoder().decode(AIRecommendation.self, from: JSONEncoder().encode(recommendation))
        XCTAssertEqual(restored.id, recommendation.id)
        XCTAssertEqual(restored.quests[0].id, recommendation.quests[0].id)
    }
    func testDemoHasRevenueWithoutTouchingFreshSession() {
        let demo = SeedData.demo(now: now, calendar: calendar)
        XCTAssertEqual(demo.monthlyRevenue(now: now, calendar: calendar), 350_000)
        XCTAssertEqual(session().monthlyRevenue(now: now, calendar: calendar), 0)
    }
    func testAdditiveConfigurationMigrationPreservesExistingRules() throws {
        let previous = Data(#"{"neutralPerformance":0.7,"dailyCoinCap":220}"#.utf8)
        let migrated = try JSONDecoder().decode(GameConfig.self, from: previous)
        XCTAssertEqual(migrated.neutralPerformance, 0.7)
        XCTAssertEqual(migrated.dailyCoinCap, 220)
        XCTAssertEqual(migrated.repeatRewardLimit, 2)
        XCTAssertTrue(migrated.isValid)
        let encoder = JSONEncoder()
        let persisted = try encoder.encode(migrated)
        XCTAssertEqual(try JSONDecoder().decode(GameConfig.self, from: persisted).mainQuestXP, 120)
    }
    func testRevenueHistoryDoesNotIncludePaymentsReceivedLater() throws {
        var s = session()
        let later = now.addingTimeInterval(3600)
        try s.addRevenue(.init(amount: 200_000, client: "Later client", date: later), now: later, calendar: calendar)
        XCTAssertEqual(s.monthlyRevenue(now: now, calendar: calendar), 0)
        XCTAssertEqual(s.monthlyRevenue(now: later, calendar: calendar), 200_000)
    }
    func testBusinessLearningAloneCannotEarnOutcomeMMR() throws {
        var s = session()
        let id = s.todayQuests(now: now, calendar: calendar).first!.id
        let index = s.quests.firstIndex { $0.id == id }!
        s.quests[index].type = .skill; s.quests[index].title = "Watch a business course"
        let reward = try s.completeQuest(id, proof: .init(questID: id, note: "Course notes recorded", timestamp: now), now: now, calendar: calendar)
        XCTAssertLessThan(reward.xp, 20)
        XCTAssertLessThan(reward.coins, 10)
        XCTAssertEqual(s.ratings[.business], 1000)
        s.advanceDay(now: now.addingTimeInterval(86400), calendar: calendar)
        XCTAssertLessThan(s.ratings[.business]!, 1000)
    }
}
