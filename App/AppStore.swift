import SwiftUI
import Observation
import ForgeCore
import SwiftData
#if os(iOS)
import AudioToolbox
#else
import AppKit
#endif

@MainActor @Observable final class AppStore {
    private(set) var session = GameSession()
    private(set) var repository: SessionRepository?
    var error: String?
    var launchError: String?
    var syncConflicts: [SessionRevision] = []
    var restoreCandidate: GameSession?
    var toast: String?
    var aiBusy = false
    var aiMessage = "Your first bottleneck is evidence of demand. Talk to qualified prospects before expanding the product."
    var proposals: AIRecommendation?
    var proposalAction: AIAction = .dailyPlan
    var commitments: [CalendarCommitment] = []
    var gitProofs: [GitCommitProof] = []
    var isTesting: Bool { CommandLine.arguments.contains("--ui-test") }
    let isDemo: Bool
    private(set) var purgePending = false
    private var workspaceGeneration = 0
    private static let purgeInterrupted = "Local purge did not finish. Some data may already be removed. Retry cleanup to finish the confirmed purge."
    init(demo: Bool = false) {
        isDemo = demo
        do {
            let testing = CommandLine.arguments.contains("--ui-test")
            if !demo && !testing {
                do {
                    if try Self.localPurge.pendingCredentials() != nil {
                        purgePending = true
                        launchError = Self.purgeInterrupted
                        return
                    }
                } catch {
                    purgePending = true
                    throw error
                }
            }
            let args = CommandLine.arguments
            let fixture = testing ? args.firstIndex(of:"--persistent-fixture").flatMap { index -> URL? in
                guard index + 1 < args.count, UUID(uuidString:args[index+1]) != nil else { return nil }
                return FileManager.default.temporaryDirectory.appendingPathComponent("forge-ui-\(args[index+1]).store")
            } : nil
            repository = try SessionRepository(memory: demo || (testing && fixture == nil), url: testing ? fixture : demo ? nil : Self.recoveryStore, cloud: Capabilities.cloud && !demo && !testing && UserDefaults.standard.bool(forKey: "forge.cloud"))
            session = demo ? SeedData.demo() : try repository!.load()
            if session.profile.onboarded { try mutate { $0.advanceDay() } }
        } catch let conflict as SyncConflict { syncConflicts = conflict.versions }
        catch { launchError = error.localizedDescription }
    }
    init(repository: SessionRepository) throws { isDemo = true; self.repository = repository; session = try repository.load() }
    func retryStorage() {
        guard !purgePending else { return }
        do { repository = try SessionRepository(memory: isDemo, url: isDemo ? nil : Self.recoveryStore); session = try repository!.load(); launchError = nil; refreshDay() }
        catch { launchError = error.localizedDescription }
    }
    func mutate(_ change: (inout GameSession) throws -> Void) throws {
        guard !purgePending, let repository else { throw GameError.missingRecord }
        var next = session
        try change(&next)
        do { try repository.save(next) }
        catch let conflict as SyncConflict { syncConflicts = conflict.versions; throw conflict }
        session = next
        if !isDemo && !isTesting { Task { do { try await ForgeNotifications.refresh(session: next) } catch { self.error = "Records saved. Notification scheduling failed; open FORGE for today’s plan." } } }
        if let warning = repository.backupError { error = warning }
    }
    @discardableResult func perform(_ change: (inout GameSession) throws -> Void, success: String? = nil) -> Bool {
        do { try mutate(change); if let success { notify(success) }; return true }
        catch { self.error = error.localizedDescription; return false }
    }
    func notify(_ text: String) {
        toast = text
        Task { try? await Task.sleep(for: .seconds(4)); if toast == text { toast = nil } }
    }
    func refreshDay() {
        guard syncConflicts.isEmpty, launchError == nil else { return }
        do {
            if let repository { session = try repository.load() }
            if session.profile.onboarded { try mutate { $0.advanceDay() } }
        } catch let conflict as SyncConflict { syncConflicts = conflict.versions }
        catch { self.error = error.localizedDescription }
    }
    func resolveSync(_ revision: SessionRevision, merged: GameSession? = nil) {
        do {
            guard let repository else { throw GameError.missingRecord }
            session = try repository.resolve(revision, merged: merged); syncConflicts = []; refreshDay()
        } catch let conflict as SyncConflict { syncConflicts = conflict.versions; self.error = conflict.localizedDescription }
        catch { self.error = error.localizedDescription }
    }
    func prepareRestore(_ data: Data) throws { restoreCandidate = try ForgeBackup.restore(data) }
    func confirmRestore() throws {
        guard let restoreCandidate, let repository else { throw GameError.missingRecord }
        repository.backup(session,preserving:true)
        guard repository.backupError == nil else { throw BackupError.damaged }
        try mutate { $0 = restoreCandidate }
        self.restoreCandidate = nil
        refreshDay()
    }
    func redeemReward(_ reward: Reward) {
        do {
            var next = session; try next.redeem(reward.id)
            var granted = false
            #if os(iOS)
            if !isDemo && !isTesting && Capabilities.screenTime && ScreenTimeController.shared.earned {
                try ScreenTimeController.shared.grant(minutes: reward.minutes); granted = true
            }
            #endif
            do { try mutate { $0 = next } }
            catch {
                #if os(iOS)
                if granted { ScreenTimeController.shared.revokeGrant() }
                #endif
                throw error
            }
            notify("\(reward.title) unlocked for \(reward.minutes) minutes")
        } catch { self.error = error.localizedDescription }
    }
    func purgeLocalData(credentials: Bool) throws {
        guard !isDemo, !isTesting, !purgePending else { throw GameError.invalidInput }
        try beginLocalPurge(credentials: credentials)
        try retryLocalPurge()
    }
    private func beginLocalPurge(credentials: Bool) throws {
        guard let repository else { throw GameError.missingRecord }
        guard repository.canPurgeLocally else {
            throw NSError(domain: "FORGE", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "Turn off iCloud sync and restart FORGE before purging local data."
            ])
        }
        try Self.localPurge.begin(credentials: credentials)
        purgePending = true
        do {
            try repository.purgeLocal()
        } catch {
            let commitError = error
            do { try Self.localPurge.clear(); purgePending = false }
            catch { launchError = Self.purgeInterrupted }
            throw commitError
        }
        self.repository = nil
        workspaceGeneration += 1
        session = GameSession()
        gitProofs = []; commitments = []; proposals = nil; restoreCandidate = nil; syncConflicts = []
        toast = nil; aiBusy = false; aiMessage = "Choose one concrete result for today."
    }
    func retryLocalPurge() throws {
        guard !isDemo, !isTesting, purgePending else { throw GameError.invalidInput }
        do {
            guard let credentials = try Self.localPurge.pendingCredentials() else { throw GameError.missingRecord }
            // On interrupted launch the store intentionally remains unopened. In
            // this process release any local store before unlinking its files.
            repository = nil
            let files = ["-wal", "-shm", ""].map { URL(fileURLWithPath: Self.defaultStore.path + $0) }
            try Self.localPurge.finish(files: files + [Self.storageRoot]) {
                if credentials {
                    try Keychain.delete("proxy-token")
                    try Keychain.delete("github-token")
                }
                #if os(iOS)
                if Capabilities.screenTime { ScreenTimeController.shared.eraseSelection() }
                #endif
                for key in ["forge.cloud", "forge.notifications", "forge.focusEnd", "forge.appearance", "forge.noticeIDs", "forge.recoveryStore"] {
                    UserDefaults.standard.removeObject(forKey: key)
                }
                ForgeNotifications.purge()
                let fresh = try SessionRepository()
                session = try fresh.load()
                repository = fresh
            }
            purgePending = false
            launchError = nil
        } catch {
            launchError = Self.purgeInterrupted
            throw error
        }
    }
    private static var applicationSupport: URL { FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0] }
    private static var storageRoot: URL { applicationSupport.appendingPathComponent("FORGE", isDirectory: true) }
    private static var localPurge: LocalPurge { LocalPurge(marker: applicationSupport.appendingPathComponent("FORGE-purge.json")) }
    private static var recoveryStore: URL? { UserDefaults.standard.string(forKey: "forge.recoveryStore").map { URL(fileURLWithPath: $0) } }
    private static var defaultStore: URL { ModelConfiguration("FORGE", schema: Schema([StoredRecord.self, StoredRevision.self]), cloudKitDatabase: .none).url }
    func recoveryCopy() throws -> Data {
        if let repository { return try repository.exportRecoveryArchive() }
        struct RecoveryFile: Codable { let name: String; let bytes: Data }
        let url = Self.recoveryStore ?? Self.defaultStore
        var files: [RecoveryFile] = []
        for suffix in ["", "-wal", "-shm"] {
            let path = URL(fileURLWithPath: url.path + suffix)
            if FileManager.default.fileExists(atPath: path.path) {
                guard (try path.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 128 * 1024 * 1024 else { throw BackupError.tooLarge }
                files.append(RecoveryFile(name: "store" + suffix, bytes: try Data(contentsOf: path)))
            }
        }
        guard !files.isEmpty else { throw GameError.missingRecord }
        return try ForgeBackup.encoder.encode(files)
    }
    func recoverStorage(_ candidate: GameSession) throws {
        guard !purgePending else { throw GameError.invalidInput }
        try candidate.validateForStorage()
        let directory = Self.storageRoot.appendingPathComponent("Recovered", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let url = directory.appendingPathComponent("\(UUID()).store")
        let fresh = try SessionRepository(url: url)
        _ = try fresh.load(); try fresh.save(candidate)
        // The original database is untouched; the switch occurs only after a successful write.
        UserDefaults.standard.set(url.path, forKey: "forge.recoveryStore")
        repository = fresh; session = candidate; launchError = nil; syncConflicts = []; refreshDay()
    }
    func complete(_ quest: Quest, note: String, reference: String = "", gitProof: GitCommitProof? = nil, externalProof: ExternalProof? = nil, healthReference: String = "") -> Bool {
        do {
            let level = session.engine.level(totalXP: session.totalXP).level
            let rank = session.engine.rank(session.lifeMMR)
            var result: QuestReward?
            try mutate {
                var proof = QuestEvidence(questID: quest.id, source: gitProof == nil ? .manual : .gitCommit, note: note, reference: gitProof?.url ?? (reference.isEmpty ? nil : reference))
                if !healthReference.isEmpty {
                    guard quest.domain == .health, let summary = $0.health.first(where: { Calendar.current.isDateInToday($0.date) }),
                          let metric = ["steps", "workouts", "cardioMinutes", "sleepHours"].first(where: { healthReference == "forge-health:\(summary.id):\($0)" }),
                          summary.metric(metric).state == .available, summary.metric(metric).source == "Apple Health" else { throw GameError.invalidInput }
                    proof.source = .appleHealth; proof.confidence = EvidenceSource.appleHealth.confidence; proof.reference = healthReference
                }
                if let externalProof {
                    guard $0.evidenceInbox.contains(where: { $0.id == externalProof.id }), !$0.evidence.contains(where: { $0.externalEventID == externalProof.id }) else { throw GameError.alreadyCompleted }
                    proof.source = externalProof.source; proof.confidence = externalProof.source.confidence
                    proof.externalEventID = externalProof.id; proof.reference = "\(externalProof.project) · \(externalProof.kind) · \(externalProof.id)"
                }
                result = try $0.completeQuest(quest.id, proof: proof)
            }
            let newLevel = session.engine.level(totalXP: session.totalXP).level
            let newRank = session.engine.rank(session.lifeMMR)
            let prefix = newRank != rank ? "Promoted to \(newRank). " : newLevel > level ? "Level \(newLevel). " : quest.type == .boss ? "Boss defeated. " : "Quest complete. "
            notify(prefix + "+\(result?.xp ?? 0) XP · +\(result?.coins ?? 0) Coins")
            #if os(iOS)
            if session.profile.haptics { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            if session.profile.sound { AudioServicesPlaySystemSound(1057) }
            #else
            if session.profile.sound { NSSound(named: "Tink")?.play() }
            #endif
            return true
        } catch { self.error = error.localizedDescription; return false }
    }
    func askGM(_ action: AIAction) async {
        guard !aiBusy, !purgePending else { return }
        let generation = workspaceGeneration
        aiBusy = true
        defer { if generation == workspaceGeneration { aiBusy = false } }
        let context = AIContext(session: session, calendarMinutes: CalendarPlanning.occupiedMinutes(commitments, profile: session.profile))
        do {
            let service: any AIService
            if session.profile.aiEnabled {
                guard let url = URL(string: session.profile.aiEndpoint) else { throw GameError.invalidInput }
                service = RemoteAIService(endpoint: url, token: try Keychain.readValue("proxy-token") ?? "")
            } else { service = MockAIService() }
            let recommendation = try await service.recommend(action: action, context: context).validated(action: action)
            guard isCurrent(generation) else { return }
            if action == .dailyPlan, recommendation.quests.reduce(0, { $0 + $1.minutes }) > context.availableMinutes { throw GameError.invalidInput }
            aiMessage = recommendation.message
            proposalAction = action
            proposals = recommendation.quests.isEmpty ? nil : recommendation
            perform { $0.recommendations.append(recommendation) }
        } catch {
            let fallback = try? await MockAIService().recommend(action: action, context: context)
            guard isCurrent(generation) else { return }
            proposalAction = action; proposals = fallback?.quests.isEmpty == false ? fallback : nil
            aiMessage = fallback?.message ?? "Choose one concrete customer outcome today."
            self.error = "Remote Game Master unavailable. The local plan still works. \(error.localizedDescription)"
        }
    }
    @discardableResult func acceptPlan(replaceBoss: Bool = false) -> Bool {
        guard let proposal = proposals else { return false }
        let succeeded = perform { try $0.acceptRecommendation(proposal, action: proposalAction, replaceBoss: replaceBoss) }
        if succeeded { proposals = nil }
        return succeeded
    }
    func importGitHub() async {
        guard !purgePending else { return }
        let generation = workspaceGeneration
        do {
            let proofs = try await GitHubAPIService(token: try Keychain.readValue("github-token") ?? "").recentCommits(repository: session.profile.githubRepository)
            guard isCurrent(generation) else { return }
            gitProofs = proofs
            notify("Fetched \(proofs.count) commits. Select relevant proof when completing a quest.")
        } catch {
            if isCurrent(generation) { self.error = "GitHub unavailable: \(error.localizedDescription)" }
        }
    }
    func importExternalEvidence() async {
        guard !purgePending else { return }
        let generation = workspaceGeneration
        do {
            guard let url = URL(string: session.profile.aiEndpoint) else { throw GameError.invalidInput }
            let service = EvidenceAPIService(endpoint: url, token: try Keychain.readValue("proxy-token") ?? "")
            var records: [ExternalProof] = [], cursor = session.evidenceCursor, identity = session.evidenceServerID, hasMore = false
            for _ in 0..<20 {
                try Task.checkCancellation()
                let page = try await service.fetch(cursor:cursor,serverID:identity)
                guard isCurrent(generation) else { return }
                records.append(contentsOf:page.events); cursor = page.nextCursor; identity = page.serverID; hasMore = page.hasMore
                if !hasMore { break }
            }
            try mutate { try $0.importEvidence(records); $0.evidenceCursor = cursor; $0.evidenceServerID = identity }
            let count = records.count
            updateIntegration("n8n / VS Code", .connected, "\(count) reference records fetched; no automatic rewards", synced: true)
            notify(hasMore ? "Imported \(count) records. More remain; import again to continue from the saved cursor." : "Evidence imported. Select a relevant record when completing a quest.")
        } catch { if isCurrent(generation) { self.error = "Evidence server unavailable: \(error.localizedDescription)" } }
    }
    func connectCalendar() async {
        guard !purgePending else { return }
        let generation = workspaceGeneration
        do {
            let today = try await AppleCalendarService().today()
            guard isCurrent(generation) else { return }
            commitments = today
            updateIntegration("Calendar", .connected, "Read-only today's commitments", synced: true)
        } catch {
            if isCurrent(generation) { updateIntegration("Calendar", .denied, error.localizedDescription) }
        }
    }
    func connectHealth() async {
        guard !purgePending else { return }
        #if os(iOS)
        let generation = workspaceGeneration
        do {
            let summary = try await AppleHealthService().summary()
            guard isCurrent(generation) else { return }
            if perform({ $0.mergeHealth(summary) }) {
                updateIntegration("Apple Health", .connected, "Read permitted daily summaries; missing metrics remain unknown", synced: true)
            }
        } catch {
            if isCurrent(generation) { updateIntegration("Apple Health", .denied, error.localizedDescription) }
        }
        #else
        updateIntegration("Apple Health", .unavailable, "Read Health on iPhone. Derived summaries can sync through iCloud.")
        #endif
    }
    private func isCurrent(_ generation: Int) -> Bool {
        !purgePending && generation == workspaceGeneration
    }
    func updateIntegration(_ name: String, _ status: IntegrationState, _ message: String, synced: Bool = false) {
        perform { state in
            if let i = state.integrations.firstIndex(where: { $0.name == name }) { state.integrations[i].state = status; state.integrations[i].message = message; state.integrations[i].lastSync = synced ? Date() : nil }
            else { state.integrations.append(IntegrationStatus(name: name, state: status, message: message, lastSync: synced ? Date() : nil)) }
        }
    }
}
