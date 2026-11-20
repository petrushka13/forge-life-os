import Foundation

public enum SafeSessionMerge {
    /// Merge independent append-only notes/references only when scoring state is
    /// identical. Conflicting balances, quest edits or policies require review.
    public static func merge(_ sessions: [GameSession]) throws -> GameSession? {
        guard var merged = sessions.first else { return nil }
        let safe: Set<String> = ["reviews", "activities", "evidenceInbox"]
        func protected(_ state: GameSession) throws -> Data {
            var object = try JSONSerialization.jsonObject(with: ForgeBackup.encoder.encode(state)) as! [String: Any]
            for key in safe { object.removeValue(forKey: key) }
            return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        }
        let reference = try protected(merged)
        func union<T: Codable & Identifiable>(_ a: [T], _ b: [T]) throws -> [T]? where T.ID: Hashable {
            var values = Dictionary(uniqueKeysWithValues: a.map { ($0.id, $0) })
            for value in b {
                if let previous = values[value.id], try ForgeBackup.encoder.encode(previous) != ForgeBackup.encoder.encode(value) { return nil }
                values[value.id] = value
            }
            return values.values.sorted { String(describing: $0.id) < String(describing: $1.id) }
        }
        for state in sessions.dropFirst() {
            guard try protected(state) == reference,
                  let reviews = try union(merged.reviews, state.reviews),
                  let activities = try union(merged.activities, state.activities),
                  let inbox = try union(merged.evidenceInbox, state.evidenceInbox) else { return nil }
            merged.reviews = reviews; merged.activities = activities; merged.evidenceInbox = inbox
        }
        try merged.validateForStorage()
        return merged
    }
}
