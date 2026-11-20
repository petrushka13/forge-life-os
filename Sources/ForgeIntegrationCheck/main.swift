import Foundation
import ForgeCore

@main struct IntegrationCheck {
    static func main() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let base = environment["FORGE_FIXTURE_URL"], let endpoint = URL(string: base + "/v1/plan"), let token = environment["FORGE_FIXTURE_TOKEN"] else { throw GameError.invalidInput }
        var session = GameSession(); session.onboard(profile: UserProfile())
        var context = AIContext(session: session); context.availableMinutes = 180
        let recommendation = try await RemoteAIService(endpoint: endpoint, token: token).recommend(action: .dailyPlan, context: context)
        try session.acceptRecommendation(recommendation, action: .dailyPlan)
        guard session.recommendations.last?.accepted == true else { throw GameError.invalidInput }
        let service = EvidenceAPIService(endpoint: endpoint, token: token)
        let page = try await service.fetch()
        try session.importEvidence(page.events)
        let continuation = try await service.fetch(cursor: page.nextCursor, serverID: page.serverID)
        guard page.events.count == 1, continuation.events.isEmpty, session.coins == 0 else { throw GameError.invalidInput }
        let quest = session.todayQuests().first { page.events[0].source != .codingActivity || $0.domain == .builder }!
        var proof = QuestEvidence(questID: quest.id, source: page.events[0].source, note: "Fixture independent implementation tested against acceptance criteria")
        proof.externalEventID = page.events[0].id
        _ = try session.completeQuest(quest.id, proof: proof)
        let restored = try ForgeBackup.restore(ForgeBackup(session: session).encoded())
        guard restored.coins > 0, restored.evidence.first?.externalEventID == page.events[0].id else { throw GameError.invalidInput }
        print("FORGE client/backend chain passed: HTTP plan, validation, acceptance, evidence cursor, completion, rewards and backup restore. Provider mode: local fixture.")
    }
}
