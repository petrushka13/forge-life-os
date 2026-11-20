import XCTest
@testable import ForgeCore

final class GameEngineTests: XCTestCase {
    let engine = GameEngine()
    func testWeightsAndRankBoundaries() {
        XCTAssertEqual(engine.lifeMMR([.business: 2000, .builder: 1000, .health: 1000, .network: 1000]), 1450)
        XCTAssertEqual(engine.rank(899), "Iron I"); XCTAssertEqual(engine.rank(900), "Bronze III")
        XCTAssertEqual(engine.rank(1799), "Gold I"); XCTAssertEqual(engine.rank(1800), "Platinum III"); XCTAssertEqual(engine.rank(3000), "Apex")
        var config = GameConfig(); config.weights = [.business: 45, .builder: 30, .health: 20, .network: 5]
        XCTAssertEqual(GameEngine(config: config).lifeMMR([.business: 2000, .builder: 1000, .health: 1000, .network: 1000]), 1450)
    }
    func testNonlinearLevels() {
        XCTAssertEqual(engine.level(totalXP: 0).level, 1)
        XCTAssertEqual(engine.level(totalXP: 199).currentXP, 199)
        XCTAssertEqual(engine.level(totalXP: 200).level, 2)
        XCTAssertGreaterThan(engine.xpForLevel(10), engine.xpForLevel(1) * 10)
        XCTAssertEqual(engine.level(totalXP: -10).currentXP, 0)
    }
    func testDailyPerformance() {
        XCTAssertEqual(engine.dailyDelta(.init(plannedWeight: 1, completedWeight: 1)), 18)
        XCTAssertEqual(engine.dailyDelta(.init(plannedWeight: 1, completedWeight: 0.65)), 0)
        XCTAssertEqual(engine.dailyDelta(.init(plannedWeight: 1, completedWeight: 0)), -33)
        XCTAssertEqual(engine.dailyDelta(.init(plannedWeight: 1, completedWeight: 0, recovery: true)), -17)
        XCTAssertEqual(engine.dailyDelta(.init(plannedWeight: 0, completedWeight: 0)), 0)
        XCTAssertEqual(engine.dailyDelta(.init(plannedWeight: 1, completedWeight: 0, rest: true)), 0)
        XCTAssertEqual(engine.dailyDelta(.init(plannedWeight: 1, completedWeight: 100, outcomeBonus: 999)), 50)
    }
    func testCapsAndManualEvidence() {
        let quest = Quest(title: "Maintenance", domain: .business, type: .maintenance, impact: 0.3, baseXP: 1000, coinReward: 1000, deadline: Date())
        let reward = engine.rewards(for: quest, confidence: 0.6, earnedLowXP: 90, earnedLowCoins: 35)
        XCTAssertEqual(reward, QuestReward(xp: 10, coins: 5))
        let output = Quest(title: "Customer conversation", domain: .business, priority: .main, baseXP: 100, coinReward: 50, deadline: Date())
        XCTAssertEqual(engine.rewards(for: output, confidence: 0.6).xp, 92)
        XCTAssertEqual(engine.rewards(for: output, confidence: 1, earnedCoins: 240).coins, 0)
    }
    func testRedemptionAndStreaks() throws {
        XCTAssertEqual(try engine.redeem(balance: 100, cost: 80), 20)
        XCTAssertThrowsError(try engine.redeem(balance: 20, cost: 80))
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_750_000_000))
        let yesterday = calendar.date(byAdding: .day, value: -1, to: day)!
        let before = calendar.date(byAdding: .day, value: -2, to: day)!
        XCTAssertEqual(engine.streak(days: [day, before], restDays: [yesterday], now: day, calendar: calendar), 2)
        XCTAssertEqual(engine.streak(days: [before], now: day, calendar: calendar), 0)
    }
}
