import Foundation

public struct ForgeDiagnostics: Encodable, Sendable {
    public let format = "FORGE-redacted-diagnostics"
    public let schemaVersion = 1
    public let createdAt: Date
    public let appVersion: String
    public let records: [String:Int]
    public let capabilities: [String:Bool]
    public init(session:GameSession,version:String,capabilities:[String:Bool],now:Date=Date()) {
        createdAt=now;appVersion=version;self.capabilities=capabilities
        records=["quests":session.quests.count,"ledger":session.ledger.count,"evidence":session.evidence.count,"externalEvidence":session.evidenceInbox.count,"snapshots":session.snapshots.count]
    }
}
