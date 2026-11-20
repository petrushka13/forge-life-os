import XCTest
@testable import ForgeCore

final class BackupTests: XCTestCase {
    func testRoundTripAndLegacyExport() throws {
        var state = GameSession(); state.onboard(profile: UserProfile())
        let quest = state.todayQuests().first!
        _ = try state.completeQuest(quest.id, proof: QuestEvidence(questID: quest.id, note: "Contacted ten qualified buyers"))
        let data = try ForgeBackup(session: state).encoded()
        let restored = try ForgeBackup.restore(data)
        XCTAssertEqual(restored.coins, state.coins)
        XCTAssertEqual(restored.ledger.map(\.id), state.ledger.map(\.id))
        XCTAssertEqual(try ForgeBackup.restore(JSONEncoder().encode(state)).lifeMMR, state.lifeMMR)
    }
    func testTamperingFutureVersionAndInvalidRecords() throws {
        var state = GameSession(); state.onboard(profile: UserProfile())
        let data = try ForgeBackup(session: state).encoded()
        var object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        object["checksum"] = "changed"
        XCTAssertThrowsError(try ForgeBackup.restore(JSONSerialization.data(withJSONObject: object)))
        state.quests.append(state.quests[0])
        XCTAssertThrowsError(try ForgeBackup(session: state))
        state.quests.removeLast(); state.schemaVersion = 999
        XCTAssertThrowsError(try ForgeBackup(session: state))
        state.schemaVersion = 1; state.ledger.append(LedgerEntry(kind: .xp, amount: -1, reason: "invalid"))
        XCTAssertThrowsError(try ForgeBackup(session: state))
    }
    func testConcurrentRevisionGraphPreservesBothBranches() throws {
        var state = GameSession(); state.onboard(profile: UserProfile())
        let root = try SessionRevision(session: state, parents: [], device: "Mac")
        let left = try SessionRevision(session: state, parents: [root.id], device: "Mac")
        let right = try SessionRevision(session: state, parents: [root.id], device: "iPhone")
        XCTAssertEqual(Set(SessionRevision.heads(in: [root, left, right]).map(\.id)), [left.id, right.id])
        let resolution = try SessionRevision(session: state, parents: [left.id, right.id], device: "Mac")
        XCTAssertEqual(SessionRevision.heads(in: [root, left, right, resolution]).map(\.id), [resolution.id])
    }
    func testExtremeConfigurationCannotOverflowScores() {
        var config = GameConfig(); config.mainQuestXP = Int.max
        XCTAssertFalse(config.isValid)
        config = GameConfig(); config.weights = [.business: Double.greatestFiniteMagnitude, .builder: Double.greatestFiniteMagnitude]
        XCTAssertFalse(config.isValid)
    }
}
