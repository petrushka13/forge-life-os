import XCTest
@testable import ForgeCore

final class IntegrationRulesTests: XCTestCase {
    func testActionSpecificAIValidation() throws {
        let quest = QuestProposal(title: "Ship tested output", details: "Pass tests", domain: .builder, priority: .main, minutes: 60)
        XCTAssertThrowsError(try AIRecommendation(message: "Recover", quests: [quest]).validated(action: .recovery))
        XCTAssertThrowsError(try AIRecommendation(message: "Summary", quests: [quest]).validated(action: .weeklySummary))
        XCTAssertNoThrow(try AIRecommendation(message: "No capacity").validated(action: .dailyPlan))
        XCTAssertNoThrow(try AIRecommendation(message: "Boss", quests: [quest]).validated(action: .weeklyBoss))
    }
    func testLocalPlannerFitsCalendarAndDetectsConsumption() async throws {
        var state = GameSession(); state.onboard(profile: UserProfile())
        state.activities = [BusinessActivity(kind: .learning, count: 10)]
        let morning = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!
        let context = AIContext(session: state, now: morning, calendarMinutes: 480)
        let plan = try await MockAIService().recommend(action: .dailyPlan, context: context).validated(action: .dailyPlan)
        XCTAssertLessThanOrEqual(plan.quests.reduce(0) { $0 + $1.minutes }, context.availableMinutes)
        let advice = try await MockAIService().recommend(action: .bottleneck, context: context)
        XCTAssertTrue(advice.message.contains("10 learning"))
    }
    func testPlannerChoosesLatestReviewAfterMergeRegardlessOfOrder() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let newestDate = now.addingTimeInterval(-60)
        var newest = DailyReview(date: newestDate, moved: "", blocked: "", mainQuestCorrect: true, energy: 5, rating: 4)
        newest.id = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        var tied = DailyReview(date: newestDate, moved: "", blocked: "", mainQuestCorrect: false, energy: 2, rating: 2)
        tied.id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        var older = DailyReview(date: now.addingTimeInterval(-86_400), moved: "", blocked: "", mainQuestCorrect: false, energy: 1, rating: 1)
        older.id = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

        var local = GameSession()
        var imported = local
        local.reviews = [newest]
        imported.reviews = [older, tied]
        var merged = try XCTUnwrap(SafeSessionMerge.merge([local, imported]))

        let expected = "Energy: 5; rating: 4; main correct: true"
        XCTAssertEqual(AIContext(session: merged, now: now).recentReview, expected)
        merged.reviews.reverse()
        XCTAssertEqual(AIContext(session: merged, now: now).recentReview, expected)
    }
    func testCalendarOverlapAndOutOfWindowAreNotDoubleCounted() {
        let calendar = Calendar.current
        let now = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!
        func date(_ hour: Int) -> Date { calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now)! }
        let commitments = [CalendarCommitment(id: "a", title: "Private", start: date(9), end: date(11)), CalendarCommitment(id: "b", title: "Private", start: date(10), end: date(12)), CalendarCommitment(id: "c", title: "Private", start: date(20), end: date(22))]
        XCTAssertEqual(CalendarPlanning.occupiedMinutes(commitments, profile: UserProfile(), now: now), 180)
    }
    func testCredentialEndpointRules() {
        XCTAssertTrue(PrivateHTTP.validEndpoint(URL(string: "http://127.0.0.1:8787/v1/plan")!))
        XCTAssertFalse(PrivateHTTP.validEndpoint(URL(string: "http://example.com/v1/plan")!))
        XCTAssertFalse(PrivateHTTP.validEndpoint(URL(string: "https://secret@example.com/v1/plan")!))
    }
}
