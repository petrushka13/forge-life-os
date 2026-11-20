import Foundation

public struct ExternalProof: Codable, Identifiable, Sendable {
    public let id: String
    public let kind: String
    public let project: String
    public let timestamp: String
    public let start: String?
    public let end: String?
    public let minutes: Int?
    public init(id: String, kind: String, project: String, timestamp: String, start: String? = nil, end: String? = nil, minutes: Int? = nil) {
        self.id = id; self.kind = kind; self.project = project; self.timestamp = timestamp; self.start = start; self.end = end; self.minutes = minutes
    }
    public var date: Date? { Self.parseDate(timestamp) }
    public var source: EvidenceSource { kind == "coding_session" ? .codingActivity : .webhook }
    public func validated(now: Date = Date()) throws -> ExternalProof {
        guard !id.isEmpty, id.count <= 200, !project.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, project.count <= 200,
              let date, date <= now.addingTimeInterval(300),
              ["workflow_created", "workflow_updated", "workflow_executed", "automation_deployed", "coding_session"].contains(kind) else { throw GameError.invalidInput }
        if kind == "coding_session" {
            guard let minutes, (1...120).contains(minutes), let start = start.flatMap(Self.parseDate), let end = end.flatMap(Self.parseDate), end <= now.addingTimeInterval(300), end > start, end.timeIntervalSince(start) <= 7200, Double(minutes * 60) <= end.timeIntervalSince(start) + 2 else { throw GameError.invalidInput }
        } else { guard start == nil, end == nil, minutes == nil else { throw GameError.invalidInput } }
        return self
    }
    public static func parseDate(_ value: String) -> Date? {
        let storage = Thread.current.threadDictionary
        func formatter(_ fractional: Bool) -> ISO8601DateFormatter {
            let key = fractional ? "forge.iso.fractional" : "forge.iso.seconds"
            if let existing = storage[key] as? ISO8601DateFormatter { return existing }
            let created = ISO8601DateFormatter()
            created.formatOptions = fractional ? [.withInternetDateTime,.withFractionalSeconds] : [.withInternetDateTime]
            storage[key] = created
            return created
        }
        return formatter(true).date(from:value) ?? formatter(false).date(from:value)

    }
}

public struct EvidencePage: Codable, Sendable {
    public let events: [ExternalProof]
    public let nextCursor: Int
    public let hasMore: Bool
    public let serverID: String
}
public struct EvidenceAPIService: Sendable {
    public let endpoint: URL; public let token: String
    public init(endpoint: URL, token: String) { self.endpoint = endpoint; self.token = token }
    public func fetch(cursor: Int = 0, serverID: String? = nil) async throws -> EvidencePage {
        guard PrivateHTTP.validEndpoint(endpoint), endpoint.path.hasSuffix("/v1/plan"), !token.isEmpty, cursor >= 0 else { throw GameError.invalidInput }
        var parts = URLComponents(url: endpoint.deletingLastPathComponent().appendingPathComponent("events"), resolvingAgainstBaseURL: false)!
        parts.queryItems = [URLQueryItem(name: "cursor", value: String(cursor))]
        if let serverID { parts.queryItems!.append(URLQueryItem(name: "serverID", value: serverID)) }
        var request = URLRequest(url: parts.url!); request.timeoutInterval = 20
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await PrivateHTTP.session.data(for: request)
        try PrivateHTTP.validate(response, data: data, maximumBytes: 256_000)
        let page = try JSONDecoder().decode(EvidencePage.self, from: data)
        guard page.events.count <= 100, page.nextCursor >= 0, !page.serverID.isEmpty,
              page.serverID != serverID || !page.hasMore || page.nextCursor > cursor else { throw GameError.invalidInput }
        _ = try page.events.map { try $0.validated() }
        return page
    }
}

extension GameSession {
    public mutating func importEvidence(_ records: [ExternalProof], now: Date = Date(), calendar: Calendar = .current) throws {
        let valid = try records.map { try $0.validated(now: now) }
        var unique = Dictionary(uniqueKeysWithValues: evidenceInbox.map { ($0.id, $0) })
        for record in valid {
            if let previous = unique[record.id] {
                guard try ForgeBackup.encoder.encode(previous) == ForgeBackup.encoder.encode(record) else { throw GameError.invalidInput }
            } else { unique[record.id] = record }
        }
        evidenceInbox = unique.values.map { ($0, $0.date ?? .distantPast) }.sorted { $0.1 < $1.1 }.map(\.0)
        // Active minutes are independent of the enclosing interval. Uniform density is
        // conservative when exact active subintervals are unavailable; overlapping
        // reports use the maximum density, never the sum. Split at local midnight.
        struct Edge { let date: Date; let id: String; let density: Double; let starts: Bool }
        var days: [Date: [Edge]] = [:]
        for proof in evidenceInbox where proof.kind == "coding_session" {
            guard let a = proof.start.flatMap(ExternalProof.parseDate), let b = proof.end.flatMap(ExternalProof.parseDate), let minutes = proof.minutes else { continue }
            let density = min(1, Double(minutes) * 60 / b.timeIntervalSince(a))
            var part = a
            while part < b {
                let day = calendar.startOfDay(for: part), end = min(b, calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: part))!)
                days[day, default: []].append(Edge(date: part, id: proof.id, density: density, starts: true))
                days[day, default: []].append(Edge(date: end, id: proof.id, density: density, starts: false))
                part = end
            }
        }
        for (day, edges) in days {
            var active: [String: Double] = [:], last = day, seconds = 0.0
            for edge in edges.sorted(by: { $0.date < $1.date }) {
                seconds += edge.date.timeIntervalSince(last) * (active.values.max() ?? 0)
                if edge.starts { active[edge.id] = edge.density } else { active.removeValue(forKey: edge.id) }
                last = edge.date
            }
            let minutes = min(1440, Int((seconds / 60 + 1e-8).rounded(.down)))
            var summary = HealthSummary(date: day, codingMinutes: minutes, source: "VS Code activity")
            summary.metrics = ["codingMinutes": HealthMetric(source: "VS Code activity", observedAt: now, state: .available)]
            mergeHealth(summary, calendar: calendar)
        }
        health.sort { $0.date < $1.date }
    }
}
