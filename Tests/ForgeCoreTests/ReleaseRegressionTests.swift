import XCTest
@testable import ForgeCore

final class ReleaseRegressionTests: XCTestCase {
    let now = ISO8601DateFormatter().date(from: "2026-10-07T12:00:00Z")!
    var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    func testHugeFiniteAndNonfiniteInputsAreSafe() throws {
        for value in [Double.greatestFiniteMagnitude, .infinity, -.infinity, .nan, -1] {
            var config = GameConfig(); config.weights = [.business: value]
            XCTAssertFalse(config.isValid)
            XCTAssertEqual(GameEngine(config: config).lifeMMR([:]), 1000)
            var state = GameSession(); state.config = config
            XCTAssertThrowsError(try ForgeBackup(session: state))
        }
        XCTAssertLessThanOrEqual(GameEngine().lifeMMR([.business: Int.max]), 100_000_000)
        XCTAssertEqual(GameEngine().dailyDelta(.init(plannedWeight: .nan, completedWeight: .infinity)), 0)
    }
    func testCodingActiveMinutesMidnightOverlapAndImmutableIDs() throws {
        var state = GameSession()
        let proof = ExternalProof(id: "one", kind: "coding_session", project: "private-label", timestamp: "2026-10-06T23:59:00Z", start: "2026-10-06T23:30:00Z", end: "2026-10-07T00:30:00Z", minutes: 2)
        try state.importEvidence([proof, proof], now: now, calendar: utc)
        XCTAssertEqual(state.health.map(\.codingMinutes).reduce(0,+), 2)
        XCTAssertEqual(state.health.count, 2)
        let overlap = ExternalProof(id: "two", kind: "coding_session", project: "private-label", timestamp: proof.timestamp, start: proof.start, end: proof.end, minutes: 2)
        try state.importEvidence([overlap], now: now, calendar: utc)
        XCTAssertEqual(state.health.map(\.codingMinutes).reduce(0,+), 2)
        let changed = ExternalProof(id: "one", kind: "coding_session", project: "changed", timestamp: proof.timestamp, start: proof.start, end: proof.end, minutes: 2)
        XCTAssertThrowsError(try state.importEvidence([changed], now: now, calendar: utc))
        XCTAssertEqual(state.coins, 0)
        var single = GameSession()
        try single.importEvidence([ExternalProof(id: "minute", kind: "coding_session", project: "label", timestamp: "2026-10-07T10:00:00Z", start: "2026-10-07T09:00:00Z", end: "2026-10-07T10:00:00Z", minutes: 1)], now: now, calendar: utc)
        XCTAssertEqual(single.health.first?.codingMinutes, 1)
    }
    func testNoCapacityAndOvernightWindow() async throws {
        var state = GameSession(); state.onboard(profile: UserProfile(), now: now, calendar: utc)
        var context = AIContext(session: state, now: now); context.availableMinutes = 0
        let plan = try await MockAIService().recommend(action: .dailyPlan, context: context)
        XCTAssertTrue(plan.quests.isEmpty); XCTAssertNoThrow(try plan.validated(action: .dailyPlan))
        var profile = UserProfile(); profile.workStartHour = 22; profile.workEndHour = 6
        let midnight = ISO8601DateFormatter().date(from: "2026-10-07T00:00:00Z")!
        XCTAssertEqual(CalendarPlanning.remainingMinutes(profile: profile, now: midnight, calendar: utc), 360)
        XCTAssertEqual(CalendarPlanning.remainingMinutes(profile: UserProfile(), now: midnight.addingTimeInterval(20*3600), calendar: utc), 0)
    }
    func testRevenueAndBossShareOutcomeBudget() throws {
        var state = GameSession(); state.onboard(profile: UserProfile(), now: now, calendar: utc)
        try state.addRevenue(.init(amount: 1_000_000, client: "Customer", date: now), now: now, calendar: utc)
        let boss = state.quests.first { $0.type == .boss }!
        _ = try state.completeQuest(boss.id, proof: .init(questID: boss.id, note: "Meeting and received payment evidence"), now: now, calendar: utc)
        let outcome = state.ledger.filter { $0.kind == .mmr && ["Revenue milestone", "Boss outcome"].contains($0.reason) }.reduce(0) { $0 + $1.amount }
        XCTAssertEqual(outcome, state.config.maxOutcomeBonus)
    }
    func testHealthMergePreservesManualCodingScreenAndIdentity() {
        var state = GameSession()
        let manual = HealthSummary(date: now, sleepHours: 8, screenMinutes: 90, codingMinutes: 30)
        state.health = [manual]
        state.mergeHealth(.init(date: now, sleepHours: 6, steps: 8000, source: "Apple Health"), calendar: utc)
        XCTAssertEqual(state.health[0].id, manual.id)
        XCTAssertEqual(state.health[0].sleepHours, 8)
        XCTAssertEqual(state.health[0].steps, 8000)
        XCTAssertEqual(state.health[0].screenMinutes, 90)
        XCTAssertEqual(state.health[0].codingMinutes, 30)
        XCTAssertEqual(HealthSummary().metric("sleepHours").state, .missing)
    }
    func testAIPlanPreservesManualCompletedAndBossAndIsIdempotent() throws {
        var state = GameSession(); state.onboard(profile: UserProfile(), now: now, calendar: utc)
        let completed = state.todayQuests(now: now, calendar: utc)[0]
        _ = try state.completeQuest(completed.id, proof: .init(questID: completed.id, note: "Qualified outcome"), now: now, calendar: utc)
        var manual = state.quests.first { $0.domain == .builder && $0.type != .boss }!; manual.origin = nil
        state.quests[state.quests.firstIndex { $0.id == manual.id }!] = manual
        let bossIDs = state.bosses.map(\.id)
        let proposal = AIRecommendation(message: "Build output", quests: [.init(title: "Contact a buyer", details: "Outcome", domain: .business, priority: .main, minutes: 20), .init(title: "Walk", details: "Movement", domain: .health, priority: .supporting, minutes: 20)])
        try state.acceptRecommendation(proposal, action: .dailyPlan, now: now, calendar: utc)
        XCTAssertEqual(state.quests.first { $0.id == completed.id }?.status, .completed)
        XCTAssertEqual(state.quests.first { $0.id == manual.id }?.status, .active)
        XCTAssertEqual(state.bosses.map(\.id), bossIDs)
        XCTAssertThrowsError(try state.acceptRecommendation(proposal, action: .dailyPlan, now: now, calendar: utc))
        let weekly = AIRecommendation(message: "New boss", quests: [.init(title: "Ship", details: "Proof", domain: .builder, priority: .optional, minutes: 60)])
        XCTAssertThrowsError(try state.acceptRecommendation(weekly, action: .weeklyBoss, now: now, calendar: utc))
    }
    func testDSTSettlementIsOnceAndEvidenceCannotBeReplayed() throws {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let before = ISO8601DateFormatter().date(from: "2026-03-07T17:00:00Z")!
        let after = ISO8601DateFormatter().date(from: "2026-03-09T16:00:00Z")!
        var state = GameSession(); state.onboard(profile: UserProfile(), now: before, calendar: calendar)
        let quest = state.todayQuests(now: before, calendar: calendar)[0]
        _ = try state.completeQuest(quest.id, proof: .init(questID: quest.id, note: "Tested outcome", reference: "https://example.test/proof/one"), now: before, calendar: calendar)
        state.advanceDay(now: after, calendar: calendar)
        let ledger = state.ledger.map(\.id), xp = state.totalXP
        state.advanceDay(now: after, calendar: calendar)
        XCTAssertEqual(state.ledger.map(\.id), ledger); XCTAssertEqual(state.totalXP, xp)
        XCTAssertEqual(state.snapshots.filter(\.settled).count, 1)
        var travel = calendar; travel.timeZone = TimeZone(identifier: "Asia/Almaty")!
        state.advanceDay(now: after, calendar: travel)
        XCTAssertEqual(state.ledger.map(\.id), ledger)
        XCTAssertEqual(state.snapshots.count, 2)
        let next = state.todayQuests(now: after, calendar: calendar)[0]
        XCTAssertThrowsError(try state.completeQuest(next.id, proof: .init(questID: next.id, note: "Reused outcome", reference: "https://example.test/proof/one"), now: after, calendar: calendar))
    }
    func testPlannerUsesCapacityPipelineSkillsFailuresAndPriorities() async throws {
        var state = GameSession(); state.onboard(profile: UserProfile(), now: now, calendar: utc)
        state.customers.append(.init(name: "Private identity", stage: "Proposal"))
        var context = AIContext(session: state, now: now)
        context.availableMinutes = 35; context.recentFailures = 3; context.skillSummary = ["Python"]
        let plan = try await MockAIService().recommend(action: .dailyPlan, context: context)
        XCTAssertTrue(plan.quests[0].title.contains("proposal"))
        XCTAssertLessThanOrEqual(plan.quests.reduce(0) { $0 + $1.minutes },35)
        XCTAssertTrue(plan.quests[1].details.contains("Python"))
        context.priorities = ["builder": 1]
        let builderPlan = try await MockAIService().recommend(action: .dailyPlan, context: context)
        XCTAssertEqual(builderPlan.quests.first?.domain, .builder)
        XCTAssertFalse(String(data: try JSONEncoder().encode(context), encoding: .utf8)!.contains("Private identity"))
    }
    func testInvalidSkillCycleAndCurrencyIsolation() throws {
        var state = GameSession(); state.onboard(profile: UserProfile(), now: now, calendar: utc)
        let a = state.skills[0].id, b = state.skills[1].id
        state.skillEdges = [.init(prerequisiteID: b, skillID: a), .init(prerequisiteID: a, skillID: b)]
        XCTAssertThrowsError(try ForgeBackup(session: state))
        state.skillEdges = []
        let payment = RevenueEntry(amount: 500, currency: "USD", client: "Fixture", date: now)
        try state.addRevenue(payment, now: now, calendar: utc)
        XCTAssertEqual(state.monthlyRevenue(now: now, calendar: utc),0)
        XCTAssertEqual(state.customers.first?.value,0)
        XCTAssertThrowsError(try state.addRevenue(payment, now: now, calendar: utc))
        XCTAssertEqual(state.revenue.count,1)
    }
    func testLifeMMRTrendRoundsCompositeEndpointsOnce() {
        var state = GameSession()
        state.ratings[.business] = 1019
        state.ledger = [LedgerEntry(kind: .mmr, amount: 14, domain: .business, reason: "Performance", timestamp: now), LedgerEntry(kind: .mmr, amount: 5, domain: .business, reason: "Outcome", timestamp: now)]
        XCTAssertEqual(state.lifeMMR, 1009)
        XCTAssertEqual(state.lifeMMRChange(since: now.addingTimeInterval(-7*86400), now: now), 9)
        state.ledger.append(LedgerEntry(kind: .mmr, amount: 100, domain: .business, reason: "Future fixture", timestamp: now.addingTimeInterval(1)))
        XCTAssertEqual(state.lifeMMRChange(since: now.addingTimeInterval(-7*86400), now: now), 9)
    }
    func testHostileLegacyBackupDatesAreRejectedBeforeRestore() throws {
        var state = GameSession(); state.onboard(profile: UserProfile(), now: now, calendar: utc)
        state.profile.createdAt = Date(timeIntervalSince1970: 1e100)
        XCTAssertThrowsError(try ForgeBackup.restore(JSONEncoder().encode(state)))
        state.profile.createdAt = now
        state.integrations = [.init(name: "Fixture", state: .connected, message: "Synthetic", lastSync: Date(timeIntervalSince1970: -1e100))]
        XCTAssertThrowsError(try ForgeBackup.restore(JSONEncoder().encode(state)))
        state.integrations[0].lastSync = now
        XCTAssertNoThrow(try ForgeBackup.restore(JSONEncoder().encode(state)))
    }
    func testOverlappingWorkoutSourcesAndStaleLegacyMetrics() {
        let first = WorkoutSample(start: now, end: now.addingTimeInterval(1800), seconds: 1750, kind: 1)
        let duplicate = WorkoutSample(start: now.addingTimeInterval(5), end: now.addingTimeInterval(1805), seconds: 1800, kind: 1)
        let next = WorkoutSample(start: now.addingTimeInterval(3600), end: now.addingTimeInterval(5400), seconds: 1800, kind: 1)
        XCTAssertEqual(WorkoutSample.deduplicated([first, duplicate, next]).count, 2)
        XCTAssertEqual(HealthSummary(date: now.addingTimeInterval(-3*86400), steps: 5000).metric("steps", now: now).state, .stale)
    }
}

final class ReleaseVolumeTests: XCTestCase {
    func test365DaysTenThousandEvidenceAndSafeMerge() throws {
        let now = ISO8601DateFormatter().date(from:"2026-10-07T12:00:00Z")!
        var state = GameSession(); state.onboard(profile:UserProfile(),now:now.addingTimeInterval(-365*86400))
        for day in 0..<365 { state.advanceDay(now:now.addingTimeInterval(Double(day-364)*86400)) }
        let formatter=ISO8601DateFormatter()
        let records=(0..<10051).map { i in
            let start=now.addingTimeInterval(Double(i-10052)*60),end=start.addingTimeInterval(60)
            return ExternalProof(id:"volume-\(i)",kind:"coding_session",project:"workspace-private",timestamp:formatter.string(from:end),start:formatter.string(from:start),end:formatter.string(from:end),minutes:1)
        }
        let start=Date();try state.importEvidence(records,now:now)
        let importTime=Date().timeIntervalSince(start)
        let encoding=Date(),data=try ForgeBackup(session:state,now:now).encoded(), encodeTime=Date().timeIntervalSince(encoding)
        let decoding=Date();let restored=try ForgeBackup.restore(data);let decodeTime=Date().timeIntervalSince(decoding)
        XCTAssertEqual(restored.evidenceInbox.count,10051)
        XCTAssertEqual(restored.snapshots.count,366)
        let analytics=Date();_ = restored.ghost(now:now);_ = restored.streaks(now:now)
        let analyticsTime=Date().timeIntervalSince(analytics)
        print("FORGE volume: 366 days, 10051 evidence; import=\(importTime)s encode=\(encodeTime)s decode=\(decodeTime)s analytics=\(analyticsTime)s bytes=\(data.count)")
        XCTAssertLessThan(importTime,20);XCTAssertLessThan(decodeTime,10)
        var a=GameSession(),b=a;a.reviews.append(.init(moved:"A",blocked:"",mainQuestCorrect:true,energy:3,rating:3));b.activities.append(.init(kind:.conversation))
        let merged=try SafeSessionMerge.merge([a,b]);XCTAssertEqual(merged?.reviews.count,1);XCTAssertEqual(merged?.activities.count,1)
        b.ratings[.business]=1100;XCTAssertNil(try SafeSessionMerge.merge([a,b]))
    }
    func testNotificationPlanIsSparseAndOptionalMissDoesNotCreateRecoveryAlert() {
        var state=GameSession();let now=Date();state.onboard(profile:UserProfile(),now:now)
        let first=NotificationPlan.notices(session:state,now:now)
        XCTAssertLessThanOrEqual(first.count,3)
        XCTAssertEqual(first.map(\.id),NotificationPlan.notices(session:state,now:now).map(\.id))
        for i in state.quests.indices where state.quests[i].priority == .main { state.quests[i].status = .completed }
        XCTAssertFalse(NotificationPlan.notices(session:state,now:now).contains { $0.id.contains("risk") })
    }
}
