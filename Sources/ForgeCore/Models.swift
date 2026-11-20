import Foundation

public enum Domain: String, CaseIterable, Codable, Identifiable, Sendable {
    case business, builder, health, network
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
    public var symbol: String {
        switch self { case .business: "chart.line.uptrend.xyaxis"; case .builder: "terminal"; case .health: "heart"; case .network: "person.2" }
    }
}
public enum QuestType: String, Codable, CaseIterable, Sendable { case outcome, skill, health, maintenance, recovery, boss, optional }
public enum Priority: String, Codable, CaseIterable, Sendable { case main, secondary, supporting, optional }
public enum QuestStatus: String, Codable, Sendable { case active, completed, missed, archived }
public enum EvidenceSource: String, Codable, CaseIterable, Sendable {
    case manual, timer, codingActivity, webhook, gitCommit, appleHealth, calendar, externalMetric, revenue, customer, deviceActivity
    public var confidence: Double {
        switch self { case .manual: 0.6; case .timer, .codingActivity: 0.8; case .gitCommit, .calendar, .webhook: 0.9; default: 1 }
    }
}
public enum SkillState: String, Codable, CaseIterable, Sendable { case locked, learning, practicing, testReady, verified, mastered }
public enum IntegrationState: String, Codable, Sendable { case disconnected, available, denied, unavailable, connected }

public struct UserProfile: Codable, Identifiable, Sendable {
    public var id = UUID()
    public var name = "Player"
    public var objective = "Build my own business"
    public var targetRevenue: Double = 5_000_000
    public var baselineRevenue: Double = 0
    public var createdAt = Date()
    public var wakeHour = 7
    public var sleepHour = 23
    public var workStartHour = 9
    public var workEndHour = 18
    public var trainingDays = 3
    public var strictness = "High"
    public var aiTone = "Strict rational coach"
    public var animations = true
    public var sound = false
    public var haptics = true
    public var aiEnabled = false
    public var aiEndpoint = ""
    public var githubRepository = ""
    public var distractionNotes: String?
    public var rewardPreferences: [String]?
    public var gameTimeZoneID: String?
    public var onboarded = false
    public init() {}
}
public struct Goal: Codable, Identifiable, Sendable {
    public var id = UUID(); public var title: String; public var target: Double; public var deadline: Date
    public init(title: String, target: Double, deadline: Date) { self.title = title; self.target = target; self.deadline = deadline }
}
public struct Quest: Codable, Identifiable, Sendable {
    public var id = UUID()
    public var title: String
    public var details: String
    public var domain: Domain
    public var type: QuestType
    public var priority: Priority
    public var difficulty: Double
    public var impact: Double
    public var baseXP: Int
    public var coinReward: Int
    public var mmrWeight: Double
    public var evidenceRequirement: String
    public var origin: String?
    public var proposalID: UUID?
    public var status: QuestStatus = .active
    public var estimatedMinutes: Int
    public var deadline: Date
    public var completedAt: Date?
    public var createdAt: Date
    public init(title: String, details: String = "", domain: Domain, type: QuestType = .outcome, priority: Priority = .supporting, difficulty: Double = 1, impact: Double = 1, baseXP: Int = 80, coinReward: Int = 25, mmrWeight: Double = 1, evidenceRequirement: String = "Describe the result or attach a proof link.", estimatedMinutes: Int = 30, deadline: Date, createdAt: Date = Date()) {
        self.title = title; self.details = details; self.domain = domain; self.type = type; self.priority = priority; self.difficulty = difficulty; self.impact = impact; self.baseXP = baseXP; self.coinReward = coinReward; self.mmrWeight = mmrWeight; self.evidenceRequirement = evidenceRequirement; self.estimatedMinutes = estimatedMinutes; self.deadline = deadline; self.createdAt = createdAt
    }
    public var isLowImpact: Bool { impact < 0.5 || type == .maintenance || (domain == .business && type == .skill) }
}
public struct QuestEvidence: Codable, Identifiable, Sendable {
    public var id = UUID(); public var questID: UUID; public var source: EvidenceSource; public var confidence: Double; public var note: String; public var reference: String?; public var timestamp: Date; public var externalEventID: String?
    public init(questID: UUID, source: EvidenceSource = .manual, note: String, reference: String? = nil, timestamp: Date = Date()) { self.questID = questID; self.source = source; self.confidence = source.confidence; self.note = note; self.reference = reference; self.timestamp = timestamp }
}
public struct LedgerEntry: Codable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable { case xp, coins, mmr }
    public var id = UUID(); public var kind: Kind; public var amount: Int; public var domain: Domain?; public var reason: String; public var referenceID: UUID?; public var timestamp: Date; public var lowImpact: Bool
    public init(kind: Kind, amount: Int, domain: Domain? = nil, reason: String, referenceID: UUID? = nil, timestamp: Date = Date(), lowImpact: Bool = false) { self.kind = kind; self.amount = amount; self.domain = domain; self.reason = reason; self.referenceID = referenceID; self.timestamp = timestamp; self.lowImpact = lowImpact }
}
public typealias XPTransaction = LedgerEntry
public typealias CoinTransaction = LedgerEntry
public struct DailySnapshot: Codable, Identifiable, Sendable {
    public var id = UUID(); public var date: Date; public var ratings: [Domain: Int]; public var appliedDeltas: [Domain: Int]; public var settled: Bool; public var plannedRest: Bool; public var recoveryCompleted: Bool
    public init(date: Date, ratings: [Domain: Int]) { self.date = date; self.ratings = ratings; appliedDeltas = [:]; settled = false; plannedRest = false; recoveryCompleted = false }
}
public typealias MMRSnapshot = DailySnapshot
public struct RevenueEntry: Codable, Identifiable, Sendable {
    public var id = UUID(); public var amount: Double; public var currency: String; public var client: String; public var source: String; public var date: Date; public var recurring: Bool; public var note: String
    public init(amount: Double, currency: String = "KZT", client: String, source: String = "Direct", date: Date = Date(), recurring: Bool = false, note: String = "") { self.amount = amount; self.currency = currency; self.client = client; self.source = source; self.date = date; self.recurring = recurring; self.note = note }
}
public struct Customer: Codable, Identifiable, Sendable {
    public var id = UUID(); public var name: String; public var stage: String; public var value: Double; public var createdAt: Date
    public init(name: String, stage: String = "Qualified lead", value: Double = 0, createdAt: Date = Date()) { self.name = name; self.stage = stage; self.value = value; self.createdAt = createdAt }
}
public struct BusinessActivity: Codable, Identifiable, Sendable {
    public enum Kind: String, CaseIterable, Codable, Sendable { case outreach, conversation, demo, proposal, shipped, learning }
    public var id = UUID(); public var kind: Kind; public var count: Int; public var note: String; public var date: Date
    public init(kind: Kind, count: Int = 1, note: String = "", date: Date = Date()) { self.kind = kind; self.count = count; self.note = note; self.date = date }
}
public struct Skill: Codable, Identifiable, Sendable {
    public var id: UUID; public var title: String; public var category: String; public var objective: String
    public init(id: UUID = UUID(), title: String, category: String, objective: String) { self.id = id; self.title = title; self.category = category; self.objective = objective }
}
public struct SkillEdge: Codable, Identifiable, Sendable {
    public var id = UUID(); public var prerequisiteID: UUID; public var skillID: UUID
    public init(prerequisiteID: UUID, skillID: UUID) { self.prerequisiteID = prerequisiteID; self.skillID = skillID }
}
public struct SkillProgress: Codable, Identifiable, Sendable {
    public var id = UUID(); public var skillID: UUID; public var state: SkillState; public var proof: String; public var updatedAt: Date
    public init(skillID: UUID, state: SkillState = .learning, proof: String = "", updatedAt: Date = Date()) { self.skillID = skillID; self.state = state; self.proof = proof; self.updatedAt = updatedAt }
}
public struct BossFight: Codable, Identifiable, Sendable {
    public var id = UUID(); public var questID: UUID; public var monthly: Bool; public var objective: String
    public init(questID: UUID, monthly: Bool, objective: String) { self.questID = questID; self.monthly = monthly; self.objective = objective }
}
public struct Streak: Codable, Identifiable, Sendable {
    public var id = UUID(); public var title: String; public var current: Int; public var best: Int
    public init(title: String, current: Int = 0, best: Int = 0) { self.title = title; self.current = current; self.best = best }
}
public struct Reward: Codable, Identifiable, Sendable {
    public var id = UUID(); public var title: String; public var cost: Int; public var minutes: Int; public var symbol: String
    public init(title: String, cost: Int, minutes: Int, symbol: String) { self.title = title; self.cost = cost; self.minutes = minutes; self.symbol = symbol }
}
public struct RewardRedemption: Codable, Identifiable, Sendable {
    public var id = UUID(); public var rewardID: UUID; public var title: String; public var cost: Int; public var startsAt: Date; public var expiresAt: Date
    public init(reward: Reward, now: Date) { rewardID = reward.id; title = reward.title; cost = reward.cost; startsAt = now; expiresAt = now.addingTimeInterval(Double(reward.minutes) * 60) }
}
public struct ScreenTimeRule: Codable, Identifiable, Sendable {
    public var id = UUID(); public var mode = "Focus Lock"; public var minutes = 60; public var enabled = false; public var overrideDelay = 15; public var bypassPenalty = 0
    public init() {}
}
public struct BypassEvent: Codable, Identifiable, Sendable {
    public var id = UUID(); public var reason: String; public var date: Date
    public init(reason: String, date: Date = Date()) { self.reason = reason; self.date = date }
}
public struct RecoverySession: Codable, Identifiable, Sendable {
    public var id = UUID(); public var questID: UUID; public var date: Date; public var completed: Bool
    public init(questID: UUID, date: Date = Date(), completed: Bool = false) { self.questID = questID; self.date = date; self.completed = completed }
}
public struct DailyReview: Codable, Identifiable, Sendable {
    public var id = UUID(); public var date: Date; public var moved: String; public var blocked: String; public var mainQuestCorrect: Bool; public var energy: Int; public var rating: Int; public var note: String
    public init(date: Date = Date(), moved: String, blocked: String, mainQuestCorrect: Bool, energy: Int, rating: Int, note: String = "") { self.date = date; self.moved = moved; self.blocked = blocked; self.mainQuestCorrect = mainQuestCorrect; self.energy = energy; self.rating = rating; self.note = note }
}
public struct IntegrationStatus: Codable, Identifiable, Sendable {
    public var id = UUID(); public var name: String; public var state: IntegrationState; public var message: String; public var lastSync: Date?
    public init(name: String, state: IntegrationState, message: String, lastSync: Date? = nil) { self.name = name; self.state = state; self.message = message; self.lastSync = lastSync }
}
public struct Season: Codable, Identifiable, Sendable {
    public var id = UUID(); public var title: String; public var start: Date; public var end: Date
    public init(title: String, start: Date, end: Date) { self.title = title; self.start = start; self.end = end }
}
public enum MetricState: String, Codable, Sendable { case available, missing, stale, unsupported }
public struct HealthMetric: Codable, Sendable {
    public var source: String; public var observedAt: Date; public var state: MetricState
    public init(source: String, observedAt: Date = Date(), state: MetricState) { self.source = source; self.observedAt = observedAt; self.state = state }
}
public struct HealthSummary: Codable, Identifiable, Sendable {
    public var metrics: [String: HealthMetric]?
    public var wakeTime: Date?
    public var id = UUID(); public var date: Date; public var sleepHours: Double; public var steps: Int; public var workouts: Int; public var cardioMinutes: Int; public var weight: Double?; public var waterLiters: Double; public var screenMinutes: Int; public var codingMinutes: Int; public var source: String
    public init(date: Date = Date(), sleepHours: Double = 0, steps: Int = 0, workouts: Int = 0, cardioMinutes: Int = 0, weight: Double? = nil, waterLiters: Double = 0, screenMinutes: Int = 0, codingMinutes: Int = 0, source: String = "Manual") { self.date = date; self.sleepHours = sleepHours; self.steps = steps; self.workouts = workouts; self.cardioMinutes = cardioMinutes; self.weight = weight; self.waterLiters = waterLiters; self.screenMinutes = screenMinutes; self.codingMinutes = codingMinutes; self.source = source }
}
