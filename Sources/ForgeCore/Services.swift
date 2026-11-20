import Foundation

public struct AIContext: Codable, Sendable {
    public var contextVersion = 2; public var promptVersion = 2
    public var priorities: [String: Double] = [:]
    public var distractionState = "unmeasured"
    public var goal: String; public var targetRevenue: Double; public var monthlyRevenue: Double; public var ratings: [String: Int]; public var completed7Days: Int; public var unfinished: [String]; public var pipeline: [String: Int]; public var recentReview: String?; public var healthSummary: String?; public var calendarMinutes: Int; public var availableMinutes: Int; public var activityCounts: [String: Int]; public var completed30Days: Int; public var skillSummary: [String]; public var recentFailures: Int; public var season: String?
    public init(session: GameSession, now: Date = Date(), calendarMinutes: Int = 0) {
        goal = session.profile.objective; targetRevenue = session.profile.targetRevenue; monthlyRevenue = session.monthlyRevenue(now: now)
        ratings = Dictionary(uniqueKeysWithValues: session.ratings.map { ($0.key.rawValue, $0.value) })
        priorities = Dictionary(uniqueKeysWithValues: Domain.allCases.map { ($0.rawValue, session.config.weights[$0, default: 0]) })
        if let summary = session.health.sorted(by: { $0.date < $1.date }).last, summary.metric("screenMinutes", now: now).state == .available {
            distractionState = summary.screenMinutes > 120 ? "high" : "within planned range"
        }
        completed7Days = session.quests.filter { $0.status == .completed && ($0.completedAt ?? .distantPast) >= now.addingTimeInterval(-7 * 86400) }.count
        unfinished = session.todayQuests(now: now).filter { $0.status == .active }.prefix(5).map { "\($0.domain.rawValue) \($0.type.rawValue) \($0.priority.rawValue)" }
        pipeline = Dictionary(grouping: session.customers, by: \.stage).mapValues(\.count)
        let latestReview = session.reviews.max { lhs, rhs in
            // Merge order is based on identity, so chronology must come from the review itself.
            (lhs.date, lhs.id.uuidString) < (rhs.date, rhs.id.uuidString)
        }
        recentReview = latestReview.map { "Energy: \($0.energy); rating: \($0.rating); main correct: \($0.mainQuestCorrect)" }
        healthSummary = session.health.last.map { "Sleep metric: \($0.metric("sleepHours").state.rawValue); activity metric: \($0.metric("steps").state.rawValue); distraction metric: \($0.metric("screenMinutes").state.rawValue)" }
        self.calendarMinutes = max(0, calendarMinutes)
        availableMinutes = max(0, CalendarPlanning.remainingMinutes(profile: session.profile, now: now) - self.calendarMinutes)
        activityCounts = Dictionary(grouping: session.activities.filter { $0.date >= now.addingTimeInterval(-7 * 86400) }, by: { $0.kind.rawValue }).mapValues { $0.reduce(0) { $0 + $1.count } }
        completed30Days = session.quests.filter { $0.status == .completed && ($0.completedAt ?? .distantPast) >= now.addingTimeInterval(-30 * 86400) }.count
        skillSummary = session.skills.filter { session.state(for: $0) == .practicing || session.state(for: $0) == .verified }.prefix(8).map(\.title)
        recentFailures = session.quests.filter { $0.status == .missed && $0.deadline >= now.addingTimeInterval(-7 * 86400) }.count
        season = session.seasons.last?.title
    }
}
public struct QuestProposal: Codable, Identifiable, Sendable {
    public var id = UUID(); public var title: String; public var details: String; public var domain: Domain; public var priority: Priority; public var minutes: Int
    private enum CodingKeys: String, CodingKey { case id, title, details, domain, priority, minutes }
    public init(title: String, details: String, domain: Domain, priority: Priority, minutes: Int) { self.title = title; self.details = details; self.domain = domain; self.priority = priority; self.minutes = minutes }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decode(String.self, forKey: .title); details = try c.decode(String.self, forKey: .details)
        domain = try c.decode(Domain.self, forKey: .domain); priority = try c.decode(Priority.self, forKey: .priority); minutes = try c.decode(Int.self, forKey: .minutes)
    }
}
public struct AIRecommendation: Codable, Identifiable, Sendable {
    public var id = UUID(); public var message: String; public var quests: [QuestProposal]; public var createdAt = Date(); public var accepted = false
    private enum CodingKeys: String, CodingKey { case id, message, quests, createdAt, accepted }
    public init(message: String, quests: [QuestProposal] = []) { self.message = message; self.quests = quests }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(); message = try c.decode(String.self, forKey: .message)
        quests = try c.decode([QuestProposal].self, forKey: .quests); createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date(); accepted = try c.decodeIfPresent(Bool.self, forKey: .accepted) ?? false
    }
    public func validated(action: AIAction? = nil) throws -> AIRecommendation {
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, message.count <= 1200, quests.count <= 5,
              quests.allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.title.count <= 200 && $0.details.count <= 1500 && (5...180).contains($0.minutes) }),
              quests.filter({ $0.priority != .optional }).count <= 3,
              quests.filter({ $0.priority == .main }).count <= 1 else { throw GameError.invalidInput }
        switch action {
        case .dailyPlan:
            guard quests.isEmpty || quests.filter({ $0.priority == .main }).count == 1 else { throw GameError.invalidInput }
        case .recovery:
            guard quests.count == 1, quests[0].minutes <= 25 else { throw GameError.invalidInput }
        case .weeklyBoss:
            guard quests.count == 1 else { throw GameError.invalidInput }
        case .bottleneck, .weeklySummary:
            guard quests.isEmpty else { throw GameError.invalidInput }
        case nil: break
        }
        return self
    }
}
public enum AIAction: String, Codable, Sendable { case dailyPlan, bottleneck, recovery, weeklyBoss, weeklySummary }
public protocol AIService: Sendable {
    func recommend(action: AIAction, context: AIContext) async throws -> AIRecommendation
}
public struct MockAIService: AIService {
    public init() {}
    public func recommend(action: AIAction, context: AIContext) async throws -> AIRecommendation {
        switch action {
        case .dailyPlan:
            if context.availableMinutes < 15 { return AIRecommendation(message: "No feasible work capacity remains. Keep completed work, defer commitments to tomorrow, or explicitly choose a small recovery action when time becomes available.") }
            let buyerAction = context.pipeline["Proposal", default: 0] > 0 ? "Follow up one proposal with a concrete paid next step" : context.pipeline["Conversation", default: 0] + context.pipeline["Demo", default: 0] > 0 ? "Demonstrate one solution to a qualified buyer" : "Send personalized offers to qualified leads"
            let weakHealth = context.healthSummary?.contains("missing") == true
            let mainDomain = Domain.allCases.max { context.priorities[$0.rawValue, default: 0] < context.priorities[$1.rawValue, default: 0] } ?? .business
            let mainTitle = mainDomain == .builder ? "Ship one independently tested customer workflow" : mainDomain == .health ? "Complete a feasible session from your established training plan" : mainDomain == .network ? "Ask one relevant contact for a concrete introduction" : buyerAction
            let shrinking = context.recentFailures >= 2 || context.availableMinutes < 60
            let slice = max(5, min(shrinking ? 15 : 45, context.availableMinutes / 3))
            let secondary = context.unfinished.contains(where: { $0.contains("builder") }) ? "Finish the smallest testable part of your unfinished build" : "Demonstrate a practical capability without following a tutorial"
            let skill = context.skillSummary.first.map { "Apply \($0) independently; save a test or working demo." } ?? "Choose one capability from the skill tree; produce a working demo and pass tests."
            return AIRecommendation(message: "Goal: \(String(context.goal.prefix(160))). \(context.completed7Days) completed in 7 days; \(context.completed30Days) in 30. \(context.availableMinutes) minutes remain. \(shrinking ? "Recent misses or limited capacity call for smaller outcomes." : "Prioritize the next customer outcome.") \(context.distractionState == "high" ? "Use one focus block; measured distraction is high." : "")", quests: [.init(title: mainTitle, details: "Record the specific problem, meaningful result and evidence. Stop after \(slice) minutes.", domain: mainDomain, priority: .main, minutes: slice), .init(title: secondary, details: skill, domain: mainDomain == .builder ? .business : .builder, priority: .secondary, minutes: slice), .init(title: weakHealth ? "Record missing health context and take a short walk" : "Complete planned movement or explicitly choose planned rest", details: "Use your established plan. Missing readings are unknown, not failure.", domain: .health, priority: .supporting, minutes: slice)])
        case .bottleneck:
            let learning = context.activityCounts["learning", default: 0], conversations = context.activityCounts["conversation", default: 0]
            let message = learning > conversations ? "You recorded \(learning) learning activities and \(conversations) customer conversations this week. Remove another course from today's plan and test a specific offer with a qualified buyer." : context.monthlyRevenue == 0 ? "No revenue is recorded. Test a specific offer with a qualified buyer before expanding the product." : "Revenue is \(Int(context.monthlyRevenue)) KZT; this week has \(conversations) customer conversations. Repeat the offer that generated payment before adding features."
            return AIRecommendation(message: message)
        case .recovery: return AIRecommendation(message: "Shrink the day to one result: send one qualified prospect a specific offer. Stop after 25 minutes; recovery preserves momentum, not full rewards.", quests: [.init(title: "Send one qualified prospect a specific offer", details: "One real person, one concrete problem, one message.", domain: .business, priority: .main, minutes: 25)])
        case .weeklyBoss: return AIRecommendation(message: "This week's test is external: book a conversation with a decision maker who has a costly workflow problem.", quests: [.init(title: "Book a qualified decision-maker conversation", details: "Provide a meeting reference and the customer's problem.", domain: .business, priority: .optional, minutes: 60)])
        case .weeklySummary: return AIRecommendation(message: "\(context.completed7Days) quests completed in seven days. Monthly revenue: \(Int(context.monthlyRevenue)) KZT. Compare outputs and customer results, then remove work that produced neither.")
        }
    }
}
public struct RemoteAIService: AIService {
    public let endpoint: URL; public let token: String
    public init(endpoint: URL, token: String) { self.endpoint = endpoint; self.token = token }
    public func recommend(action: AIAction, context: AIContext) async throws -> AIRecommendation {
        guard PrivateHTTP.validEndpoint(endpoint) else { throw GameError.invalidInput }
        struct Request: Encodable { var action: AIAction; var context: AIContext }
        var request = URLRequest(url: endpoint); request.httpMethod = "POST"; request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !token.isEmpty { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONEncoder().encode(Request(action: action, context: context))
        let (data, response) = try await PrivateHTTP.session.data(for: request)
        try PrivateHTTP.validate(response, data: data, maximumBytes: 64_000)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let object, Set(object.keys) == ["message", "quests"], let proposals = object["quests"] as? [[String: Any]], proposals.allSatisfy({ Set($0.keys) == ["title", "details", "domain", "priority", "minutes"] }) else { throw GameError.invalidInput }
        return try JSONDecoder().decode(AIRecommendation.self, from: data).validated(action: action)
    }
}
public struct CalendarCommitment: Identifiable, Sendable { public var id: String; public var title: String; public var start: Date; public var end: Date; public init(id: String, title: String, start: Date, end: Date) { self.id = id; self.title = title; self.start = start; self.end = end } }
public protocol CalendarService: Sendable { func today() async throws -> [CalendarCommitment] }
public protocol HealthService: Sendable { func summary() async throws -> HealthSummary }
public protocol DistractionControl: Sendable { func authorize() async throws; func beginFocus(minutes: Int) async throws; func override(reason: String) async throws }
public protocol CodingActivityService: Sendable { func activeMinutes(since: Date) async throws -> Int }
public protocol LeetCodeService: Sendable { func proofReference() async throws -> String? }
public struct GitCommitProof: Sendable, Identifiable { public var id: String; public var title: String; public var url: String; public var date: Date }
public protocol GitHubService: Sendable { func recentCommits(repository: String) async throws -> [GitCommitProof] }
public struct GitHubAPIService: GitHubService {
    public var token: String
    public init(token: String) { self.token = token }
    public func recentCommits(repository: String) async throws -> [GitCommitProof] {
        let parts = repository.split(separator: "/")
        guard parts.count == 2, parts.allSatisfy({ $0.allSatisfy { $0.isLetter || $0.isNumber || "-_.".contains($0) } }) else { throw GameError.invalidInput }
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(repository)/commits?per_page=10")!); request.timeoutInterval = 20
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        if !token.isEmpty { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, response) = try await PrivateHTTP.session.data(for: request)
        try PrivateHTTP.validate(response, data: data, maximumBytes: 1_000_000)
        struct Commit: Decodable { var sha: String; var html_url: String; var commit: Content; struct Content: Decodable { var message: String; var author: Author; struct Author: Decodable { var date: Date } } }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Commit].self, from: data).map { .init(id: $0.sha, title: String($0.commit.message.prefix(200)), url: $0.html_url, date: $0.commit.author.date) }
    }
}

/// Credentials never follow a redirect to another origin. Ephemeral sessions do not
/// persist cookies or cached private context to disk.
private final class PrivateRedirectDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
public enum PrivateHTTP {
    public static let session = URLSession(configuration: .ephemeral, delegate: PrivateRedirectDelegate(), delegateQueue: nil)
    public static func validEndpoint(_ url: URL) -> Bool {
        url.user == nil && url.password == nil && url.fragment == nil && url.query == nil && url.host != nil && (url.scheme == "https" || (url.scheme == "http" && ["localhost", "127.0.0.1"].contains(url.host)))
    }
    public static func validate(_ response: URLResponse, data: Data, maximumBytes: Int) throws {
        guard let response = response as? HTTPURLResponse else { throw HTTPFailure.invalidResponse }
        switch response.statusCode {
        case 200: break
        case 401, 403: throw HTTPFailure.authorization
        case 429: throw HTTPFailure.rateLimited
        case 500...599: throw HTTPFailure.server
        default: throw HTTPFailure.invalidResponse
        }
        guard data.count <= maximumBytes else { throw HTTPFailure.oversized }
    }
}
public enum HTTPFailure: Error, LocalizedError {
    case authorization, rateLimited, server, invalidResponse, oversized
    public var errorDescription: String? {
        switch self {
        case .authorization: "Authorization failed. Check the scoped token and access permissions in Settings."
        case .rateLimited: "The service rate limit was reached. Wait before retrying; manual evidence and the local planner remain available."
        case .server: "The service is temporarily unavailable. Retry later; local records are preserved."
        case .invalidResponse: "The service returned an unexpected response. Check the endpoint and try again."
        case .oversized: "The response exceeds FORGE’s safety limit. Use a smaller import or plan."
        }
    }
}

public enum CalendarPlanning {
    public static func workWindow(profile: UserProfile, now: Date, calendar: Calendar) -> DateInterval? {
        guard (0...23).contains(profile.workStartHour), (0...23).contains(profile.workEndHour), profile.workStartHour != profile.workEndHour else { return nil }
        var start = calendar.date(bySettingHour: profile.workStartHour, minute: 0, second: 0, of: now)!
        var end = calendar.date(bySettingHour: profile.workEndHour, minute: 0, second: 0, of: now)!
        if end < start {
            if now < end { start = calendar.date(byAdding: .day, value: -1, to: start)! }
            else { end = calendar.date(byAdding: .day, value: 1, to: end)! }
        }
        guard end > max(start, now) else { return nil }
        return DateInterval(start: max(start, now), end: end)
    }
    public static func remainingMinutes(profile: UserProfile, now: Date = Date(), calendar: Calendar = .current) -> Int {
        workWindow(profile: profile, now: now, calendar: calendar).map { Int($0.duration / 60) } ?? 0
    }
    public static func occupiedMinutes(_ commitments: [CalendarCommitment], profile: UserProfile, now: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let window = workWindow(profile: profile, now: now, calendar: calendar) else { return 0 }
        let intervals = commitments.map { (max(window.start, $0.start), min(window.end, $0.end)) }.filter { $0.1 > $0.0 }.sorted { $0.0 < $1.0 }
        var seconds = 0.0, last = window.start
        for (a, b) in intervals { seconds += max(0, b.timeIntervalSince(max(a, last))); last = max(last, b) }
        return Int(ceil(seconds / 60))
    }
}
