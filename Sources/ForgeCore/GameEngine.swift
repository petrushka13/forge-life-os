import Foundation

public struct RankTier: Codable, Sendable { public var title: String; public var minimum: Int; public init(_ title: String, _ minimum: Int) { self.title = title; self.minimum = minimum } }
public struct GameConfig: Codable, Sendable {
    public var weights: [Domain: Double] = [.business: 0.45, .builder: 0.30, .health: 0.20, .network: 0.05]
    public var ranks: [RankTier] = [.init("Iron", 0), .init("Bronze", 900), .init("Silver", 1200), .init("Gold", 1500), .init("Platinum", 1800), .init("Diamond", 2100), .init("Master", 2400), .init("Grandmaster", 2700), .init("Apex", 3000)]
    public var startingMMR = 1000
    public var levelBase = 200.0
    public var levelExponent = 1.35
    public var neutralPerformance = 0.65
    public var dailyMultiplier = 50.0
    public var minDailyDelta = -35
    public var maxDailyDelta = 30
    public var maxOutcomeBonus = 20
    public var revenueMilestone: Double = 100_000
    public var revenueMilestoneBonus = 5
    public var lowImpactXPCap = 100
    public var lowImpactCoinCap = 40
    public var dailyCoinCap = 240
    public var repeatRewardLimit = 2
    public var mainQuestXP = 120
    public var standardQuestXP = 80
    public var mainQuestCoins = 55
    public var standardQuestCoins = 25
    public var bossOutcomeBonus = 10
    public var businessLearningFactor = 0.15
    public var recoveryPenaltyFactor = 0.5
    public init() {}
    private enum CodingKeys: String, CodingKey { case weights, ranks, startingMMR, levelBase, levelExponent, neutralPerformance, dailyMultiplier, minDailyDelta, maxDailyDelta, maxOutcomeBonus, revenueMilestone, revenueMilestoneBonus, lowImpactXPCap, lowImpactCoinCap, dailyCoinCap, repeatRewardLimit, mainQuestXP, standardQuestXP, mainQuestCoins, standardQuestCoins, bossOutcomeBonus, businessLearningFactor, recoveryPenaltyFactor }
    public init(from decoder: any Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        weights = try c.decodeIfPresent([Domain: Double].self, forKey: .weights) ?? weights
        ranks = try c.decodeIfPresent([RankTier].self, forKey: .ranks) ?? ranks
        startingMMR = try c.decodeIfPresent(Int.self, forKey: .startingMMR) ?? startingMMR
        levelBase = try c.decodeIfPresent(Double.self, forKey: .levelBase) ?? levelBase
        levelExponent = try c.decodeIfPresent(Double.self, forKey: .levelExponent) ?? levelExponent
        neutralPerformance = try c.decodeIfPresent(Double.self, forKey: .neutralPerformance) ?? neutralPerformance
        dailyMultiplier = try c.decodeIfPresent(Double.self, forKey: .dailyMultiplier) ?? dailyMultiplier
        minDailyDelta = try c.decodeIfPresent(Int.self, forKey: .minDailyDelta) ?? minDailyDelta
        maxDailyDelta = try c.decodeIfPresent(Int.self, forKey: .maxDailyDelta) ?? maxDailyDelta
        maxOutcomeBonus = try c.decodeIfPresent(Int.self, forKey: .maxOutcomeBonus) ?? maxOutcomeBonus
        revenueMilestone = try c.decodeIfPresent(Double.self, forKey: .revenueMilestone) ?? revenueMilestone
        revenueMilestoneBonus = try c.decodeIfPresent(Int.self, forKey: .revenueMilestoneBonus) ?? revenueMilestoneBonus
        lowImpactXPCap = try c.decodeIfPresent(Int.self, forKey: .lowImpactXPCap) ?? lowImpactXPCap
        lowImpactCoinCap = try c.decodeIfPresent(Int.self, forKey: .lowImpactCoinCap) ?? lowImpactCoinCap
        dailyCoinCap = try c.decodeIfPresent(Int.self, forKey: .dailyCoinCap) ?? dailyCoinCap
        repeatRewardLimit = try c.decodeIfPresent(Int.self, forKey: .repeatRewardLimit) ?? repeatRewardLimit
        mainQuestXP = try c.decodeIfPresent(Int.self, forKey: .mainQuestXP) ?? mainQuestXP
        standardQuestXP = try c.decodeIfPresent(Int.self, forKey: .standardQuestXP) ?? standardQuestXP
        mainQuestCoins = try c.decodeIfPresent(Int.self, forKey: .mainQuestCoins) ?? mainQuestCoins
        standardQuestCoins = try c.decodeIfPresent(Int.self, forKey: .standardQuestCoins) ?? standardQuestCoins
        bossOutcomeBonus = try c.decodeIfPresent(Int.self, forKey: .bossOutcomeBonus) ?? bossOutcomeBonus
        businessLearningFactor = try c.decodeIfPresent(Double.self, forKey: .businessLearningFactor) ?? businessLearningFactor
        recoveryPenaltyFactor = try c.decodeIfPresent(Double.self, forKey: .recoveryPenaltyFactor) ?? recoveryPenaltyFactor
    }
    public var isValid: Bool {
        weights.values.allSatisfy { $0.isFinite && (0...1_000_000).contains($0) } && weights.values.reduce(0, +).isFinite && weights.values.reduce(0, +) > 0 && levelBase.isFinite && (1...10_000).contains(levelBase) && levelExponent.isFinite && (1...2).contains(levelExponent) && neutralPerformance.isFinite && (0...1.25).contains(neutralPerformance) && dailyMultiplier.isFinite && (1...1000).contains(dailyMultiplier) && (-1000...0).contains(minDailyDelta) && (0...1000).contains(maxDailyDelta) && (0...1000).contains(maxOutcomeBonus) && revenueMilestone.isFinite && (1...1e12).contains(revenueMilestone) && (0...1).contains(recoveryPenaltyFactor) && (2...50).contains(ranks.count) && ranks.allSatisfy { (0...100_000_000).contains($0.minimum) } && (0...100_000_000).contains(startingMMR) && (0...100_000).contains(mainQuestXP) && (0...100_000).contains(standardQuestXP) && (0...10_000).contains(mainQuestCoins) && (0...10_000).contains(standardQuestCoins) && (0...1000).contains(bossOutcomeBonus) && ranks.first?.minimum == 0 && zip(ranks, ranks.dropFirst()).allSatisfy { $0.minimum < $1.minimum } && (0...100_000).contains(lowImpactXPCap) && (0...10_000).contains(lowImpactCoinCap) && (0...10_000).contains(dailyCoinCap) && (1...100).contains(repeatRewardLimit) && (0...1000).contains(revenueMilestoneBonus) && businessLearningFactor.isFinite && (0...0.3).contains(businessLearningFactor)
    }
}
public struct LevelProgress: Sendable { public var level: Int; public var currentXP: Int; public var requiredXP: Int; public var fraction: Double { min(1, Double(currentXP) / Double(max(1,requiredXP))) } }
public struct QuestReward: Equatable, Sendable { public var xp: Int; public var coins: Int }
public struct DayPerformance: Sendable {
    public var plannedWeight: Double; public var completedWeight: Double; public var outcomeBonus: Int; public var recovery: Bool; public var rest: Bool
    public init(plannedWeight: Double, completedWeight: Double, outcomeBonus: Int = 0, recovery: Bool = false, rest: Bool = false) { self.plannedWeight = plannedWeight; self.completedWeight = completedWeight; self.outcomeBonus = outcomeBonus; self.recovery = recovery; self.rest = rest }
}
public enum GameError: Error, LocalizedError, Equatable {
    case alreadyCompleted, invalidInput, insufficientCoins, missingRecord, proofRequired, prerequisitesMissing, invalidConfiguration
    public var errorDescription: String? {
        switch self { case .alreadyCompleted: "This action has already been recorded."; case .invalidInput: "Enter a valid value and a concrete result."; case .insufficientCoins: "Complete meaningful work to earn enough Coins."; case .missingRecord: "This record is no longer available."; case .proofRequired: "Add evidence of the result before verifying this skill."; case .prerequisitesMissing: "Verify the prerequisite skills first."; case .invalidConfiguration: "Check the scoring rules. Weights must total more than zero and limits must be valid." }
    }
}
public struct GameEngine: Sendable {
    public let config: GameConfig
    public init(config: GameConfig = GameConfig()) { self.config = config.isValid ? config : GameConfig() }
    public func lifeMMR(_ ratings: [Domain: Int]) -> Int {
        let total = Domain.allCases.reduce(0.0) { $0 + (config.weights[$1] ?? 0) }
        return Int((Domain.allCases.reduce(0.0) { $0 + Double(max(0, min(100_000_000, ratings[$1] ?? config.startingMMR))) * ((config.weights[$1] ?? 0) / total) }).rounded())
    }
    public func rank(_ mmr: Int) -> String {
        let value = max(0, mmr)
        let index = config.ranks.lastIndex(where: { value >= $0.minimum }) ?? 0
        let tier = config.ranks[index]
        guard index + 1 < config.ranks.count else { return tier.title }
        let span = config.ranks[index + 1].minimum - tier.minimum
        let division = min(2, (value - tier.minimum) * 3 / span)
        return "\(tier.title) \(["III", "II", "I"][division])"
    }
    public func xpForLevel(_ level: Int) -> Int { Int((config.levelBase * pow(Double(max(1, min(level, 10_000))), config.levelExponent)).rounded()) }
    public func level(totalXP: Int) -> LevelProgress {
        var remaining = max(0, totalXP), level = 1
        while level < 10_000 && remaining >= xpForLevel(level) { remaining -= xpForLevel(level); level += 1 }
        return LevelProgress(level: level, currentXP: remaining, requiredXP: xpForLevel(level))
    }
    public func questWeight(_ quest: Quest) -> Double {
        quest.impact.isFinite && quest.difficulty.isFinite && quest.mmrWeight.isFinite ? max(0.05, min(2, max(0, quest.impact)) * min(2, max(0, quest.difficulty)) * min(100, max(0, quest.mmrWeight))) : 0.05
    }
    public func completionCredit(_ quest: Quest, confidence: Double) -> Double {
        guard confidence.isFinite else { return 0 }
        let learningFactor = quest.domain == .business && quest.type == .skill ? config.businessLearningFactor : 1
        return questWeight(quest) * (0.8 + 0.2 * min(1, max(0, confidence))) * learningFactor
    }
    public func rewards(for quest: Quest, confidence: Double, earnedLowXP: Int = 0, earnedLowCoins: Int = 0, earnedCoins: Int = 0) -> QuestReward {
        guard confidence.isFinite, quest.impact.isFinite, quest.difficulty.isFinite, (0...100_000).contains(quest.baseXP), (0...10_000).contains(quest.coinReward) else { return QuestReward(xp: 0, coins: 0) }
        let proofFactor = 0.8 + 0.2 * min(1, max(0, confidence))
        let learningFactor = quest.domain == .business && quest.type == .skill ? config.businessLearningFactor : 1
        let impactFactor = min(1.5, max(0.15, quest.impact)) * learningFactor
        var xp = max(0, Int((Double(quest.baseXP) * min(2, max(0.5, quest.difficulty)) * impactFactor * proofFactor).rounded()))
        var coins = max(0, Int((Double(quest.coinReward) * proofFactor * learningFactor).rounded()))
        if quest.isLowImpact { xp = min(xp, max(0, config.lowImpactXPCap - earnedLowXP)); coins = min(coins, max(0, config.lowImpactCoinCap - earnedLowCoins)) }
        if quest.type != .boss { coins = min(coins, max(0, config.dailyCoinCap - earnedCoins)) }
        return QuestReward(xp: xp, coins: coins)
    }
    public func dailyDelta(_ day: DayPerformance) -> Int {
        guard day.plannedWeight.isFinite, day.completedWeight.isFinite, day.plannedWeight > 0, !day.rest else { return 0 }
        let score = min(1.25, max(0, day.completedWeight / day.plannedWeight))
        var delta = min(config.maxDailyDelta, max(config.minDailyDelta, Int((config.dailyMultiplier * (score - config.neutralPerformance)).rounded())))
        if day.recovery && delta < 0 { delta = Int((Double(delta) * config.recoveryPenaltyFactor).rounded()) }
        return delta + min(config.maxOutcomeBonus, max(0, day.outcomeBonus))
    }
    public func redeem(balance: Int, cost: Int) throws -> Int {
        guard cost > 0 else { throw GameError.invalidInput }
        guard balance >= cost else { throw GameError.insufficientCoins }
        return balance - cost
    }
    public func healthComponents(_ summary: HealthSummary) -> [String: Int] {
        guard summary.sleepHours.isFinite, (0...48).contains(summary.sleepHours), (0...100).contains(summary.workouts), (0...1440).contains(summary.cardioMinutes) else { return [:] }
        let values = ["Sleep": min(100, Int(max(0, summary.sleepHours) / 8 * 100)), "Strength": min(100, max(0, summary.workouts) * 100), "Cardio": min(100, Int(Double(max(0, summary.cardioMinutes)) / 30 * 100)), "Activity": min(100, max(0, summary.steps) / 80), "Recovery": min(100, Int(max(0, summary.sleepHours) / 8 * 100))]
        return values.filter { name,_ in summary.metric(name == "Sleep" || name == "Recovery" ? "sleepHours" : name == "Strength" ? "workouts" : name == "Cardio" ? "cardioMinutes" : "steps").state != .missing }
    }
    public func wakeConsistency(_ summaries:[HealthSummary],calendar:Calendar = .current) -> Int? {
        let wake = summaries.sorted { $0.date > $1.date }.compactMap(\.wakeTime).prefix(7).map { Double(calendar.component(.hour,from:$0)*60+calendar.component(.minute,from:$0)) }
        guard wake.count >= 2 else { return nil }
        let anchor = wake[0]
        let differences = wake.map { value in let distance=abs(value-anchor);return min(distance,1440-distance) }
        return max(0,100-Int((differences.reduce(0,+)/Double(wake.count)/120*100).rounded()))
    }
    public func streak(days: Set<Date>, restDays: Set<Date> = [], now: Date, calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: now)
        var day = days.contains(today) || restDays.contains(today) ? today : calendar.date(byAdding: .day, value: -1, to: today)!
        var count = 0
        for _ in 0..<10_000 {
            guard days.contains(day) || restDays.contains(day) else { break }
            if days.contains(day) { count += 1 }
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }
}
