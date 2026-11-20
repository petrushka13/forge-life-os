import Foundation

public enum SeedData {
    public static var rewards: [Reward] {
        [Reward(title: "YouTube", cost: 30, minutes: 30, symbol: "play.rectangle"), Reward(title: "Instagram", cost: 35, minutes: 20, symbol: "camera"), Reward(title: "Dota match", cost: 80, minutes: 60, symbol: "gamecontroller"), Reward(title: "Free evening", cost: 200, minutes: 180, symbol: "moon.stars")]
    }
    public static func dailyPlan(now: Date, calendar: Calendar = .current, config: GameConfig = GameConfig()) -> [Quest] {
        let deadline = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now)!
        let day = calendar.component(.weekday, from: now)
        let business = day % 2 == 0 ? "Send 10 personalized messages to qualified leads" : "Ask 5 prospects about their current workflow"
        let builder = day % 2 == 0 ? "Implement one API endpoint and pass its tests" : "Ship a working demo of one customer workflow"
        return [Quest(title: business, details: "Target people with a concrete workflow problem. Record who you contacted and what you learned.", domain: .business, priority: .main, baseXP: config.mainQuestXP, coinReward: config.mainQuestCoins, estimatedMinutes: 45, deadline: deadline, createdAt: now), Quest(title: builder, details: "Create an observable output. A commit or demo link is useful proof; hours watching tutorials are not the outcome.", domain: .builder, type: .skill, priority: .secondary, baseXP: 100, coinReward: 35, estimatedMinutes: 60, deadline: deadline, createdAt: now), Quest(title: "Complete a planned workout or 8,000 steps", details: "Follow your existing training plan. Use planned rest when appropriate.", domain: .health, type: .health, priority: .supporting, baseXP: 70, coinReward: 25, estimatedMinutes: 35, deadline: deadline, createdAt: now)]
    }
    public static func skillGraph() -> ([Skill], [SkillEdge]) {
        let definitions: [(String, String, String, Int?)] = [
            ("Python foundations", "Python", "Write a typed script using collections, functions and error handling; pass tests.", nil),
            ("Modules & testing", "Python", "Package a reusable module with typing, pytest and meaningful failure cases.", 0),
            ("Async Python", "Python", "Implement concurrent I/O with cancellation and tests.", 1),
            ("HTTP & REST", "Backend", "Explain requests, status codes and validation by building an endpoint.", 1),
            ("Production API", "Backend", "Deploy a FastAPI service with authentication, validation and tests.", 3),
            ("SQL & schemas", "Databases", "Model customer data and write joins and transactions in PostgreSQL.", 0),
            ("Indexes & reliability", "Databases", "Use an execution plan and constraints to improve a real query.", 5),
            ("LLM structured output", "AI Engineering", "Validate structured model output with explicit failure handling.", 4),
            ("Retrieval & evaluation", "AI Engineering", "Build retrieval with embeddings and measure it against a small evaluation set.", 7),
            ("Reliable tool workflows", "AI Engineering", "Ship a bounded tool workflow with observability and safety checks.", 8),
            ("Webhooks & integrations", "Automation", "Connect two APIs using authenticated webhooks and retries.", 4),
            ("Production automation", "Automation", "Deploy an n8n or queue workflow that solves a customer problem.", 10),
            ("Git & debugging", "Product Engineering", "Ship a reviewed change and explain a root-cause diagnosis.", nil),
            ("Deploy & observe", "Product Engineering", "Deploy a product, collect useful telemetry and recover from a failure.", 12),
            ("Customer discovery", "Sales", "Conduct five conversations and describe a repeated costly problem.", nil),
            ("Offer & close", "Sales", "Make a concrete proposal and receive payment for a solved problem.", 14)
        ]
        let skills = definitions.map { Skill(title: $0.0, category: $0.1, objective: $0.2) }
        let edges = definitions.enumerated().compactMap { index, item in item.3.map { SkillEdge(prerequisiteID: skills[$0].id, skillID: skills[index].id) } }
        return (skills, edges)
    }
    public static func demo(now: Date = Date(), calendar: Calendar = .current) -> GameSession {
        var session = GameSession()
        var profile = UserProfile(); profile.name = "Demo Player"; profile.baselineRevenue = 0
        let start = calendar.date(byAdding: .day, value: -35, to: now)!
        session.onboard(profile: profile, now: start, calendar: calendar)
        for offset in 0...35 {
            let date = calendar.date(byAdding: .day, value: offset, to: start)!
            session.advanceDay(now: date, calendar: calendar)
            for quest in session.todayQuests(now: date, calendar: calendar) where offset < 35 && (offset % 5 != 0 || quest.domain == .business) {
                _ = try? session.completeQuest(quest.id, proof: QuestEvidence(questID: quest.id, note: "Demo: meaningful output recorded", timestamp: date), now: date, calendar: calendar)
            }
            session.health.append(HealthSummary(date: date, sleepHours: 6.4 + Double(offset % 4) * 0.4, steps: 5500 + offset * 110, workouts: offset % 3 == 0 ? 1 : 0, cardioMinutes: offset % 3 == 0 ? 25 : 0, waterLiters: 2, screenMinutes: max(100, 350 - offset * 5), codingMinutes: 65 + offset, source: "Demo"))
            session.activities.append(BusinessActivity(kind: .outreach, count: 3, date: date))
            if offset % 4 == 0 { session.activities.append(BusinessActivity(kind: .conversation, date: date)) }
        }
        try? session.addRevenue(RevenueEntry(amount: 150_000, client: "Studio North", date: now.addingTimeInterval(-86400)), now: now, calendar: calendar)
        try? session.addRevenue(RevenueEntry(amount: 200_000, client: "Workflow Labs", date: now, recurring: true), now: now, calendar: calendar)
        session.activities.append(BusinessActivity(kind: .shipped, count: 3, date: now))
        for skill in session.skills.prefix(2) { try? session.updateSkill(skill.id, state: .verified, proof: "Demo: tested project implementation", now: now) }
        return session
    }
}
