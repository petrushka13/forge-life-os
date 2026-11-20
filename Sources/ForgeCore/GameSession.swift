import Foundation

public struct GameSession: Codable, Sendable {
    public var schemaVersion = 1
    public var profile = UserProfile()
    public var config = GameConfig()
    public var goals: [Goal] = []
    public var ratings: [Domain: Int] = Dictionary(uniqueKeysWithValues: Domain.allCases.map { ($0, 1000) })
    public var quests: [Quest] = []
    public var evidence: [QuestEvidence] = []
    public var ledger: [LedgerEntry] = []
    public var snapshots: [DailySnapshot] = []
    public var revenue: [RevenueEntry] = []
    public var customers: [Customer] = []
    public var activities: [BusinessActivity] = []
    public var skills: [Skill] = []
    public var skillEdges: [SkillEdge] = []
    public var skillProgress: [SkillProgress] = []
    public var bosses: [BossFight] = []
    public var rewards: [Reward] = []
    public var redemptions: [RewardRedemption] = []
    public var screenRules: [ScreenTimeRule] = [ScreenTimeRule()]
    public var bypasses: [BypassEvent] = []
    public var recoveries: [RecoverySession] = []
    public var reviews: [DailyReview] = []
    public var integrations: [IntegrationStatus] = []
    public var recommendations: [AIRecommendation] = []
    public var seasons: [Season] = []
    public var health: [HealthSummary] = []
    public var evidenceInbox: [ExternalProof] = []
    public var evidenceCursor = 0
    public var evidenceServerID: String?
    public init() {}
    private enum CodingKeys: String, CodingKey { case schemaVersion, profile, config, goals, ratings, quests, evidence, ledger, snapshots, revenue, customers, activities, skills, skillEdges, skillProgress, bosses, rewards, redemptions, screenRules, bypasses, recoveries, reviews, integrations, recommendations, seasons, health, evidenceInbox, evidenceCursor, evidenceServerID }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        profile = try c.decode(UserProfile.self, forKey: .profile)
        config = try c.decode(GameConfig.self, forKey: .config)
        goals = try c.decode([Goal].self, forKey: .goals)
        ratings = try c.decode([Domain: Int].self, forKey: .ratings)
        quests = try c.decode([Quest].self, forKey: .quests)
        evidence = try c.decode([QuestEvidence].self, forKey: .evidence)
        ledger = try c.decode([LedgerEntry].self, forKey: .ledger)
        snapshots = try c.decode([DailySnapshot].self, forKey: .snapshots)
        revenue = try c.decode([RevenueEntry].self, forKey: .revenue)
        customers = try c.decode([Customer].self, forKey: .customers)
        activities = try c.decode([BusinessActivity].self, forKey: .activities)
        skills = try c.decode([Skill].self, forKey: .skills)
        skillEdges = try c.decode([SkillEdge].self, forKey: .skillEdges)
        skillProgress = try c.decode([SkillProgress].self, forKey: .skillProgress)
        bosses = try c.decode([BossFight].self, forKey: .bosses)
        rewards = try c.decode([Reward].self, forKey: .rewards)
        redemptions = try c.decode([RewardRedemption].self, forKey: .redemptions)
        screenRules = try c.decode([ScreenTimeRule].self, forKey: .screenRules)
        bypasses = try c.decode([BypassEvent].self, forKey: .bypasses)
        recoveries = try c.decode([RecoverySession].self, forKey: .recoveries)
        reviews = try c.decode([DailyReview].self, forKey: .reviews)
        integrations = try c.decode([IntegrationStatus].self, forKey: .integrations)
        recommendations = try c.decode([AIRecommendation].self, forKey: .recommendations)
        seasons = try c.decode([Season].self, forKey: .seasons)
        health = try c.decode([HealthSummary].self, forKey: .health)
        evidenceCursor = try c.decodeIfPresent(Int.self, forKey: .evidenceCursor) ?? 0
        evidenceServerID = try c.decodeIfPresent(String.self, forKey: .evidenceServerID)
        evidenceInbox = try c.decodeIfPresent([ExternalProof].self, forKey: .evidenceInbox) ?? []
    }

    public func gameCalendar(_ proposed: Calendar = .current) -> Calendar {
        var result = proposed
        if let name = profile.gameTimeZoneID, let zone = TimeZone(identifier: name) { result.timeZone = zone }
        return result
    }
    public var engine: GameEngine { GameEngine(config: config) }
    public var totalXP: Int { ledger.filter { $0.kind == .xp }.reduce(0) { $0 + $1.amount } }
    public var coins: Int { ledger.filter { $0.kind == .coins }.reduce(0) { $0 + $1.amount } }
    public var lifeMMR: Int { engine.lifeMMR(ratings) }
    /// Compare composite ratings once, rather than rounding every weighted receipt.
    /// Current weights are used for both endpoints, so changing weights is not
    /// misrepresented as earned execution progress.
    public func lifeMMRChange(since: Date, now: Date = Date()) -> Int {
        var changes: [Domain: Double] = [:]
        for entry in ledger where entry.kind == .mmr && entry.timestamp >= since && entry.timestamp <= now {
            if let domain = entry.domain { changes[domain, default: 0] += Double(entry.amount) }
        }
        let previous = Dictionary(uniqueKeysWithValues: Domain.allCases.map { domain in
            (domain, Int(min(100_000_000, max(0, Double(ratings[domain] ?? config.startingMMR) - changes[domain, default: 0]))))
        })
        return lifeMMR - engine.lifeMMR(previous)
    }
    public func monthlyRevenue(now: Date = Date(), calendar: Calendar = .current) -> Double {
        let calendar = gameCalendar(calendar)
        let interval = calendar.dateInterval(of: .month, for: now)!
        let entries = revenue.filter { $0.currency == "KZT" && interval.contains($0.date) && $0.date <= now }.reduce(0) { $0 + $1.amount }
        // Baseline describes the starting month only, not a fictional recurring payment.
        return entries + (calendar.isDate(profile.createdAt, equalTo: now, toGranularity: .month) ? profile.baselineRevenue : 0)
    }
    public func todayQuests(now: Date = Date(), calendar: Calendar = .current) -> [Quest] {
        let calendar = gameCalendar(calendar)
        return quests.filter { calendar.isDate($0.deadline, inSameDayAs: now) && $0.status != .archived && $0.type != .boss }
            .sorted { priorityOrder($0.priority) < priorityOrder($1.priority) }
    }
    private func priorityOrder(_ priority: Priority) -> Int { switch priority { case .main: 0; case .secondary: 1; case .supporting: 2; case .optional: 3 } }
    public mutating func onboard(profile: UserProfile, now: Date = Date(), calendar: Calendar = .current) {
        self.profile = profile; self.profile.onboarded = true; self.profile.createdAt = now
        self.profile.gameTimeZoneID = calendar.timeZone.identifier
        goals = [Goal(title: profile.objective, target: profile.targetRevenue, deadline: calendar.date(byAdding: .year, value: 1, to: now)!)]
        seasons = [Season(title: "Build something people pay for", start: now, end: calendar.date(byAdding: .day, value: 30, to: now)!)]
        let seed = SeedData.skillGraph(); skills = seed.0; skillEdges = seed.1
        rewards = SeedData.rewards.filter { reward in profile.rewardPreferences.map { preferences in preferences.contains(reward.title) } ?? true }
        advanceDay(now: now, calendar: calendar)
    }
    public mutating func advanceDay(now: Date = Date(), calendar: Calendar = .current) {
        let calendar = gameCalendar(calendar)
        guard profile.onboarded else { return }
        if profile.gameTimeZoneID == nil { profile.gameTimeZoneID = calendar.timeZone.identifier }
        let today = calendar.startOfDay(for: now)
        let overdueDates = Set(quests.filter { $0.status == .active && $0.priority != .optional && $0.deadline < today }.map { calendar.startOfDay(for: $0.deadline) })
        for date in overdueDates where !snapshots.contains(where: { $0.date == date }) { snapshots.append(DailySnapshot(date: date, ratings: ratings)) }
        snapshots.sort { $0.date < $1.date }
        for index in snapshots.indices where snapshots[index].date < today && !snapshots[index].settled {
            let date = snapshots[index].date
            for domain in Domain.allCases {
                let delta = performanceDelta(domain: domain, date: date, calendar: calendar)
                let previously = snapshots[index].appliedDeltas[domain] ?? 0
                if delta != previously { recordMMR(delta - previously, domain: domain, reason: "Daily settlement · \(date.formatted(date: .abbreviated, time: .omitted))", now: now) }
                snapshots[index].appliedDeltas[domain] = delta
            }
            for qi in quests.indices where calendar.isDate(quests[qi].deadline, inSameDayAs: date) && quests[qi].status == .active { quests[qi].status = .missed }
            snapshots[index].ratings = ratings; snapshots[index].settled = true
        }
        // Optional commitments and bosses also expire, without adding a daily penalty.
        for index in quests.indices where quests[index].deadline < today && quests[index].status == .active { quests[index].status = .missed }
        if !snapshots.contains(where: { $0.date == today }) {
            snapshots.append(DailySnapshot(date: today, ratings: ratings))
            let existing = todayQuests(now: now, calendar: calendar).filter { $0.priority != .optional }
            let generated = SeedData.dailyPlan(now: now, calendar: calendar, config: config).filter { candidate in !existing.contains(where: { $0.domain == candidate.domain || ($0.priority == .main && candidate.priority == .main) }) }
            quests.append(contentsOf: generated.prefix(max(0, 3 - existing.count)).map { var quest = $0; quest.origin = "template"; return quest })
        }
        seedBosses(now: now, calendar: calendar)
    }
    public mutating func addQuest(_ quest: Quest, now: Date = Date(), calendar: Calendar = .current) throws {
        let calendar = gameCalendar(calendar)
        guard !quest.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, quest.title.count <= 200, quest.deadline >= calendar.startOfDay(for: now), quest.baseXP >= 0, quest.coinReward >= 0, (0.1...2).contains(quest.difficulty), (0.1...2).contains(quest.impact), quest.mmrWeight > 0 else { throw GameError.invalidInput }
        let mandatory = quests.filter { calendar.isDate($0.deadline, inSameDayAs: quest.deadline) && $0.priority != .optional && $0.type != .boss && $0.type != .recovery && $0.status != .archived }.count
        guard quest.priority == .optional || quest.type == .boss || quest.type == .recovery || mandatory < 3 else { throw GameError.invalidInput }
        quests.append(quest)
    }
    public mutating func completeQuest(_ id: UUID, proof: QuestEvidence, now: Date = Date(), calendar: Calendar = .current) throws -> QuestReward {
        let calendar = gameCalendar(calendar)
        guard let index = quests.firstIndex(where: { $0.id == id }) else { throw GameError.missingRecord }
        guard quests[index].status == .active else { throw GameError.alreadyCompleted }
        guard proof.questID == id, !proof.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, proof.confidence.isFinite, (0...1).contains(proof.confidence), quests[index].deadline >= calendar.startOfDay(for: now) else { throw GameError.invalidInput }
        if let event = proof.externalEventID { guard evidenceInbox.contains(where: { $0.id == event }), !evidence.contains(where: { $0.externalEventID == event }) else { throw GameError.alreadyCompleted } }
        if let reference = proof.reference, !reference.isEmpty { guard !evidence.contains(where: { $0.reference == reference }) else { throw GameError.alreadyCompleted } }
        let quest = quests[index]
        let entries = ledger.filter { calendar.isDate($0.timestamp, inSameDayAs: now) }
        var reward = engine.rewards(for: quest, confidence: proof.confidence, earnedLowXP: entries.filter { $0.kind == .xp && $0.lowImpact }.reduce(0) { $0 + $1.amount }, earnedLowCoins: entries.filter { $0.kind == .coins && $0.lowImpact && $0.amount > 0 }.reduce(0) { $0 + $1.amount }, earnedCoins: entries.filter { entry in entry.kind == .coins && entry.amount > 0 && !bosses.contains(where: { b in b.questID == entry.referenceID }) }.reduce(0) { $0 + $1.amount })
        let repeated = quests.filter { $0.status == .completed && $0.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == quest.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() && calendar.isDate($0.completedAt ?? .distantPast, inSameDayAs: now) }.count
        if repeated >= config.repeatRewardLimit { reward = QuestReward(xp: 0, coins: 0) }
        quests[index].status = .completed; quests[index].completedAt = now
        evidence.append(proof)
        ledger.append(LedgerEntry(kind: .xp, amount: reward.xp, reason: quest.title, referenceID: id, timestamp: now, lowImpact: quest.isLowImpact))
        ledger.append(LedgerEntry(kind: .coins, amount: reward.coins, reason: quest.title, referenceID: id, timestamp: now, lowImpact: quest.isLowImpact))
        if quest.type == .recovery {
            if let ri = recoveries.firstIndex(where: { $0.questID == id }) { recoveries[ri].completed = true }
            if let si = snapshots.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: now) }) { snapshots[si].recoveryCompleted = true }
        }
        if quest.type == .boss {
            let used = outcomeBonusUsed(domain: quest.domain, now: now, calendar: calendar)
            let bonus = min(config.bossOutcomeBonus, max(0, config.maxOutcomeBonus - used))
            if bonus > 0 { recordMMR(bonus, domain: quest.domain, reason: "Boss outcome", now: now) }
        }
        applyEarnedMMR(domain: quest.domain, now: now, calendar: calendar)
        return reward
    }
    private func performanceDelta(domain: Domain, date: Date, calendar: Calendar) -> Int {
        let calendar = gameCalendar(calendar)
        let planned = quests.filter { $0.domain == domain && calendar.isDate($0.deadline, inSameDayAs: date) && $0.priority != .optional && $0.type != .optional && $0.type != .recovery && $0.status != .archived }
        let completed = planned.filter { $0.status == .completed }
        let weight = planned.reduce(0) { $0 + engine.questWeight($1) }
        let done = completed.reduce(0.0) { total, quest in
            let confidence = evidence.first(where: { $0.questID == quest.id })?.confidence ?? 0.6
            return total + engine.completionCredit(quest, confidence: confidence)
        }
        let snapshot = snapshots.first { calendar.isDate($0.date, inSameDayAs: date) }
        return engine.dailyDelta(DayPerformance(plannedWeight: weight, completedWeight: done, recovery: snapshot?.recoveryCompleted ?? false, rest: domain == .health && snapshot?.plannedRest == true))
    }
    private mutating func applyEarnedMMR(domain: Domain, now: Date, calendar: Calendar) {
        let calendar = gameCalendar(calendar)
        guard let si = snapshots.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: now) }) else { return }
        let delta = max(0, performanceDelta(domain: domain, date: now, calendar: calendar))
        let applied = snapshots[si].appliedDeltas[domain] ?? 0
        if delta > applied {
            recordMMR(delta - applied, domain: domain, reason: "Earned daily performance", now: now)
            snapshots[si].appliedDeltas[domain] = delta
        }
        snapshots[si].ratings = ratings
    }
    private func outcomeBonusUsed(domain: Domain, now: Date, calendar: Calendar) -> Int {
        let calendar = gameCalendar(calendar)
        return ledger.filter { $0.kind == .mmr && $0.domain == domain && ["Boss outcome", "Revenue milestone", "Customer milestone"].contains($0.reason) && calendar.isDate($0.timestamp, inSameDayAs: now) }.reduce(0) { $0 + max(0, $1.amount) }
    }
    private mutating func recordMMR(_ amount: Int, domain: Domain, reason: String, now: Date) {
        let old = ratings[domain] ?? config.startingMMR
        let actual = min(100_000_000, max(0, old + amount)) - old
        ratings[domain] = old + actual
        ledger.append(LedgerEntry(kind: .mmr, amount: actual, domain: domain, reason: reason, timestamp: now))
    }
    public mutating func addRevenue(_ entry: RevenueEntry, now: Date = Date(), calendar: Calendar = .current) throws {
        let calendar = gameCalendar(calendar)
        guard !revenue.contains(where: { $0.id == entry.id }), entry.amount.isFinite, entry.amount > 0, entry.amount <= 1_000_000_000_000, !entry.client.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, entry.date <= now, entry.currency.count == 3, entry.currency.allSatisfy({ $0.isASCII && $0.isUppercase }) else { throw GameError.invalidInput }
        let old = monthlyRevenue(now: now, calendar: calendar)
        revenue.append(entry)
        if !customers.contains(where: { $0.name.lowercased() == entry.client.lowercased() }) { customers.append(Customer(name: entry.client, stage: "Paying customer", value: entry.currency == "KZT" ? entry.amount : 0, createdAt: entry.date)) }
        else if let ci = customers.firstIndex(where: { $0.name.lowercased() == entry.client.lowercased() }) { customers[ci].stage = "Paying customer"; customers[ci].value = revenue.filter { $0.currency == "KZT" && $0.client.lowercased() == entry.client.lowercased() }.reduce(0) { $0 + $1.amount } }
        let new = monthlyRevenue(now: now, calendar: calendar)
        let milestones = Int(min(Double(config.maxOutcomeBonus), max(0, floor(new / config.revenueMilestone) - floor(old / config.revenueMilestone))))
        let used = outcomeBonusUsed(domain: .business, now: now, calendar: calendar)
        let bonus = min(max(0, config.maxOutcomeBonus - used), milestones * config.revenueMilestoneBonus)
        if bonus > 0 { recordMMR(bonus, domain: .business, reason: "Revenue milestone", now: now) }
        if let si = snapshots.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: now) }) { snapshots[si].ratings = ratings }
    }
    public mutating func redeem(_ id: UUID, now: Date = Date()) throws {
        guard let reward = rewards.first(where: { $0.id == id }) else { throw GameError.missingRecord }
        _ = try engine.redeem(balance: coins, cost: reward.cost)
        guard !redemptions.contains(where: { $0.expiresAt > now }) else { throw GameError.alreadyCompleted }
        redemptions.append(RewardRedemption(reward: reward, now: now))
        ledger.append(LedgerEntry(kind: .coins, amount: -reward.cost, reason: "Redeemed \(reward.title)", referenceID: reward.id, timestamp: now))
    }
    public mutating func startRecovery(now: Date = Date(), calendar: Calendar = .current) {
        let calendar = gameCalendar(calendar)
        guard !recoveries.contains(where: { calendar.isDate($0.date, inSameDayAs: now) }) else { return }
        let title = "Send one qualified prospect a specific offer"
        let quest = Quest(title: title, details: "One person. One concrete problem. One message. Stop after 25 minutes.", domain: .business, type: .recovery, priority: .main, difficulty: 0.5, impact: 0.5, baseXP: 40, coinReward: 10, estimatedMinutes: 25, deadline: calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now)!, createdAt: now)
        quests.append(quest); recoveries.append(RecoverySession(questID: quest.id, date: now))
    }
    public mutating func planRest(now: Date = Date(), calendar: Calendar = .current) throws {
        let calendar = gameCalendar(calendar)
        guard let si = snapshots.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: now) }) else { throw GameError.missingRecord }
        guard snapshots[si].appliedDeltas[.health, default: 0] == 0 else { throw GameError.alreadyCompleted }
        snapshots[si].plannedRest = true
        for index in quests.indices where quests[index].domain == .health && calendar.isDate(quests[index].deadline, inSameDayAs: now) && quests[index].status == .active { quests[index].status = .archived }
    }
    public func state(for skill: Skill) -> SkillState {
        let prerequisites = skillEdges.filter { $0.skillID == skill.id }.map(\.prerequisiteID)
        if prerequisites.contains(where: { id in !skillProgress.contains { $0.skillID == id && ($0.state == .verified || $0.state == .mastered) } }) { return .locked }
        return skillProgress.first { $0.skillID == skill.id }?.state ?? .learning
    }
    public mutating func updateSkill(_ id: UUID, state: SkillState, proof: String, now: Date = Date()) throws {
        guard let skill = skills.first(where: { $0.id == id }) else { throw GameError.missingRecord }
        guard self.state(for: skill) != .locked else { throw GameError.prerequisitesMissing }
        guard state != .locked else { throw GameError.invalidInput }
        if state == .verified || state == .mastered { guard proof.trimmingCharacters(in: .whitespacesAndNewlines).count >= 8 else { throw GameError.proofRequired } }
        if state == .mastered { guard skillProgress.first(where: { $0.skillID == id })?.state == .verified || skillProgress.first(where: { $0.skillID == id })?.state == .mastered else { throw GameError.proofRequired } }
        let progress = SkillProgress(skillID: id, state: state, proof: proof, updatedAt: now)
        if let index = skillProgress.firstIndex(where: { $0.skillID == id }) { skillProgress[index].state = state; skillProgress[index].proof = proof; skillProgress[index].updatedAt = now } else { skillProgress.append(progress) }
        // Verification is self-attested in V1. XP comes from evidence-backed quests, never from toggling a skill state.
    }
    public func streaks(now: Date = Date(), calendar: Calendar = .current) -> [Streak] {
        let calendar = gameCalendar(calendar)
        let done = quests.filter { $0.status == .completed && $0.type != .optional && !$0.isLowImpact }
        func days(_ subset: [Quest]) -> Set<Date> { Set(subset.compactMap(\.completedAt).map { calendar.startOfDay(for: $0) }) }
        let rest = Set(snapshots.filter(\.plannedRest).map(\.date))
        let sets: [(String, Set<Date>, Set<Date>)] = [("Execution", days(done.filter { $0.type != .recovery }), []), ("Main Quest", days(done.filter { $0.priority == .main && $0.type != .recovery }), []), ("Training", days(done.filter { $0.domain == .health }), rest), ("No Zero Day", days(done).union(Set(recoveries.filter(\.completed).map { calendar.startOfDay(for: $0.date) })), [])]
        return sets.map { title, dates, restDays in
            let current = engine.streak(days: dates, restDays: restDays, now: now, calendar: calendar)
            let best = dates.map { engine.streak(days: dates, restDays: restDays, now: $0, calendar: calendar) }.max() ?? 0
            return Streak(title: title, current: current, best: best)
        }
    }
    public func ghost(now: Date = Date(), calendar: Calendar = .current) -> (current: Int, best: Int) {
        let calendar = gameCalendar(calendar)
        let end = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -6, to: end)!
        let meaningful = quests.filter { $0.status == .completed && !$0.isLowImpact && $0.type != .recovery }
        let current = meaningful.filter { ($0.completedAt ?? .distantPast) >= start }.count
        let best = snapshots.map { snapshot in
            let previous = calendar.date(byAdding: .day, value: -6, to: snapshot.date)!
            let next = calendar.date(byAdding: .day, value: 1, to: snapshot.date)!
            return meaningful.filter { ($0.completedAt ?? .distantPast) >= previous && ($0.completedAt ?? .distantPast) < next }.count
        }.max() ?? 0
        return (current, max(best, current))
    }
    private mutating func seedBosses(now: Date, calendar: Calendar) {
        let calendar = gameCalendar(calendar)
        let week = calendar.dateInterval(of: .weekOfYear, for: now)!
        let month = calendar.dateInterval(of: .month, for: now)!
        for (interval, monthly, title) in [(week, false, "Book a qualified decision-maker conversation"), (month, true, "Acquire a paying customer for a working product")] {
            if bosses.contains(where: { boss in boss.monthly == monthly && quests.contains(where: { $0.id == boss.questID && interval.contains($0.createdAt) }) }) { continue }
            let quest = Quest(title: title, details: monthly ? "Ship a usable offer, solve a real problem and record payment." : "Identify a business with a specific workflow problem and secure a real conversation.", domain: .business, type: .boss, priority: .optional, difficulty: 1.5, impact: 1.5, baseXP: monthly ? 500 : 250, coinReward: monthly ? 200 : 100, evidenceRequirement: monthly ? "Payment record and product/customer reference." : "Meeting reference and a summary of the customer's problem.", estimatedMinutes: 60, deadline: interval.end.addingTimeInterval(-1), createdAt: now)
            quests.append(quest); bosses.append(BossFight(questID: quest.id, monthly: monthly, objective: profile.objective))
        }
    }
}
