import Foundation
import CryptoKit

public enum BackupError: Error, LocalizedError {
    case damaged, unsupported, tooLarge, conflict
    public var errorDescription: String? {
        switch self {
        case .damaged: "This backup is damaged or contains invalid records. Your current data was preserved."
        case .unsupported: "This backup requires a newer version of FORGE."
        case .tooLarge: "This backup exceeds the 32 MB limit."
        case .conflict: "Several devices changed this data. Review the preserved versions before continuing."
        }
    }
}

public struct ForgeBackup: Codable, Sendable {
    public let format: String
    public let version: Int
    public let createdAt: Date
    public let checksum: String
    public let payload: Data
    public static let maximumBytes = 32 * 1024 * 1024
    public init(session: GameSession, now: Date = Date()) throws {
        try session.validateForStorage()
        format = "FORGE-backup"; version = 1; createdAt = now
        payload = try Self.encoder.encode(session)
        checksum = Self.digest(payload)
    }
    public func encoded() throws -> Data {
        let data = try Self.encoder.encode(self)
        guard data.count <= Self.maximumBytes else { throw BackupError.tooLarge }
        return data
    }
    public static func restore(_ data: Data) throws -> GameSession {
        guard data.count <= maximumBytes else { throw BackupError.tooLarge }
        // Original V1 exports remain importable, with the same structural validation.
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let session: GameSession
        if json?["format"] != nil {
            let backup = try JSONDecoder().decode(Self.self, from: data)
            guard backup.format == "FORGE-backup", backup.version == 1 else { throw BackupError.unsupported }
            guard backup.checksum == digest(backup.payload) else { throw BackupError.damaged }
            session = try JSONDecoder().decode(GameSession.self, from: backup.payload)
        } else { session = try JSONDecoder().decode(GameSession.self, from: data) }
        try session.validateForStorage()
        return session
    }
    public static var encoder: JSONEncoder {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; return encoder
    }
    private static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
}

extension GameSession {
    public func validateForStorage() throws {
        guard schemaVersion == 1 else { throw BackupError.unsupported }
        guard config.isValid, profile.targetRevenue.isFinite, (1...1e12).contains(profile.targetRevenue),
              profile.baselineRevenue.isFinite, (0...1e12).contains(profile.baselineRevenue),
              (0...23).contains(profile.wakeHour), (0...23).contains(profile.sleepHour),
              (0...23).contains(profile.workStartHour), (0...23).contains(profile.workEndHour),
              (0...7).contains(profile.trainingDays), profile.name.count <= 200, profile.objective.count <= 2000,
              Set(ratings.keys) == Set(Domain.allCases), ratings.values.allSatisfy({ (0...100_000_000).contains($0) }),
              quests.count <= 100_000, skills.count <= 1000, skillEdges.count <= 10000, ledger.count <= 500_000, evidenceInbox.count <= 100_000, evidenceCursor >= 0,
              profile.aiEndpoint.count <= 2048, profile.aiEndpoint.isEmpty || URL(string:profile.aiEndpoint).map(PrivateHTTP.validEndpoint) == true else { throw BackupError.damaged }
        func unique<T: Identifiable>(_ records: [T]) -> Bool where T.ID: Hashable { Set(records.map(\.id)).count == records.count }
        guard unique(goals), unique(quests), unique(evidence), unique(ledger), unique(snapshots), unique(revenue),
              unique(customers), unique(activities), unique(skills), unique(skillEdges), unique(skillProgress), unique(bosses),
              unique(rewards), unique(redemptions), unique(screenRules), unique(bypasses), unique(recoveries), unique(reviews),
              unique(integrations), unique(recommendations), unique(seasons), unique(health), unique(evidenceInbox),
              ledger.allSatisfy({ (-100_000_000...100_000_000).contains($0.amount) && ($0.kind != .xp || $0.amount >= 0) && ($0.kind != .mmr || $0.domain != nil) }),
              totalXP >= 0, coins >= 0 else { throw BackupError.damaged }
        for proof in evidenceInbox { _ = try proof.validated() }
        for recommendation in recommendations { _ = try recommendation.validated() }
        let consumed = evidence.compactMap(\.externalEventID)
        guard Set(consumed).count == consumed.count, Set(consumed).isSubset(of:Set(evidenceInbox.map(\.id))) else { throw BackupError.damaged }
        let questIDs = Set(quests.map(\.id)), skillIDs = Set(skills.map(\.id))
        // A cycle can permanently lock the tree even though every reference exists.
        let dependencies = Dictionary(grouping: skillEdges, by: \.skillID)
        var visited = Set<UUID>(), visiting = Set<UUID>()
        func checkSkill(_ id: UUID) throws {
            if visiting.contains(id) { throw BackupError.damaged }
            if visited.contains(id) { return }
            visiting.insert(id)
            for edge in dependencies[id, default: []] { try checkSkill(edge.prerequisiteID) }
            visiting.remove(id); visited.insert(id)
        }
        for skill in skills { try checkSkill(skill.id) }
        var dates = quests.flatMap { [$0.createdAt, $0.deadline] + ($0.completedAt.map { [$0] } ?? []) } + ledger.map(\.timestamp) + snapshots.map(\.date) + revenue.map(\.date) + health.map(\.date)
        dates += [profile.createdAt] + goals.map(\.deadline) + reviews.map(\.date) + activities.map(\.date) + customers.map(\.createdAt)
        dates += seasons.flatMap { [$0.start, $0.end] } + redemptions.flatMap { [$0.startsAt, $0.expiresAt] } + skillProgress.map(\.updatedAt)
        dates += recommendations.map(\.createdAt) + evidence.map(\.timestamp) + recoveries.map(\.date) + bypasses.map(\.date)
        dates += integrations.compactMap(\.lastSync)
        dates += health.compactMap(\.wakeTime) + health.flatMap { Array($0.metrics?.values ?? [:].values).map(\.observedAt) }
        guard dates.allSatisfy({ $0.timeIntervalSince1970.isFinite && (-62_135_596_800...253_402_300_799).contains($0.timeIntervalSince1970) }),
              Set(skillProgress.map(\.skillID)).count == skillProgress.count,
              Set(bosses.map(\.questID)).count == bosses.count,
              Set(recoveries.map(\.questID)).count == recoveries.count,
              evidence.allSatisfy({ $0.reference?.count ?? 0 <= 2048 }),
              health.allSatisfy({ $0.metrics?.count ?? 0 <= 16 }),
              (profile.distractionNotes?.count ?? 0) <= 2000,
              (profile.rewardPreferences?.count ?? 0) <= 20,
              profile.gameTimeZoneID == nil || TimeZone(identifier: profile.gameTimeZoneID!) != nil else { throw BackupError.damaged }
        guard quests.allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.title.count <= 200 && $0.details.count <= 5000 && (0.1...2).contains($0.difficulty) && (0.1...2).contains($0.impact) && $0.mmrWeight.isFinite && (0.01...100).contains($0.mmrWeight) && (0...100_000).contains($0.baseXP) && (0...10_000).contains($0.coinReward) && (1...1440).contains($0.estimatedMinutes) && ($0.status != .completed || $0.completedAt != nil) }),
              evidence.allSatisfy({ questIDs.contains($0.questID) && $0.confidence.isFinite && (0...1).contains($0.confidence) && $0.note.count <= 10_000 }),
              bosses.allSatisfy({ questIDs.contains($0.questID) }), recoveries.allSatisfy({ questIDs.contains($0.questID) }),
              skillEdges.allSatisfy({ skillIDs.contains($0.skillID) && skillIDs.contains($0.prerequisiteID) && $0.skillID != $0.prerequisiteID }),
              skillProgress.allSatisfy({ skillIDs.contains($0.skillID) }),
              revenue.allSatisfy({ $0.amount.isFinite && (0...1e12).contains($0.amount) && $0.currency.count == 3 && $0.currency.allSatisfy({ $0.isASCII && $0.isUppercase }) }),
              customers.allSatisfy({ $0.value.isFinite && (0...1e15).contains($0.value) }),
              activities.allSatisfy({ (0...1_000_000).contains($0.count) }),
              rewards.allSatisfy({ (1...10_000).contains($0.cost) && (1...1440).contains($0.minutes) }),
              redemptions.allSatisfy({ (1...10_000).contains($0.cost) && $0.expiresAt > $0.startsAt }),
              screenRules.allSatisfy({ (0...60).contains($0.overrideDelay) && (0...35).contains($0.bypassPenalty) && (1...1440).contains($0.minutes) }),
              reviews.allSatisfy({ (1...5).contains($0.energy) && (1...5).contains($0.rating) }),
              health.allSatisfy({ $0.sleepHours.isFinite && (0...48).contains($0.sleepHours) && (0...1_000_000).contains($0.steps) && (0...100).contains($0.workouts) && (0...1440).contains($0.cardioMinutes) && $0.waterLiters.isFinite && (0...100).contains($0.waterLiters) && ($0.weight == nil || ($0.weight!.isFinite && (0...1000).contains($0.weight!))) && (0...1440).contains($0.screenMinutes) && (0...1440).contains($0.codingMinutes) }) else { throw BackupError.damaged }
    }
}

/// Immutable revision graph. Concurrent heads require explicit review; never add balances
/// from two devices, which could mint duplicate quest rewards or double-spend Coins.
public struct SessionRevision: Codable, Identifiable, Sendable {
    public let id: UUID
    public let parents: [UUID]
    public let createdAt: Date
    public let device: String
    public let payload: Data
    public init(session: GameSession, parents: [UUID], device: String, now: Date = Date()) throws {
        try self.init(backup: ForgeBackup(session: session, now: now), parents: parents, device: device)
    }
    private init(backup: ForgeBackup, parents: [UUID], device: String) throws {
        id = UUID(); self.parents = parents; createdAt = backup.createdAt; self.device = device
        payload = try backup.encoded()
    }
    /// Validate and encode a candidate once. The portable revision and raw state
    /// bytes can then be reused for automatic backup and no-op detection.
    public static func forSave(
        session: GameSession, parents: [UUID], device: String, unlessMatching previous: Data?
    ) throws -> (revision: SessionRevision, sessionPayload: Data)? {
        let backup = try ForgeBackup(session: session)
        guard backup.payload != previous else { return nil }
        let revision = try SessionRevision(backup: backup, parents: parents, device: device)
        return (revision, backup.payload)
    }
    public static func heads(in records: [SessionRevision]) -> [SessionRevision] {
        let parents = Set(records.flatMap(\.parents))
        return records.filter { !parents.contains($0.id) }.sorted { $0.createdAt < $1.createdAt }
    }
}
